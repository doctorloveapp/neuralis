package com.neuralis.app

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.media.projection.MediaProjection
import android.os.Build
import android.os.IBinder
import android.util.Log
import androidx.core.app.NotificationCompat

/**
 * NeuralisForegroundService — Servizio in primo piano di Neuralis.
 *
 * Responsabilità:
 *   1. Mantenere una notifica persistente visibile (IMPORTANCE_LOW)
 *      ⚠️ CRITICO per Android 13+: senza notifica il sistema termina il service.
 *   2. Tenere vivo il contesto MediaProjection per la cattura audio interna.
 *   3. Delegare la cattura audio a [NativeAudioCapture] (implementato in Sezione 2).
 *   4. Delegare la gestione overlay a [OverlayManager] (implementato in questo passo).
 *
 * Avvio: il service viene avviato da [MainActivity] via MethodChannel
 * SOLO dopo aver ricevuto RESULT_OK dal dialogo MediaProjection (passo 4 del flow).
 * Non avviare mai questo service prima di avere il MediaProjectionData.
 *
 * Dispose chain (da rispettare nell'ordine — ARCHITECTURE.md §6):
 *   1. interactionController.dispose()
 *   2. shaderRepository.dispose()
 *   3. audioCaptureService.stop()   ← questo service
 *   4. overlayService.hide()        ← questo service
 *   5. stopSelf()                   ← questo service
 */
class NeuralisForegroundService : Service() {

    companion object {
        private const val TAG = "NeuralisFgService"

        // ── Canale notifica ───────────────────────────────────────────────
        const val CHANNEL_ID   = "neuralis_overlay_channel"
        const val CHANNEL_NAME = "Neuralis System"

        // ── Costanti notifica ─────────────────────────────────────────────
        private const val NOTIFICATION_ID    = 1001
        private const val NOTIFICATION_TITLE = "Neuralis — System Active"

        // ── Intent extras ─────────────────────────────────────────────────
        /** Chiave per passare il resultCode di MediaProjection all'Intent di avvio. */
        const val EXTRA_RESULT_CODE = "neuralis_media_projection_result_code"

        /** Chiave per passare il data Intent di MediaProjection all'Intent di avvio. */
        const val EXTRA_PROJECTION_DATA = "neuralis_media_projection_data"

        /** Azione per avviare il service con MediaProjection. */
        const val ACTION_START = "com.neuralis.app.START_SERVICE"

        /** Azione per fermare il service. */
        const val ACTION_STOP = "com.neuralis.app.STOP_SERVICE"
    }

    // ── Stato interno ─────────────────────────────────────────────────────
    private var mediaProjection: MediaProjection? = null

    // ── Riferimento al NativeAudioCapture (iniettato in Sezione 2) ────────
    // TODO(section2): var audioCapture: NativeAudioCapture? = null

    // ── Riferimento all'OverlayManager (iniettato in questo passo) ────────
    // TODO(section1): var overlayManager: OverlayManager? = null

    // ─────────────────────────────────────────────────────────────────────
    // Lifecycle
    // ─────────────────────────────────────────────────────────────────────

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        Log.d(TAG, "onCreate: servizio creato")
        createNotificationChannel()
    }

    /**
     * Punto di ingresso principale del service.
     *
     * ⚠️ ORDINE OBBLIGATORIO:
     *   1. Chiama startForeground() IMMEDIATAMENTE — Android 13+ lo richiede
     *      entro pochi secondi dall'avvio o il processo viene terminato.
     *   2. Solo DOPO startForeground(), estrai e usa MediaProjection.
     */
    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_START -> handleStart(intent)
            ACTION_STOP  -> handleStop()
            else         -> {
                Log.w(TAG, "onStartCommand: azione sconosciuta — ${intent?.action}")
                stopSelf()
            }
        }
        return START_STICKY  // Il sistema riavvia il service se viene terminato
    }

    override fun onDestroy() {
        Log.d(TAG, "onDestroy: pulizia risorse")
        releaseMediaProjection()
        super.onDestroy()
    }

    /**
     * Chiamato quando l'utente rimuove l'app dalla lista recenti (swipe-away).
     * ⚠️ Con START_STICKY, il service sopravvive a questo evento.
     * Manteniamo attiva solo la notifica persistente.
     */
    override fun onTaskRemoved(rootIntent: Intent?) {
        Log.d(TAG, "onTaskRemoved: app rimossa dai recenti — service rimane attivo")
        // NON chiamare stopSelf(): il service deve rimanere vivo per l'overlay
        super.onTaskRemoved(rootIntent)
    }

    // ─────────────────────────────────────────────────────────────────────
    // Gestione avvio
    // ─────────────────────────────────────────────────────────────────────

    private fun handleStart(intent: Intent) {
        Log.d(TAG, "handleStart: avvio con MediaProjection")

        // PASSO 1 CRITICO: startForeground() PRIMA di qualsiasi altra operazione.
        // Se questo non viene chiamato entro 5 secondi su Android 12+,
        // il sistema genera ANR/crash del service.
        startForeground(NOTIFICATION_ID, buildNotification())
        Log.d(TAG, "handleStart: startForeground() completato — notifica attiva")

        // Estrai i dati MediaProjection dall'Intent (passati da MainActivity
        // dopo aver ricevuto RESULT_OK dal dialogo di sistema — passo 4 del flow).
        val resultCode = intent.getIntExtra(EXTRA_RESULT_CODE, -1)
        val projectionData = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            intent.getParcelableExtra(EXTRA_PROJECTION_DATA, Intent::class.java)
        } else {
            @Suppress("DEPRECATION")
            intent.getParcelableExtra(EXTRA_PROJECTION_DATA)
        }

        if (projectionData == null || resultCode == -1) {
            Log.e(TAG, "handleStart: MediaProjectionData mancante — service non può avviarsi")
            stopSelf()
            return
        }

        // Inizializza MediaProjection — necessario per AudioPlaybackCaptureConfiguration.
        val projectionManager = getSystemService(Context.MEDIA_PROJECTION_SERVICE)
                as android.media.projection.MediaProjectionManager
        mediaProjection = projectionManager.getMediaProjection(resultCode, projectionData)
        Log.d(TAG, "handleStart: MediaProjection inizializzata — pronto per audio capture")

        // Rende disponibile la MediaProjection a NativeAudioCapture
        // per la modalità INTERNAL e HYBRID (Audio Playback Capture).
        // MainActivity leggerà sharedMediaProjection quando l'utente avvia la cattura.
        NativeAudioCapture.sharedMediaProjection = mediaProjection
        Log.d(TAG, "handleStart: sharedMediaProjection impostata su NativeAudioCapture")
        // → emette INTERNAL_AUDIO_READY via EventChannel dopo l'init
    }

    private fun handleStop() {
        Log.d(TAG, "handleStop: stop richiesto da MethodChannel")
        releaseMediaProjection()
        stopForeground(STOP_FOREGROUND_REMOVE)
        stopSelf()
    }

    // ─────────────────────────────────────────────────────────────────────
    // Notifica persistente
    // ─────────────────────────────────────────────────────────────────────

    /**
     * Crea il canale di notifica (richiesto da Android 8+).
     * IMPORTANCE_LOW → notifica silenziosa, non disturba l'utente.
     */
    private fun createNotificationChannel() {
        val channel = NotificationChannel(
            CHANNEL_ID,
            CHANNEL_NAME,
            NotificationManager.IMPORTANCE_LOW
        ).apply {
            description = "Neuralis overlay e cattura audio attivi"
            setShowBadge(false)
        }
        val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        manager.createNotificationChannel(channel)
        Log.d(TAG, "createNotificationChannel: canale '$CHANNEL_ID' creato")
    }

    /**
     * Costruisce la notifica persistente obbligatoria.
     *
     * Specifiche (ARCHITECTURE.md §1 / Master Prompt §Sezione 1):
     *   - Canale: [CHANNEL_ID] = "neuralis_overlay_channel"
     *   - Titolo: [NOTIFICATION_TITLE] = "Neuralis — System Active"
     *   - Priorità: IMPORTANCE_LOW (silenziosa)
     *   - Tipo servizio: FOREGROUND_SERVICE_TYPE_MEDIA_PROJECTION
     */
    private fun buildNotification(): Notification {
        // Tap sulla notifica → apre MainActivity
        val openIntent = PendingIntent.getActivity(
            this,
            0,
            Intent(this, MainActivity::class.java),
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
        )

        // Azione "Stop" nella notifica
        val stopIntent = PendingIntent.getService(
            this,
            1,
            Intent(this, NeuralisForegroundService::class.java).apply {
                action = ACTION_STOP
            },
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
        )

        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle(NOTIFICATION_TITLE)
            .setContentText("Neural Wavefront Engine attivo")
            .setSmallIcon(android.R.drawable.ic_media_play) // TODO: sostituire con ic_neuralis
            .setContentIntent(openIntent)
            .setOngoing(true)          // non rimovibile dall'utente
            .setSilent(true)           // nessun suono/vibrazione
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .addAction(
                android.R.drawable.ic_media_pause,
                "Stop",
                stopIntent
            )
            .build()
    }

    // ─────────────────────────────────────────────────────────────────────
    // Pulizia risorse
    // ─────────────────────────────────────────────────────────────────────

    private fun releaseMediaProjection() {
        mediaProjection?.stop()
        mediaProjection = null
        Log.d(TAG, "releaseMediaProjection: MediaProjection rilasciata")
    }
}
