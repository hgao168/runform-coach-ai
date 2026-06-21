package com.runformcoach.runformcoachai

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.itemsIndexed
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.EmojiEvents
import androidx.compose.material.icons.filled.Refresh
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.hilt.navigation.compose.hiltViewModel

// ═══════════════════════════════════════════════════════════════════════════════
// Challenge Screen — composite screen with tabs (progress + leaderboard)
// ═══════════════════════════════════════════════════════════════════════════════

@Composable
fun ChallengeScreen(viewModel: ChallengeViewModel = hiltViewModel()) {
    val listState by viewModel.listState.collectAsState()
    val joinState by viewModel.joinState.collectAsState()
    val checkInState by viewModel.checkInState.collectAsState()
    val leaderboardState by viewModel.leaderboardState.collectAsState()

    var activeTab by remember { mutableIntStateOf(0) } // 0 = progress, 1 = leaderboard

    Column(modifier = Modifier.fillMaxSize()) {
        // ── Header ──────────────────────────────────────────────────────────────
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 16.dp, vertical = 12.dp),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically
        ) {
            Text(
                text = stringResource(R.string.challenge_title),
                color = Color.White,
                fontSize = 22.sp,
                fontWeight = FontWeight.Bold
            )
            IconButton(onClick = { viewModel.loadChallenges() }) {
                Icon(
                    imageVector = Icons.Default.Refresh,
                    contentDescription = stringResource(R.string.refresh),
                    tint = AppColors.TextSecondary
                )
            }
        }

        when (listState) {
            is ChallengeListState.Loading -> {
                Box(
                    modifier = Modifier.fillMaxSize(),
                    contentAlignment = Alignment.Center
                ) {
                    CircularProgressIndicator(color = AppColors.Mint)
                }
            }
            is ChallengeListState.Error -> {
                ChallengeErrorCard(
                    message = (listState as ChallengeListState.Error).message,
                    onRetry = { viewModel.loadChallenges() }
                )
            }
            is ChallengeListState.Success -> {
                val challenges = (listState as ChallengeListState.Success).challenges
                val challenge = challenges.firstOrNull()

                if (challenge == null) {
                    ChallengeEmptyCard()
                } else {
                    // ── Tab Row ─────────────────────────────────────────────────
                    TabRow(
                        selectedTabIndex = activeTab,
                        containerColor = AppColors.Ink,
                        contentColor = AppColors.Mint,
                        modifier = Modifier.padding(horizontal = 16.dp),
                        divider = {}
                    ) {
                        Tab(
                            selected = activeTab == 0,
                            onClick = { activeTab = 0 },
                            text = {
                                Text(
                                    text = stringResource(R.string.challenge_tab_progress),
                                    fontWeight = if (activeTab == 0) FontWeight.SemiBold else FontWeight.Normal,
                                    fontSize = 14.sp
                                )
                            }
                        )
                        Tab(
                            selected = activeTab == 1,
                            onClick = { activeTab = 1 },
                            text = {
                                Text(
                                    text = stringResource(R.string.challenge_tab_leaderboard),
                                    fontWeight = if (activeTab == 1) FontWeight.SemiBold else FontWeight.Normal,
                                    fontSize = 14.sp
                                )
                            }
                        )
                    }

                    when (activeTab) {
                        0 -> ChallengeProgressTab(
                            challenge = challenge,
                            joinState = joinState,
                            checkInState = checkInState,
                            onJoin = { viewModel.joinChallenge(challenge.id) },
                            onCheckIn = { viewModel.checkIn(challenge.id) },
                            onResetJoin = { viewModel.resetJoinState() },
                            onResetCheckIn = { viewModel.resetCheckInState() }
                        )
                        1 -> ChallengeLeaderboardTab(
                            leaderboardState = leaderboardState,
                            challenge = challenge,
                            onRefresh = { viewModel.loadLeaderboard(challenge.id) }
                        )
                    }
                }
            }
        }
    }

    // ── Join success dialog ─────────────────────────────────────────────────────
    if (joinState is ChallengeJoinState.Joined) {
        AlertDialog(
            onDismissRequest = { viewModel.resetJoinState() },
            title = {
                Text(
                    text = "🎉",
                    fontSize = 36.sp,
                    textAlign = TextAlign.Center,
                    modifier = Modifier.fillMaxWidth()
                )
            },
            text = {
                Text(
                    text = (joinState as ChallengeJoinState.Joined).response.message,
                    color = Color.White,
                    fontSize = 15.sp
                )
            },
            confirmButton = {
                TextButton(onClick = { viewModel.resetJoinState() }) {
                    Text(stringResource(R.string.ok), color = AppColors.Mint)
                }
            },
            containerColor = AppColors.DarkCard,
            shape = RoundedCornerShape(20.dp)
        )
    }

    // ── Check-in success snackbar ───────────────────────────────────────────────
    LaunchedEffect(checkInState) {
        when (val state = checkInState) {
            is ChallengeCheckInState.CheckedIn -> {
                viewModel.resetCheckInState()
            }
            is ChallengeCheckInState.AlreadyCheckedIn -> {
                kotlinx.coroutines.delay(2500L)
                viewModel.resetCheckInState()
            }
            else -> {}
        }
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Challenge Progress Tab
// ═══════════════════════════════════════════════════════════════════════════════

@Composable
private fun ChallengeProgressTab(
    challenge: ChallengeInfo,
    joinState: ChallengeJoinState,
    checkInState: ChallengeCheckInState,
    onJoin: () -> Unit,
    onCheckIn: () -> Unit,
    onResetJoin: () -> Unit,
    onResetCheckIn: () -> Unit
) {
    val joined = challenge.joined == true
    val completedDays = challenge.completedDays ?: 0
    val todayCompleted = challenge.todayCompleted == true
    val progressPct = if (challenge.days > 0) {
        (completedDays.toFloat() / challenge.days * 100).toInt().coerceIn(0, 100)
    } else 0

    LazyColumn(
        modifier = Modifier.fillMaxSize(),
        contentPadding = PaddingValues(16.dp),
        verticalArrangement = Arrangement.spacedBy(16.dp)
    ) {
        // ── Challenge Info Card ─────────────────────────────────────────────────
        item {
            GlassCard {
                Column(
                    verticalArrangement = Arrangement.spacedBy(12.dp)
                ) {
                    Row(
                        verticalAlignment = Alignment.CenterVertically,
                        horizontalArrangement = Arrangement.spacedBy(10.dp)
                    ) {
                        Box(
                            modifier = Modifier
                                .size(48.dp)
                                .clip(CircleShape)
                                .background(
                                    if (challenge.status == "active") AppColors.Mint.copy(alpha = 0.2f)
                                    else AppColors.TextMuted.copy(alpha = 0.1f)
                                ),
                            contentAlignment = Alignment.Center
                        ) {
                            Icon(
                                imageVector = Icons.Default.EmojiEvents,
                                contentDescription = null,
                                tint = if (challenge.status == "active") AppColors.Mint else AppColors.TextMuted,
                                modifier = Modifier.size(24.dp)
                            )
                        }
                        Column(modifier = Modifier.weight(1f)) {
                            Text(
                                text = challenge.name,
                                color = Color.White,
                                fontSize = 17.sp,
                                fontWeight = FontWeight.SemiBold
                            )
                            Text(
                                text = stringResource(
                                    R.string.challenge_participants_count,
                                    challenge.participantCount
                                ),
                                color = AppColors.TextSecondary,
                                fontSize = 13.sp
                            )
                        }
                        // Status badge
                        Box(
                            modifier = Modifier
                                .clip(RoundedCornerShape(8.dp))
                                .background(
                                    if (challenge.status == "active") AppColors.Mint.copy(alpha = 0.15f)
                                    else AppColors.Orange.copy(alpha = 0.15f)
                                )
                                .padding(horizontal = 10.dp, vertical = 4.dp)
                        ) {
                            Text(
                                text = if (challenge.status == "active")
                                    stringResource(R.string.challenge_status_active)
                                else stringResource(R.string.challenge_status_ended),
                                color = if (challenge.status == "active") AppColors.Mint else AppColors.Orange,
                                fontSize = 12.sp,
                                fontWeight = FontWeight.SemiBold
                            )
                        }
                    }

                    Text(
                        text = challenge.description,
                        color = AppColors.TextSecondary,
                        fontSize = 14.sp,
                        lineHeight = 20.sp
                    )

                    // Duration row
                    Row(
                        horizontalArrangement = Arrangement.spacedBy(16.dp)
                    ) {
                        ChallengeInfoChip(
                            label = stringResource(R.string.challenge_duration),
                            value = stringResource(R.string.challenge_days_count, challenge.days)
                        )
                        ChallengeInfoChip(
                            label = stringResource(R.string.challenge_dates),
                            value = "${challenge.startDate} – ${challenge.endDate}"
                        )
                    }
                }
            }
        }

        // ── Progress Ring Card ──────────────────────────────────────────────────
        item {
            GlassCard {
                Column(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalAlignment = Alignment.CenterHorizontally,
                    verticalArrangement = Arrangement.spacedBy(16.dp)
                ) {
                    if (joined) {
                        // Progress ring
                        Box(
                            modifier = Modifier.size(180.dp),
                            contentAlignment = Alignment.Center
                        ) {
                            CircularProgressIndicator(
                                progress = { progressPct / 100f },
                                modifier = Modifier.fillMaxSize(),
                                strokeWidth = 10.dp,
                                color = AppColors.Mint,
                                trackColor = AppColors.Card
                            )
                            Column(horizontalAlignment = Alignment.CenterHorizontally) {
                                Text(
                                    text = "$completedDays",
                                    color = Color.White,
                                    fontSize = 48.sp,
                                    fontWeight = FontWeight.Bold
                                )
                                Text(
                                    text = stringResource(R.string.challenge_of_days, challenge.days),
                                    color = AppColors.TextMuted,
                                    fontSize = 14.sp
                                )
                                Text(
                                    text = stringResource(R.string.challenge_days_completed),
                                    color = AppColors.TextSecondary,
                                    fontSize = 13.sp,
                                    fontWeight = FontWeight.SemiBold
                                )
                            }
                        }

                        // Check-in button
                        Button(
                            onClick = onCheckIn,
                            enabled = !todayCompleted && checkInState !is ChallengeCheckInState.CheckingIn,
                            modifier = Modifier.fillMaxWidth(),
                            colors = ButtonDefaults.buttonColors(
                                containerColor = if (todayCompleted) AppColors.Green.copy(alpha = 0.15f)
                                else AppColors.Mint,
                                disabledContainerColor = AppColors.Green.copy(alpha = 0.15f),
                                disabledContentColor = AppColors.Green
                            ),
                            shape = RoundedCornerShape(14.dp)
                        ) {
                            when {
                                checkInState is ChallengeCheckInState.CheckingIn -> {
                                    CircularProgressIndicator(
                                        modifier = Modifier.size(20.dp),
                                        color = Color.Black,
                                        strokeWidth = 2.dp
                                    )
                                    Spacer(Modifier.width(8.dp))
                                    Text(
                                        text = stringResource(R.string.challenge_checking_in),
                                        color = Color.Black,
                                        fontWeight = FontWeight.SemiBold
                                    )
                                }
                                todayCompleted -> {
                                    Icon(Icons.Default.EmojiEvents, contentDescription = null, tint = AppColors.Green)
                                    Spacer(Modifier.width(8.dp))
                                    Text(
                                        text = stringResource(R.string.challenge_checked_in_today),
                                        color = AppColors.Green,
                                        fontWeight = FontWeight.SemiBold
                                    )
                                }
                                else -> {
                                    Icon(Icons.Default.EmojiEvents, contentDescription = null, tint = Color.Black)
                                    Spacer(Modifier.width(8.dp))
                                    Text(
                                        text = stringResource(R.string.challenge_check_in),
                                        color = Color.Black,
                                        fontWeight = FontWeight.SemiBold
                                    )
                                }
                            }
                        }

                        if (checkInState is ChallengeCheckInState.CheckedIn) {
                            Text(
                                text = stringResource(
                                    R.string.challenge_check_in_success,
                                    (checkInState as ChallengeCheckInState.CheckedIn).response.streakDays
                                ),
                                color = AppColors.Mint,
                                fontSize = 14.sp,
                                fontWeight = FontWeight.Medium
                            )
                        }
                    } else {
                        // Not joined — show join CTA
                        Icon(
                            imageVector = Icons.Default.EmojiEvents,
                            contentDescription = null,
                            tint = AppColors.Mint.copy(alpha = 0.5f),
                            modifier = Modifier.size(64.dp)
                        )
                        Text(
                            text = stringResource(R.string.challenge_not_joined),
                            color = AppColors.TextSecondary,
                            fontSize = 16.sp,
                            fontWeight = FontWeight.Medium
                        )
                        Text(
                            text = stringResource(R.string.challenge_join_prompt),
                            color = AppColors.TextMuted,
                            fontSize = 13.sp,
                            textAlign = TextAlign.Center
                        )

                        Button(
                            onClick = onJoin,
                            enabled = joinState !is ChallengeJoinState.Joining,
                            modifier = Modifier.fillMaxWidth(),
                            colors = ButtonDefaults.buttonColors(
                                containerColor = AppColors.Mint,
                                disabledContainerColor = AppColors.Mint.copy(alpha = 0.5f)
                            ),
                            shape = RoundedCornerShape(14.dp)
                        ) {
                            if (joinState is ChallengeJoinState.Joining) {
                                CircularProgressIndicator(
                                    modifier = Modifier.size(20.dp),
                                    color = Color.Black,
                                    strokeWidth = 2.dp
                                )
                                Spacer(Modifier.width(8.dp))
                            }
                            Text(
                                text = if (joinState is ChallengeJoinState.Joining)
                                    stringResource(R.string.challenge_joining)
                                else stringResource(R.string.challenge_join_button),
                                color = Color.Black,
                                fontWeight = FontWeight.SemiBold
                            )
                        }
                    }
                }
            }
        }

        // ── Challenge Tasks ──────────────────────────────────────────────────────
        item {
            SectionTitle(text = stringResource(R.string.challenge_tasks_title))
        }
        item {
            DarkCard {
                Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
                    ChallengeTaskItem(
                        emoji = "🏃",
                        title = stringResource(R.string.challenge_task_drills),
                        completed = completedDays > 0
                    )
                    ChallengeTaskItem(
                        emoji = "📹",
                        title = stringResource(R.string.challenge_task_video),
                        completed = completedDays > 3
                    )
                    ChallengeTaskItem(
                        emoji = "🎉",
                        title = stringResource(R.string.challenge_task_complete),
                        completed = completedDays >= challenge.days
                    )
                }
            }
        }
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Challenge Leaderboard Tab
// ═══════════════════════════════════════════════════════════════════════════════

@Composable
private fun ChallengeLeaderboardTab(
    leaderboardState: ChallengeLeaderboardState,
    challenge: ChallengeInfo,
    onRefresh: () -> Unit
) {
    when (leaderboardState) {
        is ChallengeLeaderboardState.Loading -> {
            Box(
                modifier = Modifier.fillMaxSize(),
                contentAlignment = Alignment.Center
            ) {
                CircularProgressIndicator(color = AppColors.Mint)
            }
        }
        is ChallengeLeaderboardState.Error -> {
            ChallengeErrorCard(
                message = (leaderboardState as ChallengeLeaderboardState.Error).message,
                onRetry = onRefresh
            )
        }
        is ChallengeLeaderboardState.Empty -> {
            Box(
                modifier = Modifier.fillMaxSize(),
                contentAlignment = Alignment.Center
            ) {
                Column(
                    horizontalAlignment = Alignment.CenterHorizontally,
                    verticalArrangement = Arrangement.spacedBy(8.dp)
                ) {
                    Text(
                        text = "🏆",
                        fontSize = 48.sp
                    )
                    Text(
                        text = stringResource(R.string.challenge_leaderboard_empty),
                        color = AppColors.TextSecondary,
                        fontSize = 16.sp,
                        fontWeight = FontWeight.Medium
                    )
                }
            }
        }
        is ChallengeLeaderboardState.Success -> {
            val data = leaderboardState as ChallengeLeaderboardState.Success
            LazyColumn(
                contentPadding = PaddingValues(16.dp),
                verticalArrangement = Arrangement.spacedBy(8.dp)
            ) {
                // My rank card
                if (data.myRank != null) {
                    item {
                        GlassCard {
                            Row(
                                modifier = Modifier.fillMaxWidth(),
                                verticalAlignment = Alignment.CenterVertically,
                                horizontalArrangement = Arrangement.spacedBy(12.dp)
                            ) {
                                Text(
                                    text = stringResource(R.string.challenge_my_rank, data.myRank),
                                    color = AppColors.Mint,
                                    fontSize = 16.sp,
                                    fontWeight = FontWeight.Bold
                                )
                                Spacer(Modifier.weight(1f))
                                Text(
                                    text = stringResource(
                                        R.string.challenge_my_days,
                                        challenge.completedDays ?: 0,
                                        challenge.days
                                    ),
                                    color = AppColors.TextSecondary,
                                    fontSize = 13.sp
                                )
                            }
                        }
                    }
                }

                // Leaderboard entries
                itemsIndexed(data.entries) { index, entry ->
                    val rankColor = when (entry.rank) {
                        1 -> AppColors.Yellow
                        2 -> AppColors.TextSecondary
                        3 -> AppColors.Orange
                        else -> AppColors.TextMuted
                    }
                    val bgColor = if (entry.isMe) AppColors.Mint.copy(alpha = 0.08f)
                    else Color.Transparent
                    val borderColor = if (entry.isMe) AppColors.Mint.copy(alpha = 0.3f)
                    else AppColors.Border

                    Box(
                        modifier = Modifier
                            .fillMaxWidth()
                            .clip(RoundedCornerShape(12.dp))
                            .background(bgColor)
                            .border(0.5.dp, borderColor, RoundedCornerShape(12.dp))
                            .padding(horizontal = 14.dp, vertical = 12.dp)
                    ) {
                        Row(
                            verticalAlignment = Alignment.CenterVertically,
                            horizontalArrangement = Arrangement.spacedBy(12.dp)
                        ) {
                            // Rank
                            Box(
                                modifier = Modifier
                                    .size(36.dp)
                                    .clip(CircleShape)
                                    .background(rankColor.copy(alpha = 0.15f)),
                                contentAlignment = Alignment.Center
                            ) {
                                Text(
                                    text = "${entry.rank}",
                                    color = rankColor,
                                    fontSize = 15.sp,
                                    fontWeight = FontWeight.Bold,
                                    fontFamily = FontFamily.Monospace
                                )
                            }

                            // Avatar
                            val displayName = entry.displayName ?: entry.nickname ?: entry.name ?: "?"
                            Box(
                                modifier = Modifier
                                    .size(40.dp)
                                    .clip(CircleShape)
                                    .background(
                                        Brush.linearGradient(
                                            colors = listOf(AppColors.Violet, AppColors.Cyan)
                                        )
                                    ),
                                contentAlignment = Alignment.Center
                            ) {
                                Text(
                                    text = displayName.first().uppercase(),
                                    color = Color.White,
                                    fontSize = 18.sp,
                                    fontWeight = FontWeight.Bold
                                )
                            }

                            // Name + stats
                            Column(modifier = Modifier.weight(1f)) {
                                Row(verticalAlignment = Alignment.CenterVertically) {
                                    Text(
                                        text = displayName,
                                        color = if (entry.isMe) AppColors.Mint else Color.White,
                                        fontSize = 15.sp,
                                        fontWeight = FontWeight.SemiBold
                                    )
                                    if (entry.isMe) {
                                        Spacer(Modifier.width(6.dp))
                                        Text(
                                            text = stringResource(R.string.challenge_you),
                                            color = AppColors.Mint,
                                            fontSize = 11.sp,
                                            fontWeight = FontWeight.Bold
                                        )
                                    }
                                }
                                Row(
                                    horizontalArrangement = Arrangement.spacedBy(12.dp)
                                ) {
                                    Text(
                                        text = stringResource(
                                            R.string.challenge_completed_days_short,
                                            entry.completedDays ?: 0
                                        ),
                                        color = AppColors.TextSecondary,
                                        fontSize = 12.sp
                                    )
                                    if (entry.cadenceImprovementPct != null) {
                                        Text(
                                            text = stringResource(
                                                R.string.challenge_cadence_pct,
                                                entry.cadenceImprovementPct
                                            ),
                                            color = if (entry.cadenceImprovementPct >= 0) AppColors.Green
                                            else AppColors.Red,
                                            fontSize = 12.sp
                                        )
                                    }
                                }
                            }

                            // Improvement arrow
                            if (entry.overallScoreChange != null) {
                                val isPositive = entry.overallScoreChange >= 0
                                Text(
                                    text = if (isPositive) "↑" else "↓",
                                    color = if (isPositive) AppColors.Green else AppColors.Red,
                                    fontSize = 18.sp,
                                    fontWeight = FontWeight.Bold
                                )
                            }
                        }
                    }
                }
            }
        }
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Shared Components
// ═══════════════════════════════════════════════════════════════════════════════

@Composable
private fun ChallengeInfoChip(label: String, value: String) {
    Column {
        Text(
            text = label,
            color = AppColors.TextMuted,
            fontSize = 11.sp,
            fontWeight = FontWeight.Medium,
            letterSpacing = 0.5.sp
        )
        Spacer(Modifier.height(2.dp))
        Text(
            text = value,
            color = AppColors.TextSecondary,
            fontSize = 13.sp
        )
    }
}

@Composable
private fun ChallengeTaskItem(emoji: String, title: String, completed: Boolean) {
    Row(
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(12.dp)
    ) {
        Text(text = emoji, fontSize = 24.sp)
        Text(
            text = title,
            color = if (completed) AppColors.Mint else AppColors.TextSecondary,
            fontSize = 15.sp,
            fontWeight = if (completed) FontWeight.SemiBold else FontWeight.Normal,
            modifier = Modifier.weight(1f)
        )
        if (completed) {
            Text(
                text = "✓",
                color = AppColors.Mint,
                fontSize = 18.sp,
                fontWeight = FontWeight.Bold
            )
        } else {
            Box(
                modifier = Modifier
                    .size(22.dp)
                    .clip(CircleShape)
                    .background(AppColors.Border)
            )
        }
    }
}

@Composable
private fun ChallengeErrorCard(message: String, onRetry: () -> Unit) {
    Box(
        modifier = Modifier
            .fillMaxSize()
            .padding(24.dp),
        contentAlignment = Alignment.Center
    ) {
        DarkCard(modifier = Modifier.fillMaxWidth()) {
            Column(
                horizontalAlignment = Alignment.CenterHorizontally,
                verticalArrangement = Arrangement.spacedBy(12.dp)
            ) {
                Text(
                    text = "⚠️",
                    fontSize = 40.sp
                )
                Text(
                    text = message,
                    color = AppColors.Red,
                    fontSize = 14.sp,
                    textAlign = TextAlign.Center
                )
                Text(
                    text = stringResource(R.string.challenge_tap_to_retry),
                    color = AppColors.Mint,
                    fontSize = 14.sp,
                    fontWeight = FontWeight.SemiBold,
                    modifier = Modifier.clickable { onRetry() }
                )
            }
        }
    }
}

@Composable
private fun ChallengeEmptyCard() {
    Box(
        modifier = Modifier
            .fillMaxSize()
            .padding(24.dp),
        contentAlignment = Alignment.Center
    ) {
        Column(
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(8.dp)
        ) {
            Text(text = "🏆", fontSize = 48.sp)
            Text(
                text = stringResource(R.string.challenge_no_challenges),
                color = AppColors.TextSecondary,
                fontSize = 16.sp,
                fontWeight = FontWeight.Medium
            )
            Text(
                text = stringResource(R.string.challenge_coming_soon),
                color = AppColors.TextMuted,
                fontSize = 13.sp
            )
        }
    }
}
