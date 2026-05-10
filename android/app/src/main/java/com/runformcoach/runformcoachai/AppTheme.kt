package com.runformcoach.runformcoachai

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxScope
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.darkColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp

// ── Palette ───────────────────────────────────────────────────────────────────

object AppColors {
    val Midnight = Color(0xFF050A17)
    val Navy = Color(0xFF08172B)
    val DeepBlue = Color(0xFF0D2142)
    val Ink = Color(0xFF0F1628)
    val Card = Color(0x18FFFFFF)    // white 9.5%
    val DarkCard = Color(0xFF0A1020)

    val Mint = Color(0xFF40F5C2)
    val Cyan = Color(0xFF1AABFF)
    val Violet = Color(0xFF7866FF)
    val Orange = Color(0xFFFF9E38)
    val Red = Color(0xFFFF5252)
    val Green = Color(0xFF69FF87)
    val Yellow = Color(0xFFFFE259)

    val TextPrimary = Color.White
    val TextSecondary = Color(0xA0FFFFFF)   // white 63%
    val TextMuted = Color(0x60FFFFFF)       // white 38%
    val Border = Color(0x20FFFFFF)          // white 12%
}

// ── Gradients ─────────────────────────────────────────────────────────────────

val BgGradient: Brush
    get() = Brush.linearGradient(
        colors = listOf(
            AppColors.Midnight,
            AppColors.Navy,
            AppColors.DeepBlue,
            Color(0xFF1C1A40)
        )
    )

val MintGradient = Brush.linearGradient(
    colors = listOf(AppColors.Mint, AppColors.Cyan)
)

val VioletGradient = Brush.linearGradient(
    colors = listOf(AppColors.Violet, AppColors.Cyan)
)

val WarmGradient = Brush.linearGradient(
    colors = listOf(AppColors.Orange, AppColors.Mint)
)

val RunFormColorScheme = darkColorScheme(
    primary = AppColors.Mint,
    secondary = AppColors.Cyan,
    tertiary = AppColors.Violet,
    background = AppColors.Midnight,
    surface = AppColors.Ink,
    surfaceVariant = AppColors.Navy,
    onBackground = Color.White,
    onSurface = Color.White,
    onSurfaceVariant = AppColors.TextSecondary,
    onPrimary = Color.Black,
    outline = AppColors.Border
)

// ── Theme wrapper ─────────────────────────────────────────────────────────────

@Composable
fun RunFormTheme(content: @Composable () -> Unit) {
    MaterialTheme(
        colorScheme = RunFormColorScheme,
        content = content
    )
}

// ── Shared composables ────────────────────────────────────────────────────────

@Composable
fun AppBackground(modifier: Modifier = Modifier, content: @Composable BoxScope.() -> Unit) {
    Box(
        modifier = modifier
            .fillMaxSize()
            .background(BgGradient),
        content = content
    )
}

@Composable
fun GlassCard(
    modifier: Modifier = Modifier,
    cornerRadius: Int = 16,
    content: @Composable () -> Unit
) {
    Box(
        modifier = modifier
            .clip(RoundedCornerShape(cornerRadius.dp))
            .background(AppColors.Card)
            .border(0.5.dp, AppColors.Border, RoundedCornerShape(cornerRadius.dp))
            .padding(16.dp)
    ) {
        content()
    }
}

@Composable
fun DarkCard(
    modifier: Modifier = Modifier,
    cornerRadius: Int = 16,
    content: @Composable () -> Unit
) {
    Box(
        modifier = modifier
            .clip(RoundedCornerShape(cornerRadius.dp))
            .background(AppColors.DarkCard)
            .border(0.5.dp, AppColors.Border, RoundedCornerShape(cornerRadius.dp))
            .padding(16.dp)
    ) {
        content()
    }
}

@Composable
fun SectionTitle(text: String, modifier: Modifier = Modifier) {
    Text(
        text = text.uppercase(),
        color = AppColors.TextSecondary,
        fontSize = 11.sp,
        fontWeight = FontWeight.Bold,
        letterSpacing = 1.5.sp,
        modifier = modifier.padding(vertical = 4.dp)
    )
}

fun categoryColor(category: String): Color = when (category.lowercase()) {
    "easy run", "easy" -> AppColors.Mint
    "long run", "long" -> AppColors.Cyan
    "tempo", "tempo run" -> AppColors.Orange
    "intervals", "interval", "speed" -> AppColors.Violet
    "recovery", "rest" -> AppColors.Green
    "strength", "strength & mobility", "mobility" -> AppColors.Yellow
    "cross-training", "cross training" -> AppColors.TextSecondary
    else -> AppColors.Cyan
}
