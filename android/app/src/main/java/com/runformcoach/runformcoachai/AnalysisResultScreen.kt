package com.runformcoach.runformcoachai

import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.*
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp

@Composable
fun AnalysisResultScreen(result: AnalysisResponse) {
    Column(
        modifier = Modifier.fillMaxWidth(),
        verticalArrangement = Arrangement.spacedBy(16.dp)
    ) {
        // Summary card
        Card(modifier = Modifier.fillMaxWidth()) {
            Column(modifier = Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(6.dp)) {
                Text("Analysis Summary", style = MaterialTheme.typography.titleMedium)
                Text(result.summary, style = MaterialTheme.typography.bodyMedium, color = MaterialTheme.colorScheme.onSurfaceVariant)
                Text(
                    "Confidence: ${(result.confidence * 100).toInt()}%",
                    style = MaterialTheme.typography.labelSmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )
            }
        }

        // Metrics
        Text("Movement Metrics", style = MaterialTheme.typography.titleMedium)
        result.metrics.forEach { metric ->
            Card(modifier = Modifier.fillMaxWidth()) {
                Column(modifier = Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(6.dp)) {
                    Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                        Text(metric.name, style = MaterialTheme.typography.bodyLarge)
                        SuggestionChip(onClick = {}, label = { Text(metric.status, style = MaterialTheme.typography.labelSmall) })
                    }
                    LinearProgressIndicator(
                        progress = { metric.score.toFloat() },
                        modifier = Modifier.fillMaxWidth()
                    )
                    Text(metric.explanation, style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
                }
            }
        }

        // Issues / strength plan
        Text("Recommended Strength Plan", style = MaterialTheme.typography.titleMedium)
        result.issues.forEach { issue ->
            Card(modifier = Modifier.fillMaxWidth()) {
                Column(modifier = Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                    Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                        Text(issue.title, style = MaterialTheme.typography.titleSmall)
                        SuggestionChip(onClick = {}, label = { Text(issue.severity, style = MaterialTheme.typography.labelSmall) })
                    }
                    Text(issue.explanation, style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)

                    issue.recommendedExercises.forEach { ex ->
                        HorizontalDivider()
                        Column(verticalArrangement = Arrangement.spacedBy(2.dp)) {
                            Text(ex.name, style = MaterialTheme.typography.bodyMedium)
                            Text(
                                "${ex.sets} sets × ${ex.reps}  •  ${ex.frequencyPerWeek}×/week  •  ${ex.category}",
                                style = MaterialTheme.typography.labelSmall,
                                color = MaterialTheme.colorScheme.onSurfaceVariant
                            )
                            Text(ex.reason, style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
                        }
                    }
                }
            }
        }
    }
}
