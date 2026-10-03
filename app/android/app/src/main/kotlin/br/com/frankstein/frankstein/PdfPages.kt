package br.com.frankstein.frankstein

import android.graphics.Bitmap
import android.graphics.Color
import android.graphics.pdf.PdfRenderer
import android.os.Handler
import android.os.Looper
import android.os.ParcelFileDescriptor
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream
import java.io.Closeable
import java.io.File
import java.util.concurrent.Executors

/**
 * Páginas de PDF de receitas e exames como imagem, pelo `PdfRenderer` do
 * próprio Android — sem biblioteca de PDF. Canal `rlt/pdf`:
 * - `pageCount(path)` → número de páginas (erro se protegido por senha ou
 *   danificado);
 * - `renderPage(path, index, width)` → PNG da página com fundo branco.
 *
 * Só lê arquivos da pasta privada do app; nada sai do aparelho. Roda fora
 * da thread principal para não travar a tela.
 */
object PdfPages {
    private val worker = Executors.newSingleThreadExecutor()
    private val main = Handler(Looper.getMainLooper())

    fun handle(call: MethodCall, result: MethodChannel.Result) {
        val path = call.argument<String>("path")
        if (path == null) {
            result.error("bad_args", "path ausente", null)
            return
        }
        when (call.method) {
            "pageCount" -> inBackground(result) { open(path).use { it.pageCount } }
            "renderPage" -> {
                val index = call.argument<Int>("index") ?: 0
                val width = (call.argument<Int>("width") ?: 1600).coerceIn(200, 3000)
                inBackground(result) { open(path).use { render(it, index, width) } }
            }
            else -> result.notImplemented()
        }
    }

    private fun inBackground(result: MethodChannel.Result, block: () -> Any) {
        worker.execute {
            try {
                val value = block()
                main.post { result.success(value) }
            } catch (e: Exception) {
                main.post { result.error("pdf_unreadable", e.message, null) }
            }
        }
    }

    private class Doc(val fd: ParcelFileDescriptor, val renderer: PdfRenderer) : Closeable {
        val pageCount get() = renderer.pageCount
        override fun close() {
            renderer.close()
            fd.close()
        }
    }

    private fun open(path: String): Doc {
        val fd = ParcelFileDescriptor.open(File(path), ParcelFileDescriptor.MODE_READ_ONLY)
        return try {
            Doc(fd, PdfRenderer(fd))
        } catch (e: Exception) {
            fd.close()
            throw e
        }
    }

    private fun render(doc: Doc, index: Int, width: Int): ByteArray {
        val page = doc.renderer.openPage(index.coerceIn(0, doc.pageCount - 1))
        try {
            val height = (width.toLong() * page.height / page.width).toInt().coerceAtLeast(1)
            val bitmap = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
            bitmap.eraseColor(Color.WHITE)
            page.render(bitmap, null, null, PdfRenderer.Page.RENDER_MODE_FOR_DISPLAY)
            val out = ByteArrayOutputStream()
            bitmap.compress(Bitmap.CompressFormat.PNG, 100, out)
            bitmap.recycle()
            return out.toByteArray()
        } finally {
            page.close()
        }
    }
}
