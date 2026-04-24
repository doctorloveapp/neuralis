package com.neuralis.app

import android.content.Context
import android.graphics.PixelFormat
import android.os.Build
import android.util.Log
import android.view.Gravity
import android.view.View
import android.view.WindowManager
import io.flutter.plugin.common.MethodChannel

/**
 * OverlayManager — Gestione dell'overlay di sistema tramite WindowManager.
 *
 * Responsabilità:
 *   - Aggiungere/rimuovere una View dal WindowManager di sistema
 *     usando il tipo SYSTEM_ALERT_WINDOW (TYPE_APPLICATION_OVERLAY).
 *   - Rispondere ai comandi show/hide/isVisible provenienti da Flutter
 *     tramite MethodChannel('neuralis/overlay').
 *   - Gestire le LayoutParams (flag touchable, opacità, lock posizione).
 *
 * ⚠️ PREREQUISITI:
 *   - Il permesso SYSTEM_ALERT_WINDOW deve essere granted PRIMA di show().
 *   - Verificare con Settings.canDrawOverlays(context) prima di chiamare show().
 *
 * Nota architetturale: questo oggetto è creato e tenuto da MainActivity,
 * che lo inizializza dopo aver ricevuto la conferma del permesso overlay
 * dal layer Flutter. Il layer Flutter non conosce WindowManager.
 */
class OverlayManager(private val context: Context) {

    companion object {
        private const val TAG = "OverlayManager"
    }

    private val windowManager: WindowManager =
        context.getSystemService(Context.WINDOW_SERVICE) as WindowManager

    /** La View correntemente mostrata come overlay. Null se nascosta. */
    private var overlayView: View? = null

    /** Opacità corrente dell'overlay [0.0, 1.0]. */
    private var currentOpacity: Float = 1.0f

    /** True se la posizione è bloccata (non trascinabile). */
    private var isLocked: Boolean = true

    // ─────────────────────────────────────────────────────────────────────
    // API pubblica — chiamata da MainActivity via MethodChannel
    // ─────────────────────────────────────────────────────────────────────

    /**
     * Mostra l'overlay di sistema.
     *
     * Crea e aggiunge la View al WindowManager con le LayoutParams appropriate.
     * Se l'overlay è già visibile, è un no-op.
     *
     * ⚠️ Chiamare SOLO se Settings.canDrawOverlays(context) == true.
     *
     * @param view La View Flutter da mostrare come overlay.
     *             In produzione sarà il FlutterView dell'overlay_screen.
     *             Per ora accetta qualsiasi View per consentire test isolati.
     */
    fun show(view: View) {
        if (overlayView != null) {
            Log.d(TAG, "show: overlay già visibile — no-op")
            return
        }
        try {
            windowManager.addView(view, buildLayoutParams())
            overlayView = view
            Log.d(TAG, "show: overlay aggiunto al WindowManager")
        } catch (e: WindowManager.BadTokenException) {
            Log.e(TAG, "show: BadTokenException — permesso SYSTEM_ALERT_WINDOW non valido", e)
        } catch (e: Exception) {
            Log.e(TAG, "show: errore inatteso durante addView", e)
        }
    }

    /**
     * Nasconde l'overlay rimuovendo la View dal WindowManager.
     *
     * Se l'overlay non è visibile, è un no-op.
     * Il ForegroundService e l'audio capture rimangono attivi.
     */
    fun hide() {
        val view = overlayView ?: run {
            Log.d(TAG, "hide: overlay non visibile — no-op")
            return
        }
        try {
            windowManager.removeView(view)
            overlayView = null
            Log.d(TAG, "hide: overlay rimosso dal WindowManager")
        } catch (e: Exception) {
            Log.e(TAG, "hide: errore durante removeView", e)
        }
    }

    /** Restituisce true se l'overlay è attualmente aggiunto al WindowManager. */
    fun isVisible(): Boolean = overlayView != null

    /**
     * Aggiorna l'opacità dell'overlay senza rimuovere e riaggiunger la View.
     *
     * @param opacity Valore in [0.0, 1.0]. Valori fuori range vengono clampati.
     */
    fun setOpacity(opacity: Float) {
        val clamped = opacity.coerceIn(0.0f, 1.0f)
        currentOpacity = clamped
        val view = overlayView ?: return
        try {
            val params = view.layoutParams as WindowManager.LayoutParams
            params.alpha = clamped
            windowManager.updateViewLayout(view, params)
            Log.d(TAG, "setOpacity: opacità aggiornata a $clamped")
        } catch (e: Exception) {
            Log.e(TAG, "setOpacity: errore durante updateViewLayout", e)
        }
    }

    /**
     * Imposta il flag di blocco posizione dell'overlay.
     *
     * Quando [locked] == false, la View può essere trascinata.
     * TODO(future): implementare GestureDetector per drag-to-reposition
     *               con windowManager.updateViewLayout() ad ogni touch event.
     */
    fun setLocked(locked: Boolean) {
        isLocked = locked
        val view = overlayView ?: return
        try {
            val params = buildLayoutParams()
            windowManager.updateViewLayout(view, params)
            Log.d(TAG, "setLocked: isLocked=$locked — layout aggiornato")
        } catch (e: Exception) {
            Log.e(TAG, "setLocked: errore durante updateViewLayout", e)
        }
    }

    // ─────────────────────────────────────────────────────────────────────
    // Handler MethodChannel — registrato da MainActivity
    // ─────────────────────────────────────────────────────────────────────

    /**
     * Gestisce le chiamate MethodChannel('neuralis/overlay') da Flutter.
     *
     * Metodi supportati (ARCHITECTURE.md §7.3):
     *   - "show"      → show() (View placeholder — da sostituire con FlutterView)
     *   - "hide"      → hide()
     *   - "isVisible" → restituisce Boolean
     *   - "setOpacity"→ setOpacity(Double)
     *   - "setLocked" → setLocked(Boolean)
     */
    fun handleMethodCall(
        method: String,
        arguments: Any?,
        result: MethodChannel.Result,
        placeholderView: View,
    ) {
        when (method) {
            "show" -> {
                show(placeholderView)
                result.success(null)
            }
            "hide" -> {
                hide()
                result.success(null)
            }
            "isVisible" -> result.success(isVisible())
            "setOpacity" -> {
                val opacity = (arguments as? Double)?.toFloat() ?: 1.0f
                setOpacity(opacity)
                result.success(null)
            }
            "setLocked" -> {
                val locked = arguments as? Boolean ?: true
                setLocked(locked)
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    // ─────────────────────────────────────────────────────────────────────
    // WindowManager LayoutParams
    // ─────────────────────────────────────────────────────────────────────

    private fun buildLayoutParams(): WindowManager.LayoutParams {
        val type = WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY

        // FLAG_NOT_FOCUSABLE: l'overlay non intercetta il focus della tastiera.
        // FLAG_NOT_TOUCH_MODAL: i touch fuori dall'overlay passano all'app sottostante.
        // FLAG_LAYOUT_IN_SCREEN: l'overlay si estende fino ai bordi dello schermo.
        var flags = (WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE
                or WindowManager.LayoutParams.FLAG_NOT_TOUCH_MODAL
                or WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN)

        // Se bloccato, l'overlay non è interagibile tramite touch (solo visivo).
        // TODO(future): rimuovere FLAG_NOT_TOUCHABLE quando isLocked == false
        //               per abilitare drag-to-reposition.
        if (isLocked) {
            flags = flags or WindowManager.LayoutParams.FLAG_NOT_TOUCHABLE
        }

        return WindowManager.LayoutParams(
            WindowManager.LayoutParams.MATCH_PARENT,
            WindowManager.LayoutParams.MATCH_PARENT,
            type,
            flags,
            PixelFormat.TRANSLUCENT    // supporta trasparenza RGBA
        ).apply {
            gravity = Gravity.TOP or Gravity.START
            alpha = currentOpacity
        }
    }
}
