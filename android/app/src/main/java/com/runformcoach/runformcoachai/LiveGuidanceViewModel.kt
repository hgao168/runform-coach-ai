package com.runformcoach.runformcoachai

import android.content.Context
import android.net.Uri
import androidx.camera.core.CameraSelector
import androidx.camera.core.ImageAnalysis
import androidx.camera.core.ImageProxy
import androidx.camera.core.Preview
import androidx.camera.lifecycle.ProcessCameraProvider
import androidx.camera.view.PreviewView
import androidx.core.content.ContextCompat
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.google.mlkit.vision.common.InputImage
import com.google.mlkit.vision.pose.Pose
import com.google.mlkit.vision.pose.PoseDetection
import com.google.mlkit.vision.pose.PoseDetector
import com.google.mlkit.vision.pose.PoseLandmark
import com.google.mlkit.vision.pose.defaults.PoseDetectorOptions
import dagger.hilt.android.lifecycle.HiltViewModel
import dagger.hilt.android.qualifiers.ApplicationContext
import kotlinx.coroutines.Job
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import java.io.File
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors
import javax.inject.Inject

/**
 * Pose data captured from ML Kit for overlay rendering.
 *
 * Each [PoseLine] represents a bone connecting two landmarks with normalised
 * screen coordinates (0..1, origin top-left).
 */
data class PoseLine(
    val startX: Float,
    val startY: Float,
    val endX: Float,
    val endY: Float
)

/**
 * Full-body guidance hint displayed as an overlay prompt.
 */
enum class GuidanceHint {
    TOO_CLOSE,   // "Please step back"
    TOO_FAR,     // "Please move closer"
    FULL_BODY,   // whole body visible — good to record
    NO_PERSON    // no person detected yet
}

/**
 * State holder for the Live Guidance recording screen (RF-209).
 *
 * Responsibilities:
 * - Manage CameraX lifecycle (bind/unbind via a provided ProcessCameraProvider)
 * - Run ML Kit Pose Detection on every frame
 * - Emit pose landmarks as [PoseLine]s for the Canvas overlay
 * - Emit [GuidanceHint] for body-position prompts
 * - Track recording state and elapsed time
 */
@HiltViewModel
class LiveGuidanceViewModel @Inject constructor(
    @ApplicationContext private val appContext: Context
) : ViewModel() {

    // ── Pose overlay data ────────────────────────────────────────────────────

    private val _poseLines = MutableStateFlow<List<PoseLine>>(emptyList())
    val poseLines: StateFlow<List<PoseLine>> = _poseLines.asStateFlow()

    private val _guidanceHint = MutableStateFlow(GuidanceHint.NO_PERSON)
    val guidanceHint: StateFlow<GuidanceHint> = _guidanceHint.asStateFlow()

    // ── Recording state ──────────────────────────────────────────────────────

    private val _isRecording = MutableStateFlow(false)
    val isRecording: StateFlow<Boolean> = _isRecording.asStateFlow()

    private val _elapsedSeconds = MutableStateFlow(0L)
    val elapsedSeconds: StateFlow<Long> = _elapsedSeconds.asStateFlow()

    private val _recordedVideoUri = MutableStateFlow<Uri?>(null)
    val recordedVideoUri: StateFlow<Uri?> = _recordedVideoUri.asStateFlow()

    /** Set by the caller after recording finishes to navigate to analysis. */
    var onRecordingComplete: ((Uri) -> Unit)? = null

    // ── Camera / ML Kit internals ────────────────────────────────────────────

    private var cameraProvider: ProcessCameraProvider? = null
    private var preview: Preview? = null
    private var imageAnalysis: ImageAnalysis? = null
    private var cameraExecutor: ExecutorService = Executors.newSingleThreadExecutor()
    private var poseDetector: PoseDetector? = null
    private var timerJob: Job? = null

    /** Must be called by the Composable after the PreviewView is ready. */
    fun startCamera(previewView: PreviewView) {
        val cameraProviderFuture = ProcessCameraProvider.getInstance(appContext)

        cameraProviderFuture.addListener({
            cameraProvider = cameraProviderFuture.get()

            preview = Preview.Builder().build().also { it.surfaceProvider = previewView.surfaceProvider }

            // Choose back camera for rear-facing recording (user films a runner)
            val cameraSelector = CameraSelector.DEFAULT_BACK_CAMERA

            // ImageAnalysis for ML Kit pose detection
            imageAnalysis = ImageAnalysis.Builder()
                .setBackpressureStrategy(ImageAnalysis.STRATEGY_KEEP_ONLY_LATEST)
                .build()
                .also { analysis ->
                    analysis.setAnalyzer(cameraExecutor) { imageProxy ->
                        processImageProxy(imageProxy)
                    }
                }

            try {
                cameraProvider?.unbindAll()
                cameraProvider?.bindToLifecycle(
                    previewView.context as androidx.lifecycle.LifecycleOwner,
                    cameraSelector,
                    preview,
                    imageAnalysis
                )
            } catch (_: Exception) {
                // Camera binding may fail if lifecycle is not ready; ignore gracefully
            }

            // Initialise ML Kit
            val options = PoseDetectorOptions.Builder()
                .setDetectorMode(PoseDetectorOptions.STREAM_MODE)
                .build()
            poseDetector = PoseDetection.getClient(options)

        }, ContextCompat.getMainExecutor(appContext))
    }

    /** Toggle recording — typically called from the record button. */
    fun toggleRecording() {
        if (_isRecording.value) {
            stopRecording()
        } else {
            startRecording()
        }
    }

    private fun startRecording() {
        _isRecording.value = true
        _elapsedSeconds.value = 0L
        _recordedVideoUri.value = null

        timerJob = viewModelScope.launch {
            while (true) {
                kotlinx.coroutines.delay(1000L)
                _elapsedSeconds.value += 1
            }
        }
    }

    fun stopRecording() {
        _isRecording.value = false
        timerJob?.cancel()
        timerJob = null

        // Simulate a recorded file path (in a real app, this would come from
        // MediaRecorder or CameraX VideoCapture use case).
        val tempFile = File.createTempFile("live_recording_", ".mp4", appContext.cacheDir)
        val uri = Uri.fromFile(tempFile)
        _recordedVideoUri.value = uri

        onRecordingComplete?.invoke(uri)
    }

    fun reset() {
        stopRecording()
        _poseLines.value = emptyList()
        _guidanceHint.value = GuidanceHint.NO_PERSON
        _elapsedSeconds.value = 0L
        _recordedVideoUri.value = null
    }

    override fun onCleared() {
        super.onCleared()
        cameraExecutor.shutdown()
        poseDetector?.close()
    }

    // ── ML Kit Pose Detection ────────────────────────────────────────────────

    private fun processImageProxy(imageProxy: ImageProxy) {
        val mediaImage = imageProxy.image ?: run {
            imageProxy.close()
            return
        }

        val inputImage = InputImage.fromMediaImage(mediaImage, imageProxy.imageInfo.rotationDegrees)
        poseDetector?.process(inputImage)
            ?.addOnSuccessListener { pose ->
                _poseLines.value = extractPoseLines(pose, imageProxy.width, imageProxy.height)
                _guidanceHint.value = evaluateGuidance(pose)
            }
            ?.addOnFailureListener {
                _poseLines.value = emptyList()
                _guidanceHint.value = GuidanceHint.NO_PERSON
            }
            ?.addOnCompleteListener {
                imageProxy.close()
            }
    }

    // ── Pose → Overlay lines ─────────────────────────────────────────────────

    companion object {
        /**
         * Bone connections for pose skeleton rendering.
         * Each pair connects two PoseLandmark constants.
         */
        private val BONE_PAIRS = listOf(
            PoseLandmark.LEFT_SHOULDER to PoseLandmark.RIGHT_SHOULDER,
            PoseLandmark.LEFT_SHOULDER to PoseLandmark.LEFT_ELBOW,
            PoseLandmark.LEFT_ELBOW to PoseLandmark.LEFT_WRIST,
            PoseLandmark.RIGHT_SHOULDER to PoseLandmark.RIGHT_ELBOW,
            PoseLandmark.RIGHT_ELBOW to PoseLandmark.RIGHT_WRIST,
            PoseLandmark.LEFT_SHOULDER to PoseLandmark.LEFT_HIP,
            PoseLandmark.RIGHT_SHOULDER to PoseLandmark.RIGHT_HIP,
            PoseLandmark.LEFT_HIP to PoseLandmark.RIGHT_HIP,
            PoseLandmark.LEFT_HIP to PoseLandmark.LEFT_KNEE,
            PoseLandmark.LEFT_KNEE to PoseLandmark.LEFT_ANKLE,
            PoseLandmark.RIGHT_HIP to PoseLandmark.RIGHT_KNEE,
            PoseLandmark.RIGHT_KNEE to PoseLandmark.RIGHT_ANKLE,
            // Head / spine
            PoseLandmark.NOSE to PoseLandmark.LEFT_EAR,
            PoseLandmark.NOSE to PoseLandmark.RIGHT_EAR,
            PoseLandmark.LEFT_EAR to PoseLandmark.LEFT_SHOULDER,
            PoseLandmark.RIGHT_EAR to PoseLandmark.RIGHT_SHOULDER
        )

        /** Minimum inlier fraction to consider the full body visible. */
        private const val FULL_BODY_THRESHOLD = 0.85f

        /** When the average Y of visible landmarks is too high (person too close). */
        private const val TOO_CLOSE_Y = 0.15f

        /** When the average bounding box height is too small (person too far). */
        private const val TOO_FAR_HEIGHT_RATIO = 0.35f
    }

    private fun extractPoseLines(pose: Pose, imageWidth: Int, imageHeight: Int): List<PoseLine> {
        val lines = mutableListOf<PoseLine>()
        for ((startType, endType) in BONE_PAIRS) {
            val start = pose.getPoseLandmark(startType) ?: continue
            val end = pose.getPoseLandmark(endType) ?: continue
            if (start.inFrameLikelihood < 0.5f || end.inFrameLikelihood < 0.5f) continue
            lines.add(
                PoseLine(
                    startX = start.position.x / imageWidth,
                    startY = start.position.y / imageHeight,
                    endX = end.position.x / imageWidth,
                    endY = end.position.y / imageHeight
                )
            )
        }
        return lines
    }

    private fun evaluateGuidance(pose: Pose): GuidanceHint {
        val all = pose.allPoseLandmarks
        val inFrame = all.count { it.inFrameLikelihood > 0.5f }
        val total = all.size
        if (total == 0 || inFrame.toFloat() / total < 0.3f) return GuidanceHint.NO_PERSON

        // Check if person is too close: average Y of visible landmarks is very high
        val visibleYs = all.filter { it.inFrameLikelihood > 0.5f }.map { it.position.y }
        if (visibleYs.isNotEmpty()) {
            val avgY = visibleYs.average().toFloat()
            val minY = visibleYs.min()
            val maxY = visibleYs.max()
            val heightRatio = (maxY - minY) / 1080f // rough normalisation

            if (minY < TOO_CLOSE_Y * 100f) return GuidanceHint.TOO_CLOSE
            if (heightRatio < TOO_FAR_HEIGHT_RATIO) return GuidanceHint.TOO_FAR
        }

        val fraction = inFrame.toFloat() / total
        return if (fraction >= FULL_BODY_THRESHOLD) GuidanceHint.FULL_BODY
        else GuidanceHint.NO_PERSON
    }
}
