package com.neuralis.app

import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.Settings
import android.util.Log
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

/**
 * MainActivity — Entry point Android e hub dei MethodChannel Flutter↔Kotlin.
 *
 * Responsabilità:
 *   - Inizializzare tutti i MethodChannel definiti in ARCHITECTURE.md §7
 *   - Istanziare e coordinare [OverlayManager] e [MediaProjectionHandler]
 *   - Delegare ogni chiamata al gestore appropriato
 *
 * Channel registrati (ARCHITECTURE.md §7):
 *   - "neuralis/audio"       → comandi audio capture (Sezione 2)
 *   - "neuralis/overlay"     → show/hide/isVisible overlay
 *   - "neuralis/permissions" → overlay permission + MediaProjection flow
 *
 * ⚠️ ORDINE INIZIALIZZAZIONE in configureFlutterEngine():
 *   1. [MediaProjectionHandler] — registra ActivityResultLauncher (PRIMA di onStart)
 *   2. [OverlayManager]         — nessun vincolo di timing
 *   3. Registrazione MethodChannel — dopo che i gestori sono pronti
 */
class MainActivity : FlutterFragmentActivity() {

    companion object {
        private const val TAG = "MainActivity"

        // Channel IDs — corrispondono ai MethodChannel/EventChannel nel layer Dart
        private const val CHANNEL_AUDIO        = "neuralis/audio"
        private const val CHANNEL_AUDIO_STREAM = "neuralis/audio_stream"
        private const val CHANNEL_OVERLAY      = "neuralis/overlay"
        private const val CHANNEL_PERMISSIONS  = "neuralis/permissions"
    }

    // ── Gestori nativi ────────────────────────────────────────────────────
    private lateinit var overlayManager: OverlayManager
    private lateinit var mediaProjectionHandler: MediaProjectionHandler
    private lateinit var audioCapture: NativeAudioCapture

    // ── Channel references ────────────────────────────────────────────────
    private var audioChannel: MethodChannel? = null
    private var overlayChannel: MethodChannel? = null
    private var permissionsChannel: MethodChannel? = null

    // ─────────────────────────────────────────────────────────────────────
    // Lifecycle
    // ─────────────────────────────────────────────────────────────────────

    /**
     * Punto di registrazione dei MethodChannel.
     *
     * ⚠️ [MediaProjectionHandler] DEVE essere creato qui (in configureFlutterEngine)
     * e NON in onCreate/onStart, perché registerForActivityResult() deve essere
     * chiamato prima che l'Activity raggiunga lo stato STARTED.
     */
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        Log.d(TAG, "configureFlutterEngine: inizializzazione gestori e channel")

        // PASSO 1: MediaProjectionHandler prima di tutto (registra ActivityResultLauncher)
        mediaProjectionHandler = MediaProjectionHandler(this)

        // PASSO 2b: NativeAudioCapture — istanziato prima dei channel
        audioCapture = NativeAudioCapture()

        // PASSO 2: OverlayManager
        overlayManager = OverlayManager(this)

        // PASSO 3: Registra i MethodChannel
        val messenger = flutterEngine.dartExecutor.binaryMessenger

        // Registra NativeAudioCapture come StreamHandler dell'EventChannel
        EventChannel(messenger, CHANNEL_AUDIO_STREAM)
            .setStreamHandler(audioCapture)

        setupAudioChannel(messenger)
        setupOverlayChannel(messenger)
        setupPermissionsChannel(messenger)

        Log.d(TAG, "configureFlutterEngine: tutti i channel registrati")
    }

    override fun onDestroy() {
        Log.d(TAG, "onDestroy: pulizia channel")
        audioChannel?.setMethodCallHandler(null)
        overlayChannel?.setMethodCallHandler(null)
        permissionsChannel?.setMethodCallHandler(null)

        // Ferma audio capture e nascondi overlay
        if (::audioCapture.isInitialized) audioCapture.dispose()
        if (overlayManager.isVisible()) overlayManager.hide()

        super.onDestroy()
    }

    // ─────────────────────────────────────────────────────────────────────
    // Channel: neuralis/audio
    // ─────────────────────────────────────────────────────────────────────

    /**
     * Registra il MethodChannel per i comandi audio.
     *
     * Metodi (ARCHITECTURE.md §7.1):
     *   - "start"    → avvia cattura (mode: "internal"|"external"|"hybrid")
     *   - "stop"     → ferma cattura
     *   - "setMode"  → cambia modalità al volo
     *
     * ⚠️ Implementazione completa in Sezione 2 (NativeAudioCapture.kt).
     *    Per ora risponde con "not_ready" per non lasciare il channel silenzioso.
     */
    private fun setupAudioChannel(messenger: io.flutter.plugin.common.BinaryMessenger) {
        audioChannel = MethodChannel(messenger, CHANNEL_AUDIO).also { channel ->
            channel.setMethodCallHandler { call, result ->
                Log.d(TAG, "audio channel → metodo: ${call.method}")
                @Suppress("UNCHECKED_CAST")
                val args = call.arguments as? Map<String, Any?>
                when (call.method) {
                    "start"   -> {
                        val mode = args?.get("mode") as? String ?: "external"
                        audioCapture.start(mode, result)
                    }
                    "stop"    -> audioCapture.stop(result)
                    "setMode" -> {
                        val mode = args?.get("mode") as? String ?: "external"
                        audioCapture.setMode(mode, result)
                    }
                    else -> result.notImplemented()
                }
            }
        }
    }

    // ─────────────────────────────────────────────────────────────────────
    // Channel: neuralis/overlay
    // ─────────────────────────────────────────────────────────────────────

    /**
     * Registra il MethodChannel per il controllo dell'overlay.
     *
     * Metodi (ARCHITECTURE.md §7.3):
     *   - "show"       → mostra overlay
     *   - "hide"       → nasconde overlay
     *   - "isVisible"  → restituisce Boolean
     *   - "setOpacity" → aggiorna opacità (Double)
     *   - "setLocked"  → aggiorna lock posizione (Boolean)
     *
     * ⚠️ "show" richiede che SYSTEM_ALERT_WINDOW sia granted.
     *    La View placeholder è temporanea — in Sezione 3 sarà il FlutterView
     *    dell'overlay_screen con il Neural Wavefront e i pad LCARS.
     */
    private fun setupOverlayChannel(messenger: io.flutter.plugin.common.BinaryMessenger) {
        overlayChannel = MethodChannel(messenger, CHANNEL_OVERLAY).also { channel ->
            channel.setMethodCallHandler { call, result ->
                Log.d(TAG, "overlay channel → metodo: ${call.method}")

                // Verifica permesso overlay prima di qualsiasi operazione visiva
                if (call.method == "show" && !canDrawOverlays()) {
                    Log.e(TAG, "show: permesso SYSTEM_ALERT_WINDOW non concesso")
                    result.error(
                        "PERMISSION_DENIED",
                        "SYSTEM_ALERT_WINDOW non concesso — richiedere prima il permesso",
                        null
                    )
                    return@setMethodCallHandler
                }

                // Crea una View placeholder per i test — sarà sostituita in Sezione 3
                val placeholderView = android.view.View(this).apply {
                    setBackgroundColor(android.graphics.Color.argb(128, 0, 0, 0))
                }

                overlayManager.handleMethodCall(
                    method = call.method,
                    arguments = call.arguments,
                    result = result,
                    placeholderView = placeholderView,
                )
            }
        }
    }

    // ─────────────────────────────────────────────────────────────────────
    // Channel: neuralis/permissions
    // ─────────────────────────────────────────────────────────────────────

    /**
     * Registra il MethodChannel per la gestione dei permessi Android.
     *
     * Metodi (ARCHITECTURE.md §7.4):
     *   - "requestOverlay"         → apre ACTION_MANAGE_OVERLAY_PERMISSION
     *   - "checkOverlay"           → controlla stato permesso overlay (Boolean)
     *   - "requestMediaProjection" → avvia il flow in 7 passi
     *   - "openAppSettings"        → apre le impostazioni dell'app
     *
     * Nota: i runtime permission standard (RECORD_AUDIO) sono gestiti
     * dal layer Dart tramite il package permission_handler.
     * Solo i permessi speciali che richiedono Activity Result vengono
     * gestiti via MethodChannel.
     */
    private fun setupPermissionsChannel(messenger: io.flutter.plugin.common.BinaryMessenger) {
        permissionsChannel = MethodChannel(messenger, CHANNEL_PERMISSIONS).also { channel ->
            channel.setMethodCallHandler { call, result ->
                Log.d(TAG, "permissions channel → metodo: ${call.method}")
                when (call.method) {

                    // Apre la schermata impostazioni overlay di sistema
                    "requestOverlay" -> {
                        openOverlayPermissionSettings()
                        result.success(null)
                    }

                    // Controlla se il permesso overlay è attualmente concesso
                    "checkOverlay" -> {
                        result.success(canDrawOverlays())
                    }

                    // Avvia il flow MediaProjection (passi 2–5)
                    "requestMediaProjection" -> {
                        mediaProjectionHandler.requestProjection(result)
                        // result viene completato in modo asincrono da MediaProjectionHandler
                    }

                    // Ferma il ForegroundService
                    "stopService" -> {
                        mediaProjectionHandler.stopService()
                        result.success(null)
                    }

                    // Apre le impostazioni dell'app (per permessi permanentemente negati)
                    "openAppSettings" -> {
                        openAppSettings()
                        result.success(null)
                    }

                    else -> result.notImplemented()
                }
            }
        }
    }

    // ─────────────────────────────────────────────────────────────────────
    // Helpers — permessi speciali Android
    // ─────────────────────────────────────────────────────────────────────

    /** True se il permesso SYSTEM_ALERT_WINDOW è concesso. */
    private fun canDrawOverlays(): Boolean =
        Settings.canDrawOverlays(this)

    /**
     * Apre la schermata delle impostazioni per SYSTEM_ALERT_WINDOW.
     * Non è un runtime permission — richiede navigazione manuale dell'utente.
     */
    private fun openOverlayPermissionSettings() {
        val intent = Intent(
            Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
            Uri.parse("package:$packageName")
        ).apply {
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        }
        startActivity(intent)
        Log.d(TAG, "openOverlayPermissionSettings: aperto ACTION_MANAGE_OVERLAY_PERMISSION")
    }

    /**
     * Apre le impostazioni generali dell'app.
     * Usato quando un permesso è [PermissionStatus.permanentlyDenied]
     * e l'utente deve abilitarlo manualmente.
     * Corrisponde al metodo [PermissionService.openAppSettings()].
     */
    private fun openAppSettings() {
        val intent = Intent(
            Settings.ACTION_APPLICATION_DETAILS_SETTINGS,
            Uri.parse("package:$packageName")
        ).apply {
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        }
        startActivity(intent)
        Log.d(TAG, "openAppSettings: aperto ACTION_APPLICATION_DETAILS_SETTINGS")
    }
}
