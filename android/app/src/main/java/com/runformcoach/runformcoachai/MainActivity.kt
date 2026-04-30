package com.runformcoach.runformcoachai

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.PlayArrow
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewmodel.compose.viewModel

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()
        setContent {
            MaterialTheme {
                MainScreen()
            }
        }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun MainScreen(vm: MainViewModel = viewModel()) {
    val context = LocalContext.current
    val selectedUri by vm.selectedVideoUri.collectAsStateWithLifecycle()
    val state by vm.analysisState.collectAsStateWithLifecycle()

    val videoPicker = rememberLauncherForActivityResult(
        contract = ActivityResultContracts.GetContent()
    ) { uri -> uri?.let { vm.onVideoSelected(it) } }

    Scaffold(
        topBar = { TopAppBar(title = { Text("RunForm Coach AI") }) }
    ) { padding ->
        Column(
            modifier = Modifier
                .padding(padding)
                .padding(16.dp)
                .verticalScroll(rememberScrollState()),
            verticalArrangement = Arrangement.spacedBy(16.dp)
        ) {
            // Header
            Text(
                "Running video → strength plan",
                style = MaterialTheme.typography.titleLarge
            )
            Text(
                "Upload a short side-view running video. V1 returns a starter analysis and strength recommendations.",
                style = MaterialTheme.typography.bodyMedium,
                color = MaterialTheme.colorScheme.onSurfaceVariant
            )

            // Selected video indicator
            if (selectedUri != null) {
                Card(modifier = Modifier.fillMaxWidth()) {
                    Text(
                        "Video selected: ${selectedUri?.lastPathSegment ?: "video"}",
                        modifier = Modifier.padding(12.dp),
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant
                    )
                }
            }

            // Buttons
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(12.dp)
            ) {
                Button(
                    onClick = { videoPicker.launch("video/*") },
                    modifier = Modifier.weight(1f)
                ) {
                    Icon(Icons.Default.PlayArrow, contentDescription = null)
                    Spacer(Modifier.width(6.dp))
                    Text("Pick Video")
                }

                OutlinedButton(
                    onClick = { vm.analyzeVideo(context) },
                    enabled = selectedUri != null && state !is AnalysisState.Loading,
                    modifier = Modifier.weight(1f)
                ) {
                    if (state is AnalysisState.Loading) {
                        CircularProgressIndicator(modifier = Modifier.size(18.dp), strokeWidth = 2.dp)
                    } else {
                        Text("Analyze")
                    }
                }
            }

            // Error
            if (state is AnalysisState.Error) {
                Text(
                    (state as AnalysisState.Error).message,
                    color = MaterialTheme.colorScheme.error,
                    style = MaterialTheme.typography.bodySmall
                )
            }

            // Result
            if (state is AnalysisState.Success) {
                AnalysisResultScreen(result = (state as AnalysisState.Success).result)
            }
        }
    }
}
