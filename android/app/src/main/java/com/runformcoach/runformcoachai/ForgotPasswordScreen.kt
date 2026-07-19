package com.runformcoach.runformcoachai

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.ArrowBack
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.material.icons.filled.Email
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.OutlinedTextFieldDefaults
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp

/**
 * Forgot-password screen — email-based password reset.
 *
 * Aligned with iOS LoginView.swift forgot-password flow (L130-138):
 *   1. User enters email
 *   2. Taps "发送重置邮件" → POST /api/v1/auth/reset-password
 *   3. On success → shows "重置邮件已发送，请查收" guidance
 *   4. Email format validation
 *   5. Network error / email-not-registered error messages
 *   6. Link back to login
 *
 * @param vm The shared [AppViewModel].
 * @param onNavigateToLogin Called when user taps "返回登录".
 */
@Composable
fun ForgotPasswordScreen(
    vm: AppViewModel,
    onNavigateToLogin: () -> Unit
) {
    var email by rememberSaveable { mutableStateOf("") }
    var localError by remember { mutableStateOf<String?>(null) }

    val state = vm.forgotPasswordState
    val isLoading = state is ForgotPasswordState.Loading
    val isSuccess = state is ForgotPasswordState.Success

    // Reset to idle when navigating away from success
    LaunchedEffect(Unit) {
        vm.resetForgotPasswordState()
    }

    // Clear local error when user edits email
    LaunchedEffect(email) {
        if (localError != null) localError = null
    }

    val textFieldColors = OutlinedTextFieldDefaults.colors(
        focusedBorderColor = AppColors.Mint,
        unfocusedBorderColor = AppColors.Border,
        focusedTextColor = Color.White,
        unfocusedTextColor = Color.White,
        cursorColor = AppColors.Mint,
        focusedLabelColor = AppColors.Mint,
        unfocusedLabelColor = AppColors.TextSecondary
    )

    AppBackground {
        Column(
            modifier = Modifier
                .fillMaxSize()
                .verticalScroll(rememberScrollState()),
            horizontalAlignment = Alignment.CenterHorizontally
        ) {
            Spacer(Modifier.height(48.dp))

            // ── App icon / branding ──────────────────────────────────────────
            Text(
                text = "RunForm",
                color = AppColors.Mint,
                fontSize = 36.sp,
                fontWeight = FontWeight.Bold,
                letterSpacing = 2.sp
            )
            Text(
                text = "智能跑步教练",
                color = AppColors.TextSecondary,
                fontSize = 16.sp
            )

            Spacer(Modifier.height(32.dp))

            // ── Forgot-password card ─────────────────────────────────────────
            GlassCard(modifier = Modifier.fillMaxWidth().padding(horizontal = 24.dp)) {
                Column(verticalArrangement = Arrangement.spacedBy(16.dp)) {

                    when {
                        // ── Success state ────────────────────────────────────
                        isSuccess -> {
                            SuccessContent(
                                email = email.trim().lowercase(),
                                onBackToLogin = {
                                    vm.resetForgotPasswordState()
                                    onNavigateToLogin()
                                }
                            )
                        }

                        // ── Form state ───────────────────────────────────────
                        else -> {
                            SectionTitle("忘记密码")

                            // Instructional text
                            Text(
                                text = "请输入注册时使用的邮箱地址，我们将发送一封密码重置邮件。",
                                color = AppColors.TextSecondary,
                                fontSize = 14.sp,
                                lineHeight = 20.sp
                            )

                            // Email input
                            OutlinedTextField(
                                value = email,
                                onValueChange = { email = it },
                                label = { Text("邮箱") },
                                placeholder = { Text("you@example.com", color = AppColors.TextMuted) },
                                singleLine = true,
                                leadingIcon = {
                                    Icon(Icons.Default.Email, contentDescription = null, tint = AppColors.Mint)
                                },
                                keyboardOptions = KeyboardOptions(
                                    keyboardType = KeyboardType.Email,
                                    imeAction = ImeAction.Done
                                ),
                                modifier = Modifier.fillMaxWidth(),
                                colors = textFieldColors,
                                enabled = !isLoading
                            )

                            // Error message (from VM or local validation)
                            val displayError = (state as? ForgotPasswordState.Error)?.message
                                ?: localError
                            AnimatedVisibility(
                                visible = displayError != null,
                                enter = fadeIn(),
                                exit = fadeOut()
                            ) {
                                Text(
                                    text = displayError ?: "",
                                    color = AppColors.Red,
                                    fontSize = 13.sp,
                                    modifier = Modifier.fillMaxWidth(),
                                    textAlign = TextAlign.Center
                                )
                            }

                            // Send reset email button
                            Button(
                                onClick = {
                                    val trimmedEmail = email.trim().lowercase()
                                    when {
                                        trimmedEmail.isEmpty() -> {
                                            localError = "请输入邮箱地址"
                                        }
                                        !isValidEmail(trimmedEmail) -> {
                                            localError = "请输入有效的邮箱地址"
                                        }
                                        else -> {
                                            localError = null
                                            vm.resetPassword(trimmedEmail)
                                        }
                                    }
                                },
                                modifier = Modifier.fillMaxWidth().height(52.dp),
                                shape = RoundedCornerShape(14.dp),
                                colors = ButtonDefaults.buttonColors(
                                    containerColor = AppColors.Mint,
                                    contentColor = Color.Black,
                                    disabledContainerColor = AppColors.Mint.copy(alpha = 0.4f),
                                    disabledContentColor = Color.Black.copy(alpha = 0.5f)
                                ),
                                enabled = !isLoading
                            ) {
                                if (isLoading) {
                                    CircularProgressIndicator(
                                        modifier = Modifier.size(22.dp),
                                        color = Color.Black,
                                        strokeWidth = 2.dp
                                    )
                                    Spacer(Modifier.width(8.dp))
                                    Text("发送中…", fontWeight = FontWeight.Bold, fontSize = 16.sp)
                                } else {
                                    Text("发送重置邮件", fontWeight = FontWeight.Bold, fontSize = 16.sp)
                                }
                            }
                        }
                    }
                }
            }

            // ── Back-to-login link (always visible except during loading) ────
            if (!isSuccess) {
                Spacer(Modifier.height(20.dp))
                Row(
                    modifier = Modifier.fillMaxWidth().padding(horizontal = 24.dp),
                    horizontalArrangement = Arrangement.Center
                ) {
                    TextButton(onClick = {
                        vm.resetForgotPasswordState()
                        onNavigateToLogin()
                    }) {
                        Icon(
                            Icons.Default.ArrowBack,
                            contentDescription = null,
                            tint = AppColors.Mint,
                            modifier = Modifier.size(18.dp)
                        )
                        Spacer(Modifier.width(4.dp))
                        Text(
                            text = "返回登录",
                            color = AppColors.Mint,
                            fontSize = 14.sp,
                            fontWeight = FontWeight.SemiBold
                        )
                    }
                }
            }

            Spacer(Modifier.height(48.dp))
        }
    }
}

// ── Success State ──────────────────────────────────────────────────────────────

/**
 * Rendered inside [GlassCard] when the reset-password API returns success.
 * Shows a confirmation icon, message, and a back-to-login button.
 */
@Composable
private fun SuccessContent(
    email: String,
    onBackToLogin: () -> Unit
) {
    Column(
        modifier = Modifier.fillMaxWidth(),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(16.dp)
    ) {
        // ── Success icon ────────────────────────────────────────────────────
        Icon(
            Icons.Default.CheckCircle,
            contentDescription = "成功",
            tint = AppColors.Mint,
            modifier = Modifier.size(56.dp)
        )

        // ── Title ───────────────────────────────────────────────────────────
        Text(
            text = "重置邮件已发送",
            color = Color.White,
            fontSize = 20.sp,
            fontWeight = FontWeight.Bold
        )

        // ── Guidance text ───────────────────────────────────────────────────
        Text(
            text = "重置邮件已发送，请查收",
            color = AppColors.Mint,
            fontSize = 16.sp,
            fontWeight = FontWeight.SemiBold,
            textAlign = TextAlign.Center
        )

        // ── Detail ──────────────────────────────────────────────────────────
        Text(
            text = "我们已将重置密码的链接发送至\n$email\n请检查收件箱（包括垃圾邮件），点击链接完成密码重置。",
            color = AppColors.TextSecondary,
            fontSize = 14.sp,
            textAlign = TextAlign.Center,
            lineHeight = 22.sp
        )

        // ── Back to login button ────────────────────────────────────────────
        Spacer(Modifier.height(8.dp))
        Button(
            onClick = onBackToLogin,
            modifier = Modifier.fillMaxWidth().height(48.dp),
            shape = RoundedCornerShape(14.dp),
            colors = ButtonDefaults.buttonColors(
                containerColor = AppColors.Mint,
                contentColor = Color.Black
            )
        ) {
            Text("返回登录", fontWeight = FontWeight.Bold, fontSize = 16.sp)
        }
    }
}

// ── Helpers ────────────────────────────────────────────────────────────────────

/** Basic email format validation (mirrors iOS isValidEmail). */
private fun isValidEmail(email: String): Boolean {
    if (email.isEmpty() || email.contains(" ")) return false
    return email.matches(Regex("^[A-Za-z0-9+_.-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}$"))
}
