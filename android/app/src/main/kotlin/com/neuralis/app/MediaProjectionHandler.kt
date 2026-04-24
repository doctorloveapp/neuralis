package com.neuralis.app

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.media.projection.MediaProjectionManager
import android.os.Build
import android.util.Log
import androidx.activity.result.ActivityResultLauncher
import androidx.activity.result.contract.ActivityResultContracts
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.plugin.common.MethodChannel

/**
 * MediaProjectionHandler — Gestione del flow MediaProjection in 7 passi.
 *
 * ⚠️ CRITICO: rispettare l'ordine esatto dei 7 passi definiti in
 * NEURALIS_MASTER_PROMPT_V1.2.md §Sezione 1 e ARCHITECTURE.md.
 *
 * FLOW OBBLIGATORIO:
 *   Passo 1: Flutter UI → "Avvia Cattura Interna" → MethodChannel.invokeMethod('requestMediaProjection')
 *   Passo 2: MainActivity chiama [requestProjection()] → createScreenCaptureIntent()
 *   Passo 3: Il dialogo di sistema viene mostrato all'utente
 *   Passo 4: [activityResultLauncher] riceve il callback:
 *             - RESULT_CANCELED → emette errore a Flutter
 *             - RESULT_OK       → procede al passo 5
 *   Passo 5: Avvia NeuralisForegroundService passando resultCode + data
 *   Passo 6: NeuralisForegroundService inizializza AudioRecord con
 *             AudioPlaybackCaptureConfiguration (in Sezione 2)
 *   Passo 7: Emette "INTERNAL_AUDIO_READY" via EventChannel a Flutter
 *
 * Questo handler gestisce i passi 2, 3, 4, 5.
 * I passi 6 e 7 sono in NeuralisForegroundService + NativeAudioCapture (Sezione 2).
 *
 * @param activity Riferimento alla FlutterActivity (MainActivity).
 *                 Necessario per startActivityForResult e startForegroundService.
 */
class MediaProjectionHandler(private val activity: FlutterFragmentActivity) {

    companion object {
        private const val TAG = "MediaProjectionHandler"
    }

    private val projectionManager: MediaProjectionManager =
        activity.getSystemService(Context.MEDIA_PROJECTION_SERVICE) as MediaProjectionManager

    /** Callback da chiamare dopo la risoluzione del dialogo di sistema. */
    private var pendingResult: MethodChannel.Result? = null

    /**
     * Launcher per il risultato dell'Activity MediaProjection.
     *
     * Registrato in MainActivity.onCreate() tramite registerForActivityResult().
     * ⚠️ DEVE essere registrato prima di onStart() — non in onResume() o altrove.
     */
    val activityResultLauncher: ActivityResultLauncher<Intent> =
        activity.registerForActivityResult(
            ActivityResultContracts.StartActivityForResult()
        ) { result ->
            handleProjectionResult(result.resultCode, result.data)
        }

    // ─────────────────────────────────────────────────────────────────────
    // API pubblica
    // ─────────────────────────────────────────────────────────────────────

    /**
     * PASSO 2: Avvia il flow MediaProjection mostrando il dialogo di sistema.
     *
     * Chiamato da MainActivity quando Flutter invoca
     * MethodChannel('neuralis/permissions').invokeMethod('requestMediaProjection').
     *
     * @param result Il [MethodChannel.Result] da completare dopo la risposta utente.
     *               Salvato come [pendingResult] per il callback asincrono.
     */
    fun requestProjection(result: MethodChannel.Result) {
        if (pendingResult != null) {
            // Una richiesta è già in corso — non accumulare pending results.
            Log.w(TAG, "requestProjection: richiesta già in corso — ignorata")
            result.error("PROJECTION_PENDING", "Una richiesta MediaProjection è già in corso", null)
            return
        }
        pendingResult = result
        Log.d(TAG, "requestProjection: PASSO 2 — avvio dialogo sistema")

        // PASSO 3: mostra il dialogo di sistema all'utente.
        val captureIntent = projectionManager.createScreenCaptureIntent()
        activityResultLauncher.launch(captureIntent)
    }

    // ─────────────────────────────────────────────────────────────────────
    // Gestione risultato (PASSO 4)
    // ─────────────────────────────────────────────────────────────────────

    /**
     * PASSO 4: Elabora il risultato del dialogo MediaProjection.
     *
     * @param resultCode [Activity.RESULT_OK] o [Activity.RESULT_CANCELED].
     * @param data       L'Intent contenente il token MediaProjection (solo se RESULT_OK).
     */
    private fun handleProjectionResult(resultCode: Int, data: Intent?) {
        val pending = pendingResult
        pendingResult = null

        if (resultCode != Activity.RESULT_OK || data == null) {
            // RESULT_CANCELED: l'utente ha negato il dialogo di sistema.
            Log.w(TAG, "handleProjectionResult: RESULT_CANCELED — utente ha negato il dialogo")
            pending?.success("denied")  // informa Flutter — non è un errore critico
            return
        }

        Log.d(TAG, "handleProjectionResult: RESULT_OK — procedo con PASSO 5")

        // PASSO 5: avvia NeuralisForegroundService con i dati MediaProjection.
        startForegroundServiceWithProjection(resultCode, data)

        // Informa Flutter che il permesso è stato concesso e il service avviato.
        // L'evento INTERNAL_AUDIO_READY arriverà separatamente via EventChannel (Passo 7).
        pending?.success("granted")
    }

    // ─────────────────────────────────────────────────────────────────────
    // PASSO 5: avvio NeuralisForegroundService
    // ─────────────────────────────────────────────────────────────────────

    /**
     * PASSO 5: Avvia [NeuralisForegroundService] passando il token MediaProjection.
     *
     * ⚠️ CRITICO: usare startForegroundService() e NON startService().
     * Su Android 8+ il sistema richiede che il service chiami startForeground()
     * entro 5 secondi o viene terminato con ANR.
     */
    private fun startForegroundServiceWithProjection(resultCode: Int, data: Intent) {
        val serviceIntent = Intent(activity, NeuralisForegroundService::class.java).apply {
            action = NeuralisForegroundService.ACTION_START
            putExtra(NeuralisForegroundService.EXTRA_RESULT_CODE, resultCode)
            putExtra(NeuralisForegroundService.EXTRA_PROJECTION_DATA, data)
        }

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            activity.startForegroundService(serviceIntent)
        } else {
            activity.startService(serviceIntent)
        }
        Log.d(TAG, "startForegroundServiceWithProjection: PASSO 5 — NeuralisForegroundService avviato")
    }

    /**
     * Ferma il [NeuralisForegroundService].
     * Chiamato da MainActivity quando Flutter invia il comando "stop".
     */
    fun stopService() {
        val serviceIntent = Intent(activity, NeuralisForegroundService::class.java).apply {
            action = NeuralisForegroundService.ACTION_STOP
        }
        activity.startService(serviceIntent)
        Log.d(TAG, "stopService: richiesta stop inviata al ForegroundService")
    }
}
