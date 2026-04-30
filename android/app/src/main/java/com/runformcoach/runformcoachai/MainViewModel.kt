package com.runformcoach.runformcoachai

import android.content.Context
import android.net.Uri
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.launch
import java.io.File

sealed class AnalysisState {
    object Idle : AnalysisState()
    object Loading : AnalysisState()
    data class Success(val result: AnalysisResponse) : AnalysisState()
    data class Error(val message: String) : AnalysisState()
}

class MainViewModel : ViewModel() {

    private val _selectedVideoUri = MutableStateFlow<Uri?>(null)
    val selectedVideoUri: StateFlow<Uri?> = _selectedVideoUri

    private val _analysisState = MutableStateFlow<AnalysisState>(AnalysisState.Idle)
    val analysisState: StateFlow<AnalysisState> = _analysisState

    fun onVideoSelected(uri: Uri) {
        _selectedVideoUri.value = uri
        _analysisState.value = AnalysisState.Idle
    }

    fun analyzeVideo(context: Context) {
        val uri = _selectedVideoUri.value ?: return
        viewModelScope.launch {
            _analysisState.value = AnalysisState.Loading
            try {
                val tempFile = uriToTempFile(context, uri)
                val part = ApiClient.buildVideoPart(tempFile)
                val result = ApiClient.api.analyzeVideo(part)
                _analysisState.value = AnalysisState.Success(result)
                tempFile.delete()
            } catch (e: Exception) {
                _analysisState.value = AnalysisState.Error(
                    e.message ?: "Unknown error. Make sure the backend is running."
                )
            }
        }
    }

    private fun uriToTempFile(context: Context, uri: Uri): File {
        val inputStream = context.contentResolver.openInputStream(uri)
            ?: throw Exception("Cannot open video file")
        val tempFile = File.createTempFile("upload", ".mp4", context.cacheDir)
        tempFile.outputStream().use { inputStream.copyTo(it) }
        return tempFile
    }
}
