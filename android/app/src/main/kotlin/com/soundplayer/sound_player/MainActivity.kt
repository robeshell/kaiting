package com.soundplayer.sound_player

import android.app.Activity
import android.content.Intent
import android.net.Uri
import android.provider.DocumentsContract
import java.io.File
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import com.ryanheise.audioservice.AudioServiceActivity

class MainActivity : AudioServiceActivity() {
    companion object {
        private const val channelName =
            "com.soundplayer.sound_player/local_directory_access"
        private const val pickDirectoryRequestCode = 9401
    }

    private var pendingDirectoryResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler(::handleDirectoryMethod)
    }

    private fun handleDirectoryMethod(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "pickDirectory" -> pickDirectory(result)
            "restoreDirectory" -> restoreDirectory(call, result)
            "releaseDirectory" -> releaseDirectory(call, result)
            "listAudioFiles" -> listAudioFiles(call, result)
            "prepareAudioFile" -> prepareAudioFile(call, result)
            "releasePreparedAudioFile" -> releasePreparedAudioFile(call, result)
            else -> result.notImplemented()
        }
    }

    private fun pickDirectory(result: MethodChannel.Result) {
        if (pendingDirectoryResult != null) {
            result.error(
                "directory_picker_active",
                "A directory picker is already active.",
                null,
            )
            return
        }
        pendingDirectoryResult = result
        val intent = Intent(Intent.ACTION_OPEN_DOCUMENT_TREE).apply {
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            addFlags(Intent.FLAG_GRANT_PERSISTABLE_URI_PERMISSION)
            addFlags(Intent.FLAG_GRANT_PREFIX_URI_PERMISSION)
        }
        startActivityForResult(intent, pickDirectoryRequestCode)
    }

    @Deprecated("Deprecated in Android")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != pickDirectoryRequestCode) return
        val result = pendingDirectoryResult ?: return
        pendingDirectoryResult = null

        val uri = data?.data
        if (resultCode != Activity.RESULT_OK || uri == null) {
            result.success(null)
            return
        }

        val takeFlags = data.flags and Intent.FLAG_GRANT_READ_URI_PERMISSION
        try {
            contentResolver.takePersistableUriPermission(uri, takeFlags)
            result.success(grant(uri, "available"))
        } catch (_: SecurityException) {
            result.success(grant(uri, "permissionRequired"))
        } catch (_: IllegalArgumentException) {
            // Providers may reject persistence even after returning a tree URI.
            result.success(grant(uri, "permissionRequired"))
        }
    }

    private fun restoreDirectory(call: MethodCall, result: MethodChannel.Result) {
        val rootUri = call.argument<String>("rootUri")
        if (rootUri == null) {
            result.error("invalid_directory_grant", "A root URI is required.", null)
            return
        }
        val uri = Uri.parse(rootUri)
        val permission = contentResolver.persistedUriPermissions.firstOrNull {
            it.uri == uri && it.isReadPermission
        }
        if (permission == null) {
            result.success(grant(uri, "permissionRequired"))
            return
        }

        val status = try {
            contentResolver.query(
                documentUri(uri),
                arrayOf(DocumentsContract.Document.COLUMN_DOCUMENT_ID),
                null,
                null,
                null,
            )?.use { cursor ->
                if (cursor.moveToFirst()) "available" else "unavailable"
            } ?: "unavailable"
        } catch (_: SecurityException) {
            "permissionRequired"
        } catch (_: Exception) {
            "unavailable"
        }
        result.success(grant(uri, status))
    }

    private fun releaseDirectory(call: MethodCall, result: MethodChannel.Result) {
        val rootUri = call.argument<String>("rootUri")
        if (rootUri != null) {
            try {
                contentResolver.releasePersistableUriPermission(
                    Uri.parse(rootUri),
                    Intent.FLAG_GRANT_READ_URI_PERMISSION,
                )
            } catch (_: SecurityException) {
                // The permission was already revoked by the user or provider.
            }
        }
        result.success(null)
    }

    private fun grant(uri: Uri, status: String): Map<String, Any?> {
        return mapOf(
            "rootUri" to uri.toString(),
            "displayName" to displayName(uri),
            "status" to status,
            "permissionToken" to null,
            "isStale" to false,
        )
    }

    private fun displayName(treeUri: Uri): String {
        return try {
            contentResolver.query(
                documentUri(treeUri),
                arrayOf(DocumentsContract.Document.COLUMN_DISPLAY_NAME),
                null,
                null,
                null,
            )?.use { cursor ->
                if (cursor.moveToFirst()) cursor.getString(0) else null
            } ?: DocumentsContract.getTreeDocumentId(treeUri)
        } catch (_: Exception) {
            treeUri.lastPathSegment ?: treeUri.toString()
        }
    }

    private fun documentUri(treeUri: Uri): Uri {
        return DocumentsContract.buildDocumentUriUsingTree(
            treeUri,
            DocumentsContract.getTreeDocumentId(treeUri),
        )
    }

    private fun listAudioFiles(call: MethodCall, result: MethodChannel.Result) {
        val rootUri = call.argument<String>("rootUri")
        if (rootUri == null) {
            result.error("invalid_directory_grant", "A root URI is required.", null)
            return
        }
        runMediaOperation(result) {
            val treeUri = Uri.parse(rootUri)
            val rootDocumentId = DocumentsContract.getTreeDocumentId(treeUri)
            val files = mutableListOf<Map<String, Any?>>()
            val visitedDirectories = mutableSetOf<String>()

            fun walk(documentId: String, parentPath: String) {
                if (!visitedDirectories.add(documentId)) return
                val childrenUri = DocumentsContract.buildChildDocumentsUriUsingTree(
                    treeUri,
                    documentId,
                )
                val columns = arrayOf(
                    DocumentsContract.Document.COLUMN_DOCUMENT_ID,
                    DocumentsContract.Document.COLUMN_DISPLAY_NAME,
                    DocumentsContract.Document.COLUMN_MIME_TYPE,
                    DocumentsContract.Document.COLUMN_SIZE,
                    DocumentsContract.Document.COLUMN_LAST_MODIFIED,
                )
                contentResolver.query(childrenUri, columns, null, null, null)?.use { cursor ->
                    val idIndex = cursor.getColumnIndexOrThrow(
                        DocumentsContract.Document.COLUMN_DOCUMENT_ID,
                    )
                    val nameIndex = cursor.getColumnIndexOrThrow(
                        DocumentsContract.Document.COLUMN_DISPLAY_NAME,
                    )
                    val mimeIndex = cursor.getColumnIndexOrThrow(
                        DocumentsContract.Document.COLUMN_MIME_TYPE,
                    )
                    val sizeIndex = cursor.getColumnIndex(
                        DocumentsContract.Document.COLUMN_SIZE,
                    )
                    val modifiedIndex = cursor.getColumnIndex(
                        DocumentsContract.Document.COLUMN_LAST_MODIFIED,
                    )
                    while (cursor.moveToNext()) {
                        val childId = cursor.getString(idIndex)
                        val name = cursor.getString(nameIndex) ?: childId.substringAfterLast('/')
                        val mimeType = cursor.getString(mimeIndex)
                        val relativePath = if (parentPath.isEmpty()) {
                            name
                        } else {
                            "$parentPath/$name"
                        }
                        if (mimeType == DocumentsContract.Document.MIME_TYPE_DIR) {
                            walk(childId, relativePath)
                        } else if (isSupportedAudioFile(name, mimeType)) {
                            val documentUri = DocumentsContract.buildDocumentUriUsingTree(
                                treeUri,
                                childId,
                            )
                            files.add(
                                mapOf(
                                    "relativePath" to relativePath,
                                    "mediaUri" to documentUri.toString(),
                                    "contentType" to mimeType,
                                    "fileSize" to cursor.longOrNull(sizeIndex),
                                    "modifiedAtMs" to (cursor.longOrNull(modifiedIndex) ?: 0L),
                                ),
                            )
                        }
                    }
                } ?: throw IllegalStateException("The selected directory could not be queried.")
            }

            walk(rootDocumentId, "")
            files
        }
    }

    private fun prepareAudioFile(call: MethodCall, result: MethodChannel.Result) {
        val mediaUri = call.argument<String>("mediaUri")
        val relativePath = call.argument<String>("relativePath")
        if (mediaUri == null || relativePath == null) {
            result.error("invalid_audio_file", "A media URI and relative path are required.", null)
            return
        }
        runMediaOperation(result) {
            val extension = relativePath.substringAfterLast('.', "audio")
                .lowercase()
                .filter { it.isLetterOrDigit() }
                .take(8)
            val scanCache = File(cacheDir, "sound_scan").apply { mkdirs() }
            val prepared = File.createTempFile("metadata-", ".$extension", scanCache)
            try {
                contentResolver.openInputStream(Uri.parse(mediaUri))?.use { input ->
                    prepared.outputStream().use(input::copyTo)
                } ?: throw IllegalStateException("The audio file could not be opened.")
                prepared.absolutePath
            } catch (error: Exception) {
                prepared.delete()
                throw error
            }
        }
    }

    private fun releasePreparedAudioFile(call: MethodCall, result: MethodChannel.Result) {
        val filePath = call.argument<String>("path")
        if (filePath != null) {
            val scanCache = File(cacheDir, "sound_scan").canonicalFile
            val file = File(filePath).canonicalFile
            if (file.parentFile == scanCache) file.delete()
        }
        result.success(null)
    }

    private fun runMediaOperation(
        result: MethodChannel.Result,
        operation: () -> Any?,
    ) {
        Thread {
            try {
                val value = operation()
                runOnUiThread { result.success(value) }
            } catch (error: SecurityException) {
                runOnUiThread {
                    result.error("directory_permission_required", error.message, null)
                }
            } catch (error: Exception) {
                runOnUiThread {
                    result.error("local_media_scan_failed", error.message, null)
                }
            }
        }.start()
    }

    private fun isSupportedAudioFile(name: String, mimeType: String?): Boolean {
        val lowerName = name.lowercase()
        val normalizedMimeType = mimeType?.substringBefore(';')?.trim()?.lowercase()
        return supportedAudioExtensions.any(lowerName::endsWith) ||
            normalizedMimeType in supportedAudioMimeTypes
    }

    private val supportedAudioExtensions = setOf(
        ".mp3", ".flac", ".m4a", ".aac", ".wav", ".ogg", ".opus",
    )

    private val supportedAudioMimeTypes = setOf(
        "audio/mpeg", "audio/mp3",
        "audio/flac", "audio/x-flac",
        "audio/mp4", "audio/x-m4a", "audio/m4a",
        "audio/aac", "audio/x-aac",
        "audio/wav", "audio/x-wav", "audio/vnd.wave",
        "audio/ogg", "application/ogg", "audio/opus",
    )

    private fun android.database.Cursor.longOrNull(index: Int): Long? {
        return if (index < 0 || isNull(index)) null else getLong(index)
    }
}
