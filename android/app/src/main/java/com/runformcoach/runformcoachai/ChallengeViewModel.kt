package com.runformcoach.runformcoachai

import android.content.Context
import android.content.SharedPreferences
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import dagger.hilt.android.lifecycle.HiltViewModel
import dagger.hilt.android.qualifiers.ApplicationContext
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import java.util.UUID
import javax.inject.Inject
import javax.inject.Singleton

// ═══════════════════════════════════════════════════════════════════════════════
// User Identity Provider — persists a stable UUID for challenge identification
// ═══════════════════════════════════════════════════════════════════════════════

@Singleton
class UserIdentity @Inject constructor(
    @ApplicationContext private val context: Context
) {
    private val prefs: SharedPreferences =
        context.getSharedPreferences("runform_identity", Context.MODE_PRIVATE)

    val userId: String by lazy {
        prefs.getString(KEY_USER_ID, null) ?: run {
            val newId = "android_${UUID.randomUUID().toString().take(8)}"
            prefs.edit().putString(KEY_USER_ID, newId).apply()
            newId
        }
    }

    companion object {
        private const val KEY_USER_ID = "user_id"
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Challenge ViewModel
// ═══════════════════════════════════════════════════════════════════════════════

@HiltViewModel
class ChallengeViewModel @Inject constructor(
    private val api: RunFormApi,
    private val userIdentity: UserIdentity
) : ViewModel() {

    // ── Challenge List ──────────────────────────────────────────────────────────

    private val _listState = MutableStateFlow<ChallengeListState>(ChallengeListState.Loading)
    val listState: StateFlow<ChallengeListState> = _listState.asStateFlow()

    // ── Join State ──────────────────────────────────────────────────────────────

    private val _joinState = MutableStateFlow<ChallengeJoinState>(ChallengeJoinState.Idle)
    val joinState: StateFlow<ChallengeJoinState> = _joinState.asStateFlow()

    // ── Check-In State ──────────────────────────────────────────────────────────

    private val _checkInState = MutableStateFlow<ChallengeCheckInState>(ChallengeCheckInState.Idle)
    val checkInState: StateFlow<ChallengeCheckInState> = _checkInState.asStateFlow()

    // ── Leaderboard State ───────────────────────────────────────────────────────

    private val _leaderboardState = MutableStateFlow<ChallengeLeaderboardState>(ChallengeLeaderboardState.Loading)
    val leaderboardState: StateFlow<ChallengeLeaderboardState> = _leaderboardState.asStateFlow()

    // ── Active Challenge (set after loadChallenges or join) ─────────────────────

    private var activeChallenge: ChallengeInfo? = null

    init {
        loadChallenges()
    }

    // ── Load Challenges ─────────────────────────────────────────────────────────

    fun loadChallenges() {
        _listState.value = ChallengeListState.Loading
        viewModelScope.launch {
            try {
                val challenges = api.listChallenges(userIdentity.userId)
                _listState.value = ChallengeListState.Success(challenges)
                // Auto-select first active challenge
                activeChallenge = challenges.firstOrNull { it.status == "active" }
                if (activeChallenge != null) {
                    loadLeaderboard(activeChallenge!!.id)
                }
            } catch (e: Exception) {
                _listState.value = ChallengeListState.Error(
                    e.message ?: "Failed to load challenges"
                )
            }
        }
    }

    // ── Join Challenge ──────────────────────────────────────────────────────────

    fun joinChallenge(challengeId: String) {
        _joinState.value = ChallengeJoinState.Joining
        viewModelScope.launch {
            try {
                val response = api.joinChallenge(
                    challengeId,
                    ChallengeJoinRequest(iosUserId = userIdentity.userId)
                )
                _joinState.value = ChallengeJoinState.Joined(response)
                // Refresh challenges to get updated participation state
                loadChallenges()
            } catch (e: Exception) {
                _joinState.value = ChallengeJoinState.Error(
                    e.message ?: "Failed to join challenge"
                )
            }
        }
    }

    fun resetJoinState() {
        _joinState.value = ChallengeJoinState.Idle
    }

    // ── Daily Check-In ──────────────────────────────────────────────────────────

    fun checkIn(challengeId: String) {
        val current = activeChallenge
        if (current?.todayCompleted == true) {
            _checkInState.value = ChallengeCheckInState.AlreadyCheckedIn("Already checked in today")
            return
        }
        _checkInState.value = ChallengeCheckInState.CheckingIn
        viewModelScope.launch {
            try {
                val response = api.checkInChallenge(
                    challengeId,
                    ChallengeCheckInRequest(userId = userIdentity.userId)
                )
                _checkInState.value = ChallengeCheckInState.CheckedIn(response)
                // Refresh challenges and leaderboard
                loadChallenges()
            } catch (e: Exception) {
                _checkInState.value = ChallengeCheckInState.Error(
                    e.message ?: "Failed to check in"
                )
            }
        }
    }

    fun resetCheckInState() {
        _checkInState.value = ChallengeCheckInState.Idle
    }

    // ── Leaderboard ─────────────────────────────────────────────────────────────

    fun loadLeaderboard(challengeId: String) {
        _leaderboardState.value = ChallengeLeaderboardState.Loading
        viewModelScope.launch {
            try {
                val entries = api.getChallengeLeaderboard(challengeId, userIdentity.userId)
                val myRank = entries.firstOrNull { it.isMe }?.rank
                _leaderboardState.value = if (entries.isEmpty()) {
                    ChallengeLeaderboardState.Empty
                } else {
                    ChallengeLeaderboardState.Success(entries, myRank)
                }
            } catch (e: Exception) {
                _leaderboardState.value = ChallengeLeaderboardState.Error(
                    e.message ?: "Failed to load leaderboard"
                )
            }
        }
    }
}
