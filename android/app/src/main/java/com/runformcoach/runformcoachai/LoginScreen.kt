package com.runformcoach.runformcoachai

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
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
import androidx.compose.material.icons.filled.Email
import androidx.compose.material.icons.filled.Lock
import androidx.compose.material.icons.filled.Visibility
import androidx.compose.material.icons.filled.VisibilityOff
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.OutlinedTextFieldDefaults
import androidx.compose.material3.Text
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
import androidx.compose.ui.text.input.PasswordVisualTransformation
import androidx.compose.ui.text.input.VisualTransformation
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp

/**
 * Login screen — email + password authentication.
 *
 * Mirrors iOS LoginView.swift login flow:
 *   - Email / password inputs with validation
 *   - Loading state on the login button
 *   - Token persistence via [TokenManager] (stored in [AppViewModel])
 *   - Auto-skip to main UI if already authenticated (handled in [AppRoot])
 *   - Error messages for invalid credentials / network errors
 *   - Bottom links: "Forgot password?" + "No account? Register"
 *
 * @param onNavigateToForgotPassword Called when user taps "忘记密码？".
 * @param onNavigateToRegister Called when user taps "没有账号？去注册".
 */
@Composable
fun LoginScreen(
    vm: AppViewModel,
    onNavigateToForgotPassword: () -> Unit,
    onNavigateToRegister: () -> Unit
) {
    var email by rememberSaveable { mutableStateOf("") }
    var password by rememberSaveable { mutableStateOf("") }
    var passwordVisible by remember { mutableStateOf(false) }
    var localError by remember { mutableStateOf<String?>(null) }

    val loginState = vm.loginState
    val isLoading = loginState is LoginState.Loading

    // Clear local error when user starts typing again
    LaunchedEffect(email, password) {
        if (localError != null) localError = null
        if (loginState is LoginState.Error) vm.resetLoginState()
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

            // ── Login card ───────────────────────────────────────────────────
            GlassCard(modifier = Modifier.fillMaxWidth().padding(horizontal = 24.dp)) {
                Column(verticalArrangement = Arrangement.spacedBy(16.dp)) {
                    SectionTitle("登录")

                    // Email
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
                            imeAction = ImeAction.Next
                        ),
                        modifier = Modifier.fillMaxWidth(),
                        colors = textFieldColors,
                        enabled = !isLoading
                    )

                    // Password
                    OutlinedTextField(
                        value = password,
                        onValueChange = { password = it },
                        label = { Text("密码") },
                        placeholder = { Text("********", color = AppColors.TextMuted) },
                        singleLine = true,
                        leadingIcon = {
                            Icon(Icons.Default.Lock, contentDescription = null, tint = AppColors.Mint)
                        },
                        trailingIcon = {
                            IconButton(onClick = { passwordVisible = !passwordVisible }) {
                                Icon(
                                    imageVector = if (passwordVisible) Icons.Default.Visibility
                                        else Icons.Default.VisibilityOff,
                                    contentDescription = if (passwordVisible) "隐藏密码" else "显示密码",
                                    tint = AppColors.TextSecondary
                                )
                            }
                        },
                        visualTransformation = if (passwordVisible) VisualTransformation.None
                            else PasswordVisualTransformation(),
                        keyboardOptions = KeyboardOptions(
                            keyboardType = KeyboardType.Password,
                            imeAction = ImeAction.Done
                        ),
                        modifier = Modifier.fillMaxWidth(),
                        colors = textFieldColors,
                        enabled = !isLoading
                    )

                    // Error message (from VM or local validation)
                    val displayError = (loginState as? LoginState.Error)?.message ?: localError
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

                    // Login button
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
                                password.isEmpty() -> {
                                    localError = "请输入密码"
                                }
                                else -> {
                                    vm.login(trimmedEmail, password)
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
                            Text("登录中…", fontWeight = FontWeight.Bold, fontSize = 16.sp)
                        } else {
                            Text("登录", fontWeight = FontWeight.Bold, fontSize = 16.sp)
                        }
                    }
                }
            }

            Spacer(Modifier.height(20.dp))

            // ── Bottom links ─────────────────────────────────────────────────
            Row(
                modifier = Modifier.fillMaxWidth().padding(horizontal = 24.dp),
                horizontalArrangement = Arrangement.SpaceBetween
            ) {
                Text(
                    text = "忘记密码？",
                    color = AppColors.Mint,
                    fontSize = 14.sp,
                    fontWeight = FontWeight.SemiBold,
                    modifier = Modifier.clickable(enabled = !isLoading) {
                        vm.resetLoginState()
                        onNavigateToForgotPassword()
                    }
                )
                Text(
                    text = "没有账号？去注册",
                    color = AppColors.Mint,
                    fontSize = 14.sp,
                    fontWeight = FontWeight.SemiBold,
                    modifier = Modifier.clickable(enabled = !isLoading) {
                        vm.resetLoginState()
                        onNavigateToRegister()
                    }
                )
            }

            Spacer(Modifier.height(48.dp))
        }
    }
}

/** Basic email format validation (mirrors iOS isValidEmail). */
private fun isValidEmail(email: String): Boolean {
    if (email.isEmpty() || email.contains(" ")) return false
    // Simple regex: user@domain.tld
    return email.matches(Regex("^[A-Za-z0-9+_.-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}$"))
}
