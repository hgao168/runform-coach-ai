package com.runformcoach.runformcoachai

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.runformcoach.runformcoachai.data.FeedbackDao
import com.runformcoach.runformcoachai.data.FeedbackEntity
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import javax.inject.Inject

// ── Feedback state machine ─────────────────────────────────────────────────────

sealed class FeedbackSubmissionState {
    /** No submission in progress. */
    object Idle : FeedbackSubmissionState()

    /** Submitting to server or storing locally. */
    object Submitting : FeedbackSubmissionState()

    /** Successfully submitted (network or locally stored). */
    data class Submitted(val offlineSaved: Boolean = false) : FeedbackSubmissionState()

    /** Submission failed (network error), saved locally. */
    data class SavedOffline(val message: String = "Saved offline. Will sync later.") : FeedbackSubmissionState()

    /** Hard error — couldn't even save locally. */
    data class Error(val message: String) : FeedbackSubmissionState()
}

// ── ViewModel ──────────────────────────────────────────────────────────────────

/**
 * Manages user feedback submission for analysis results (RF-203).
 *
 * - 5-star rating + optional comment
 * - Submits to POST /feedback API
 * - Falls back to Room offline storage when network is unavailable
 * - Syncs unsynced feedback on re-submit
 */
@HiltViewModel
class FeedbackViewModel @Inject constructor(
    private val api: RunFormApi,
    private val feedbackDao: FeedbackDao
) : ViewModel() {

    // ── Rating ──────────────────────────────────────────────────────────────────

    private val _rating = MutableStateFlow(0)   // 0 = unset, 1–5 = stars
    val rating: StateFlow<Int> = _rating.asStateFlow()

    // ── Comment ─────────────────────────────────────────────────────────────────

    private val _comment = MutableStateFlow("")
    val comment: StateFlow<String> = _comment.asStateFlow()

    // ── Submission state ────────────────────────────────────────────────────────

    private val _submissionState = MutableStateFlow<FeedbackSubmissionState>(FeedbackSubmissionState.Idle)
    val submissionState: StateFlow<FeedbackSubmissionState> = _submissionState.asStateFlow()

    // ── Last submitted analysis ID (prevents duplicate submissions) ─────────────

    private var lastSubmittedAnalysisId: String? = null

    // ── Actions ─────────────────────────────────────────────────────────────────

    fun setRating(stars: Int) {
        _rating.value = stars.coerceIn(1, 5)
    }

    fun setComment(text: String) {
        _comment.value = text
    }

    /**
     * Submit feedback for a given analysis.
     * Tries network first; falls back to local Room storage.
     */
    fun submitFeedback(analysisId: String) {
        val stars = _rating.value
        if (stars < 1) return  // must select a rating

        // Prevent duplicate submissions for the same analysis
        if (lastSubmittedAnalysisId == analysisId &&
            _submissionState.value is FeedbackSubmissionState.Submitted
        ) {
            return
        }

        _submissionState.value = FeedbackSubmissionState.Submitting

        viewModelScope.launch {
            try {
                // Try network submission first
                val request = FeedbackRequest(
                    analysisId = analysisId,
                    rating = stars,
                    comment = _comment.value
                )
                api.submitFeedback(request)

                // Network success — also sync any pending offline feedback
                syncPendingFeedback()

                lastSubmittedAnalysisId = analysisId
                _submissionState.value = FeedbackSubmissionState.Submitted(offlineSaved = false)
            } catch (e: Exception) {
                // Network failed — save locally
                saveOffline(analysisId, stars, _comment.value)
            }
        }
    }

    /** Save feedback locally via Room when offline. */
    private suspend fun saveOffline(analysisId: String, stars: Int, commentText: String) {
        try {
            withContext(Dispatchers.IO) {
                feedbackDao.insert(
                    FeedbackEntity(
                        analysisId = analysisId,
                        rating = stars,
                        comment = commentText,
                        synced = false
                    )
                )
            }
            lastSubmittedAnalysisId = analysisId
            _submissionState.value = FeedbackSubmissionState.SavedOffline()
        } catch (e: Exception) {
            _submissionState.value = FeedbackSubmissionState.Error(
                e.message ?: "Failed to save feedback"
            )
        }
    }

    /** Attempt to sync all locally-stored pending feedback to the server. */
    private suspend fun syncPendingFeedback() {
        try {
            val pending = withContext(Dispatchers.IO) {
                feedbackDao.getUnsynced()
            }
            for (entity in pending) {
                try {
                    api.submitFeedback(
                        FeedbackRequest(
                            analysisId = entity.analysisId,
                            rating = entity.rating,
                            comment = entity.comment
                        )
                    )
                    withContext(Dispatchers.IO) {
                        feedbackDao.markSynced(entity.id)
                    }
                } catch (_: Exception) {
                    // Skip individual failures — keep them for next sync
                }
            }
            // Clean up old synced records (>7 days)
            val cutoff = System.currentTimeMillis() - 7 * 24 * 60 * 60 * 1000L
            withContext(Dispatchers.IO) {
                feedbackDao.deleteSyncedOlderThan(cutoff)
            }
        } catch (_: Exception) {
            // Swallow sync errors — not critical
        }
    }

    /** Reset the form for a new submission. */
    fun reset() {
        _rating.value = 0
        _comment.value = ""
        _submissionState.value = FeedbackSubmissionState.Idle
        lastSubmittedAnalysisId = null
    }
}
