package com.runformcoach.runformcoachai

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.combine
import kotlinx.coroutines.flow.stateIn
import kotlinx.coroutines.launch
import javax.inject.Inject

// ── UI State ───────────────────────────────────────────────────────────────────

/**
 * Loading / error / success states for the session list and detail screens.
 */
sealed class RunSessionListState {
    object Loading : RunSessionListState()
    data class Success(val sessions: List<RunSessionSummary>) : RunSessionListState()
    data class Error(val message: String) : RunSessionListState()
}

sealed class RunSessionDetailState {
    object Loading : RunSessionDetailState()
    data class Success(val session: RunSessionDetail) : RunSessionDetailState()
    data class Error(val message: String) : RunSessionDetailState()
}

/**
 * Replay playback state.
 */
enum class ReplayPlaybackState {
    STOPPED,
    PLAYING,
    PAUSED
}

// ── ViewModel ──────────────────────────────────────────────────────────────────

/**
 * ViewModel for RF-1000 RunSession History and Replay.
 *
 * Manages two screens:
 * 1. Session list — fetches GET /sessions, shows session cards
 * 2. Session replay — fetches GET /sessions/{id}, provides replay controls
 *
 * Replay logic:
 * - [playbackState] drives the play/pause/stop control
 * - [currentDataPointIndex] advances automatically in PLAYING mode (4 Hz)
 * - [currentDataPoint] is derived from index and the loaded session
 * - [promptMarkersAtOrBefore] shows coach prompts up to current time
 *
 * Usage:
 * ```
 * @Composable
 * fun RunSessionReplayScreen(vm: RunSessionReplayViewModel = hiltViewModel()) { ... }
 * ```
 */
@HiltViewModel
class RunSessionReplayViewModel @Inject constructor(
    private val api: RunFormApi
) : ViewModel() {

    // ── Session List State ─────────────────────────────────────────────────────

    private val _listState = MutableStateFlow<RunSessionListState>(RunSessionListState.Loading)
    val listState: StateFlow<RunSessionListState> = _listState.asStateFlow()

    // ── Selected Session Detail State ──────────────────────────────────────────

    private val _detailState = MutableStateFlow<RunSessionDetailState?>(null)
    val detailState: StateFlow<RunSessionDetailState?> = _detailState.asStateFlow()

    // ── Replay State ───────────────────────────────────────────────────────────

    private val _playbackState = MutableStateFlow(ReplayPlaybackState.STOPPED)
    val playbackState: StateFlow<ReplayPlaybackState> = _playbackState.asStateFlow()

    private val _currentDataPointIndex = MutableStateFlow(0)
    val currentDataPointIndex: StateFlow<Int> = _currentDataPointIndex.asStateFlow()

    /**
     * Derived current data point from index and loaded session.
     * Reactively recomputes when detailState or currentDataPointIndex changes.
     */
    val currentDataPoint: StateFlow<ReplayDataPoint?> = combine(
        _detailState, _currentDataPointIndex
    ) { detailState, index ->
        val detail = (detailState as? RunSessionDetailState.Success)?.session
        detail?.dataPoints?.getOrNull(index)
    }.stateIn(viewModelScope, SharingStarted.WhileSubscribed(5000), null)

    /**
     * Coach prompts that occurred at or before the current replay time.
     * Reactively recomputes when detailState or currentDataPoint changes.
     */
    val promptMarkersAtOrBefore: StateFlow<List<SessionCoachPrompt>> = combine(
        _detailState, currentDataPoint
    ) { detailState, dp ->
        val detail = (detailState as? RunSessionDetailState.Success)?.session
        val elapsed = dp?.elapsedSeconds ?: 0.0
        detail?.coachPrompts?.filter { it.elapsedSeconds <= elapsed } ?: emptyList()
    }.stateIn(viewModelScope, SharingStarted.WhileSubscribed(5000), emptyList())

    // ── Internal ───────────────────────────────────────────────────────────────

    private var replayJob: Job? = null
    /** Replay tick interval in milliseconds (~4 Hz). */
    private val replayTickMs = 250L

    // ── Initialization ─────────────────────────────────────────────────────────

    init {
        loadSessionList()
    }

    // ── Load Session List ──────────────────────────────────────────────────────

    fun loadSessionList() {
        _listState.value = RunSessionListState.Loading
        viewModelScope.launch {
            try {
                val sessions = api.fetchSessions()
                _listState.value = RunSessionListState.Success(sessions)
            } catch (e: Exception) {
                _listState.value = RunSessionListState.Error(
                    e.message ?: "Failed to load sessions"
                )
            }
        }
    }

    // ── Select & Load Session Detail ───────────────────────────────────────────

    /**
     * Called when the user taps a session card.
     * Fetches the full detail from GET /sessions/{id} and resets replay state.
     */
    fun selectSession(sessionId: String) {
        stopReplay()
        _detailState.value = RunSessionDetailState.Loading
        viewModelScope.launch {
            try {
                val detail = api.fetchSessionDetail(sessionId)
                _detailState.value = RunSessionDetailState.Success(detail)
                _currentDataPointIndex.value = 0
            } catch (e: Exception) {
                _detailState.value = RunSessionDetailState.Error(
                    e.message ?: "Failed to load session detail"
                )
            }
        }
    }

    /**
     * Navigate back from replay to the session list.
     */
    fun dismissDetail() {
        stopReplay()
        _detailState.value = null
    }

    // ── Replay Controls ────────────────────────────────────────────────────────

    /** Start or resume playback. */
    fun play() {
        val detail = (_detailState.value as? RunSessionDetailState.Success)?.session
            ?: return
        val totalPoints = detail.dataPointCount
        if (totalPoints == 0) return

        _playbackState.value = ReplayPlaybackState.PLAYING

        replayJob?.cancel()
        replayJob = viewModelScope.launch {
            while (_currentDataPointIndex.value < totalPoints - 1) {
                delay(replayTickMs)
                if (_playbackState.value != ReplayPlaybackState.PLAYING) break
                _currentDataPointIndex.value = _currentDataPointIndex.value + 1
            }
            // Auto-stop at end
            if (_currentDataPointIndex.value >= totalPoints - 1) {
                _playbackState.value = ReplayPlaybackState.STOPPED
            }
        }
    }

    /** Pause playback at current position. */
    fun pause() {
        _playbackState.value = ReplayPlaybackState.PAUSED
    }

    /** Stop playback and reset to beginning. */
    fun stopReplay() {
        _playbackState.value = ReplayPlaybackState.STOPPED
        replayJob?.cancel()
        replayJob = null
        _currentDataPointIndex.value = 0
    }

    /**
     * Seek to a specific data point index via slider.
     */
    fun seekTo(index: Int) {
        val detail = (_detailState.value as? RunSessionDetailState.Success)?.session
            ?: return
        _currentDataPointIndex.value = index.coerceIn(0, (detail.dataPointCount - 1).coerceAtLeast(0))
    }

    override fun onCleared() {
        super.onCleared()
        replayJob?.cancel()
    }
}
