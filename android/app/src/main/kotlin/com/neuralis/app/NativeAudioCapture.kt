package com.neuralis.app

import android.media.AudioAttributes
import android.media.AudioFormat
import android.media.AudioPlaybackCaptureConfiguration
import android.media.AudioRecord
import android.media.MediaRecorder
import android.media.projection.MediaProjection
import android.os.Handler
import android.os.Looper
import android.util.Log
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.*
import kotlinx.coroutines.currentCoroutineContext
import kotlin.math.*

/**
 * NativeAudioCapture — Motore di cattura audio con FFT a 32 bande e Anti-DRM.
 *
 * Implementa [EventChannel.StreamHandler] per inviare dati FFT a Flutter.
 * Il processing (Hanning Window + FFT + bande logaritmiche + RMS) avviene
 * su [Dispatchers.Default] per non bloccare il thread UI di Flutter.
 *
 * Dati emessi via EventChannel('neuralis/audio_stream'):
 *   - FFT data  : FloatArray(32)                          → Dart: List<double>
 *   - DRM event : Map {"event":"DRM_BLOCKED","rms":Float} → Dart: Map
 *   - Ready     : Map {"event":"INTERNAL_AUDIO_READY"}    → Dart: Map
 */
class NativeAudioCapture : EventChannel.StreamHandler {

    companion object {
        private const val TAG             = "NativeAudioCapture"
        const val SAMPLE_RATE             = 44100
        const val FFT_SIZE                = 1024          // campioni per FFT
        const val BAND_COUNT              = 32            // bande logaritmiche
        private const val SILENCE_THRESHOLD = 0.001f     // soglia RMS Anti-DRM
        // ~3 secondi a 44100 Hz con buffer da 1024 campioni → 129 buffer
        private const val DRM_THRESHOLD_BUFFERS = 129

        /** MediaProjection condivisa da NeuralisForegroundService. */
        var sharedMediaProjection: MediaProjection? = null
    }

    // ── EventChannel ─────────────────────────────────────────────────────
    private var eventSink: EventChannel.EventSink? = null
    private val mainHandler = Handler(Looper.getMainLooper())

    // ── Coroutine scope ───────────────────────────────────────────────────
    private val scope = CoroutineScope(Dispatchers.Default + SupervisorJob())
    private var captureJob: Job? = null

    // ── Stato corrente ────────────────────────────────────────────────────
    private var currentMode = "external"
    private var isCapturing  = false

    // ── RMS / Anti-DRM ───────────────────────────────────────────────────
    private var belowThresholdCount = 0
    private var peakMagnitude       = 1.0f
    private val PEAK_DECAY          = 0.9995f // decadimento lento per normalizzazione stabile

    // ── Pre-computazione bande logaritmiche ───────────────────────────────
    // Calcolate una volta sola in init per evitare allocazioni nel loop audio.
    private val bandBoundaries: Array<IntRange> = computeBandBoundaries()

    // ═════════════════════════════════════════════════════════════════════
    // EventChannel.StreamHandler
    // ═════════════════════════════════════════════════════════════════════

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        Log.d(TAG, "onListen: EventChannel attivo")
        eventSink = events
    }

    override fun onCancel(arguments: Any?) {
        Log.d(TAG, "onCancel: EventChannel chiuso")
        eventSink = null
    }

    // ═════════════════════════════════════════════════════════════════════
    // API pubblica — chiamata da MainActivity via MethodChannel
    // ═════════════════════════════════════════════════════════════════════

    /**
     * Avvia la cattura audio nella modalità specificata.
     * @param mode "internal" | "external" | "hybrid"
     */
    fun start(mode: String, result: MethodChannel.Result) {
        if (isCapturing) {
            Log.d(TAG, "start: già in cattura — cambio modalità a $mode")
            setMode(mode, result)
            return
        }
        currentMode = mode
        belowThresholdCount = 0
        isCapturing = true

        captureJob = scope.launch {
            Log.d(TAG, "start: avvio cattura in modalità $mode")
            runCaptureLoop(mode)
        }
        result.success(null)
    }

    /** Ferma la cattura e libera AudioRecord. */
    fun stop(result: MethodChannel.Result) {
        Log.d(TAG, "stop: richiesta stop")
        isCapturing = false
        captureJob?.cancel()
        captureJob = null
        result.success(null)
    }

    /** Cambia modalità al volo. */
    fun setMode(mode: String, result: MethodChannel.Result) {
        Log.d(TAG, "setMode: cambio da $currentMode a $mode")
        currentMode = mode
        belowThresholdCount = 0
        if (isCapturing) {
            captureJob?.cancel()
            captureJob = scope.launch { runCaptureLoop(mode) }
        }
        result.success(null)
    }

    /** Rilascia tutte le risorse. */
    fun dispose() {
        isCapturing = false
        captureJob?.cancel()
        scope.cancel()
        Log.d(TAG, "dispose: risorse rilasciate")
    }

    // ═════════════════════════════════════════════════════════════════════
    // Loop di cattura audio (Dispatchers.Default)
    // ═════════════════════════════════════════════════════════════════════

    private suspend fun runCaptureLoop(mode: String) {
        val bufferSize = maxOf(
            AudioRecord.getMinBufferSize(
                SAMPLE_RATE,
                AudioFormat.CHANNEL_IN_MONO,
                AudioFormat.ENCODING_PCM_FLOAT
            ),
            FFT_SIZE * 4   // *4 perché float = 4 byte
        )

        val internalRecord = if (mode == "internal" || mode == "hybrid") {
            buildInternalAudioRecord(bufferSize)
        } else null

        val externalRecord = if (mode == "external" || mode == "hybrid") {
            buildExternalAudioRecord(bufferSize)
        } else null

        // Avvia le istanze valide
        internalRecord?.startRecording()
        externalRecord?.startRecording()

        // Notifica INTERNAL_AUDIO_READY se rilevante
        if (mode == "internal" || mode == "hybrid") {
            if (internalRecord != null && internalRecord.state == AudioRecord.STATE_INITIALIZED) {
                emitEvent(mapOf("event" to "INTERNAL_AUDIO_READY"))
                Log.d(TAG, "runCaptureLoop: INTERNAL_AUDIO_READY emesso")
            } else {
                Log.e(TAG, "runCaptureLoop: AudioRecord INTERNAL non inizializzato")
            }
        }

        val internalBuffer = FloatArray(FFT_SIZE)
        val externalBuffer = FloatArray(FFT_SIZE)

        try {
            while (currentCoroutineContext().isActive && isCapturing) {
                val mixedBuffer = when (mode) {
                    "internal" -> readBuffer(internalRecord, internalBuffer)
                    "external" -> readBuffer(externalRecord, externalBuffer)
                    "hybrid"   -> {
                        val intBuf = readBuffer(internalRecord, internalBuffer)
                        val extBuf = readBuffer(externalRecord, externalBuffer)
                        mixBuffers(intBuf, extBuf)
                    }
                    else       -> readBuffer(externalRecord, externalBuffer)
                } ?: continue

                // ── Calcolo RMS e logica Anti-DRM ──────────────────────
                if (mode == "internal" || mode == "hybrid") {
                    checkDrmRms(mixedBuffer)
                }

                // ── Pipeline FFT ────────────────────────────────────────
                val fftBands = processFFTPipeline(mixedBuffer)

                // ── Emissione su EventChannel (main thread) ─────────────
                emitEvent(fftBands)
            }
        } finally {
            internalRecord?.stop()
            internalRecord?.release()
            externalRecord?.stop()
            externalRecord?.release()
            Log.d(TAG, "runCaptureLoop: AudioRecord rilasciati")
        }
    }

    // ═════════════════════════════════════════════════════════════════════
    // Costruzione AudioRecord
    // ═════════════════════════════════════════════════════════════════════

    private fun buildInternalAudioRecord(bufferSize: Int): AudioRecord? {
        val projection = sharedMediaProjection ?: run {
            Log.e(TAG, "buildInternalAudioRecord: MediaProjection non disponibile")
            return null
        }
        return try {
            val config = AudioPlaybackCaptureConfiguration.Builder(projection)
                .addMatchingUsage(AudioAttributes.USAGE_MEDIA)
                .addMatchingUsage(AudioAttributes.USAGE_GAME)
                .addMatchingUsage(AudioAttributes.USAGE_UNKNOWN)
                .build()

            val format = AudioFormat.Builder()
                .setEncoding(AudioFormat.ENCODING_PCM_FLOAT)
                .setSampleRate(SAMPLE_RATE)
                .setChannelMask(AudioFormat.CHANNEL_IN_MONO)
                .build()

            AudioRecord.Builder()
                .setAudioPlaybackCaptureConfig(config)
                .setAudioFormat(format)
                .setBufferSizeInBytes(bufferSize)
                .build()
        } catch (e: Exception) {
            Log.e(TAG, "buildInternalAudioRecord: errore — ${e.message}", e)
            null
        }
    }

    private fun buildExternalAudioRecord(bufferSize: Int): AudioRecord? {
        return try {
            AudioRecord(
                MediaRecorder.AudioSource.MIC,
                SAMPLE_RATE,
                AudioFormat.CHANNEL_IN_MONO,
                AudioFormat.ENCODING_PCM_FLOAT,
                bufferSize
            ).also {
                if (it.state != AudioRecord.STATE_INITIALIZED) {
                    Log.e(TAG, "buildExternalAudioRecord: AudioRecord non inizializzato")
                    it.release()
                    return null
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "buildExternalAudioRecord: errore — ${e.message}", e)
            null
        }
    }

    // ═════════════════════════════════════════════════════════════════════
    // Lettura buffer e mix
    // ═════════════════════════════════════════════════════════════════════

    private fun readBuffer(record: AudioRecord?, buffer: FloatArray): FloatArray? {
        if (record == null) return null
        val read = record.read(buffer, 0, FFT_SIZE, AudioRecord.READ_BLOCKING)
        return if (read == FFT_SIZE) buffer else null
    }

    /** Mix pesato 50/50 di due buffer (modalità HYBRID). */
    private fun mixBuffers(a: FloatArray?, b: FloatArray?): FloatArray? {
        if (a == null && b == null) return null
        if (a == null) return b
        if (b == null) return a
        return FloatArray(FFT_SIZE) { i -> (a[i] + b[i]) * 0.5f }
    }

    // ═════════════════════════════════════════════════════════════════════
    // Pipeline FFT
    // ═════════════════════════════════════════════════════════════════════

    /**
     * Pipeline completa:
     *   1. Hanning Window → riduce spectral leakage
     *   2. FFT (Cooley-Tukey radix-2 in-place)
     *   3. Magnitudine per ogni bin: sqrt(re² + im²)
     *   4. 32 bande logaritmiche con media per banda
     *   5. Normalizzazione [0.0, 1.0] con peak tracking + decay
     */
    private fun processFFTPipeline(samples: FloatArray): FloatArray {
        // 1. Hanning Window
        val windowed = applyHanningWindow(samples)

        // 2 + 3. FFT → magnitudini (solo metà positiva dello spettro)
        val magnitudes = computeFFTMagnitudes(windowed)

        // 4. 32 bande logaritmiche
        val bands = mapTo32Bands(magnitudes)

        // 5. Normalizzazione con peak tracking
        return normalizeBands(bands)
    }

    /** Applica la finestra di Hanning per ridurre lo spectral leakage. */
    private fun applyHanningWindow(samples: FloatArray): FloatArray {
        val n = samples.size
        return FloatArray(n) { i ->
            samples[i] * (0.5f - 0.5f * cos(2.0 * PI * i / (n - 1)).toFloat())
        }
    }

    /**
     * FFT Cooley-Tukey radix-2 in-place.
     * Restituisce le magnitudini dei bin positivi (N/2 valori).
     */
    private fun computeFFTMagnitudes(windowed: FloatArray): FloatArray {
        val n = windowed.size
        val real = windowed.copyOf()
        val imag = FloatArray(n)

        // Bit-reversal permutation
        var j = 0
        for (i in 1 until n) {
            var bit = n shr 1
            while (j and bit != 0) { j = j xor bit; bit = bit shr 1 }
            j = j xor bit
            if (i < j) {
                real[i] = real[j].also { real[j] = real[i] }
                imag[i] = imag[j].also { imag[j] = imag[i] }
            }
        }

        // FFT butterfly
        var len = 2
        while (len <= n) {
            val halfLen = len / 2
            val wImSign = -2.0 * PI / len
            var k = 0
            while (k < n) {
                var curRe = 1.0
                var curIm = 0.0
                for (m in 0 until halfLen) {
                    val uRe = real[k + m]; val uIm = imag[k + m]
                    val vRe = real[k + m + halfLen] * curRe - imag[k + m + halfLen] * curIm
                    val vIm = real[k + m + halfLen] * curIm + imag[k + m + halfLen] * curRe
                    real[k + m] = (uRe + vRe).toFloat(); imag[k + m] = (uIm + vIm).toFloat()
                    real[k + m + halfLen] = (uRe - vRe).toFloat(); imag[k + m + halfLen] = (uIm - vIm).toFloat()
                    val angle = wImSign * m
                    val newRe = curRe * cos(angle) - curIm * sin(angle)
                    curIm     = curRe * sin(angle) + curIm * cos(angle)
                    curRe     = newRe
                }
                k += len
            }
            len = len shl 1
        }

        // Magnitudini: solo la metà positiva dello spettro
        return FloatArray(n / 2) { i -> sqrt(real[i] * real[i] + imag[i] * imag[i]) }
    }

    /**
     * Raggruppa i bin FFT in [BAND_COUNT] bande logaritmiche.
     * Ogni banda copre una porzione logaritmicamente uniforme di 20 Hz–22050 Hz.
     */
    private fun mapTo32Bands(magnitudes: FloatArray): FloatArray {
        return FloatArray(BAND_COUNT) { band ->
            val range = bandBoundaries[band]
            val low = range.first.coerceAtMost(magnitudes.size - 1)
            val high = range.last.coerceAtMost(magnitudes.size - 1)
            if (low > high) {
                if (low < magnitudes.size) magnitudes[low] else 0f
            } else {
                var sum = 0.0f
                for (i in low..high) sum += magnitudes[i]
                sum / (high - low + 1)
            }
        }
    }

    /**
     * Pre-calcola i boundary [lowBin, highBin] delle 32 bande logaritmiche.
     * Chiamato una sola volta al momento dell'inizializzazione.
     */
    private fun computeBandBoundaries(): Array<IntRange> {
        val minFreq = 20.0
        val maxFreq = SAMPLE_RATE / 2.0          // frequenza di Nyquist
        val nyquistBins = FFT_SIZE / 2
        return Array(BAND_COUNT) { band ->
            val lowFreq  = minFreq * (maxFreq / minFreq).pow(band.toDouble() / BAND_COUNT)
            val highFreq = minFreq * (maxFreq / minFreq).pow((band + 1.0) / BAND_COUNT)
            val lowBin   = max((lowFreq  * nyquistBins / maxFreq).toInt(), 1)
            val highBin  = min((highFreq * nyquistBins / maxFreq).toInt(), nyquistBins - 1)
            IntRange(lowBin, max(highBin, lowBin))
        }
    }

    /**
     * Normalizza le bande in [0.0, 1.0] usando un peak tracker con decadimento lento.
     * Il decadimento [PEAK_DECAY] garantisce che il valore massimo storico
     * diminuisca gradualmente, adattandosi ai cambiamenti di volume.
     */
    private fun normalizeBands(bands: FloatArray): FloatArray {
        val currentPeak = bands.maxOrNull() ?: 0f
        if (currentPeak > peakMagnitude) peakMagnitude = currentPeak
        peakMagnitude = max(peakMagnitude * PEAK_DECAY, 1.0f)  // floor a 1.0 per evitare ÷0
        return FloatArray(BAND_COUNT) { i -> (bands[i] / peakMagnitude).coerceIn(0f, 1f) }
    }

    // ═════════════════════════════════════════════════════════════════════
    // Anti-DRM — Monitoraggio RMS
    // ═════════════════════════════════════════════════════════════════════

    /**
     * Calcola l'RMS del buffer e verifica la soglia Anti-DRM.
     *
     * ⚠️ NOTA dal Master Prompt: il silenzio DRM non è matematicamente zero —
     * è rumore sotto soglia. Usiamo rms_media < SOGLIA, non rms == 0.
     *
     * Se l'RMS rimane sotto [SILENCE_THRESHOLD] per [DRM_THRESHOLD_BUFFERS]
     * buffer consecutivi (~3 secondi), emette DRM_BLOCKED e forza modalità EXTERNAL.
     */
    private fun checkDrmRms(buffer: FloatArray) {
        val rms = computeRms(buffer)
        if (rms < SILENCE_THRESHOLD) {
            belowThresholdCount++
            if (belowThresholdCount >= DRM_THRESHOLD_BUFFERS) {
                belowThresholdCount = 0
                Log.w(TAG, "checkDrmRms: DRM rilevato (rms=$rms) — failover a EXTERNAL")
                triggerDrmFailover(rms)
            }
        } else {
            belowThresholdCount = 0  // reset se il segnale torna sopra soglia
        }
    }

    /** Calcola il Root Mean Square del buffer. */
    private fun computeRms(buffer: FloatArray): Float {
        var sumSq = 0.0
        for (sample in buffer) sumSq += sample * sample
        return sqrt(sumSq / buffer.size).toFloat()
    }

    /** Emette DRM_BLOCKED e forza la modalità EXTERNAL. */
    private fun triggerDrmFailover(rms: Float) {
        // Emetti evento DRM
        emitEvent(mapOf("event" to "DRM_BLOCKED", "rms" to rms))
        // Forza modalità EXTERNAL sul prossimo ciclo
        currentMode = "external"
        captureJob?.cancel()
        captureJob = scope.launch { runCaptureLoop("external") }
    }

    // ═════════════════════════════════════════════════════════════════════
    // Emissione eventi su EventChannel (sempre sul main thread)
    // ═════════════════════════════════════════════════════════════════════

    private fun emitEvent(data: Any) {
        mainHandler.post { eventSink?.success(data) }
    }
}
