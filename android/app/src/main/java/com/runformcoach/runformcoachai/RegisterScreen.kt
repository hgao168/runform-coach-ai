package com.runformcoach.runformcoachai

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
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
import androidx.compose.foundation.text.KeyboardActions
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Email
import androidx.compose.material.icons.filled.Lock
import androidx.compose.material.icons.filled.Person
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
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalFocusManager
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.input.PasswordVisualTransformation
import androidx.compose.ui.text.input.VisualTransformation
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp

// ── Password strength enum ─────────────────────────────────────────────────────

enum class PasswordStrength { WEAK, MEDIUM, STRONG }

// ── Register Screen ────────────────────────────────────────────────────────────

/**
 * Full-screen registration UI aligned with iOS LoginView.swift register flow.
 *
 * Fields: email, password, confirm password, nickname (optional).
 * Includes password strength indicator, loading state, error message, and
 * a bottom link to navigate to login.
 *
 * @param onRegisterSuccess Called after successful registration (token stored, ready to navigate).
 * @param onNavigateToLogin Called when user taps "已有账号？去登录".
 */
@Composable
fun RegisterScreen(
    vm: AppViewModel,
    onRegisterSuccess: () -> Unit,
    onNavigateToLogin: () -> Unit
) {
    var email by rememberSaveable { mutableStateOf("") }
    var password by rememberSaveable { mutableStateOf("") }
    var confirmPassword by rememberSaveable { mutableStateOf("") }
    var nickname by rememberSaveable { mutableStateOf("") }
    var passwordVisible by rememberSaveable { mutableStateOf(false) }
    var confirmPasswordVisible by rememberSaveable { mutableStateOf(false) }
    var localError by remember { mutableStateOf<String?>(null) }
    val focusManager = LocalFocusManager.current

    val loginState = vm.loginState
    val isLoading = loginState is LoginState.Loading

    // Clear local error when API state changes
    val apiError = (loginState as? LoginState.Error)?.message

    // Watch for success
    if (loginState is LoginState.Success) {
        onRegisterSuccess()
        vm.resetLoginState()
    }

    AppBackground {
        Column(
            modifier = Modifier
                .fillMaxSize()
                .verticalScroll(rememberScrollState())
                .padding(horizontal = 24.dp, vertical = 32.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.Center
        ) {
            // ── Header ──────────────────────────────────────────────────────────
            Text(
                text = "注册",
                color = Color.White,
                fontSize = 28.sp,
                fontWeight = FontWeight.Bold
            )
            Spacer(Modifier.height(6.dp))
            Text(
                text = "创建账号以同步你的数据",
                color = AppColors.TextSecondary,
                fontSize = 14.sp
            )
            Spacer(Modifier.height(32.dp))

            // ── Form Card ───────────────────────────────────────────────────────
            GlassCard(modifier = Modifier.fillMaxWidth()) {
                Column(verticalArrangement = Arrangement.spacedBy(16.dp)) {

                    // -- Nickname (optional) --
                    OutlinedTextField(
                        value = nickname,
                        onValueChange = { nickname = it; localError = null },
                        label = { Text("昵称（可选）") },
                        placeholder = { Text("你的昵称", color = AppColors.TextMuted) },
                        leadingIcon = {
                            Icon(Icons.Default.Person, contentDescription = null, tint = AppColors.TextSecondary)
                        },
                        singleLine = true,
                        modifier = Modifier.fillMaxWidth(),
                        colors = textFieldColors(),
                        keyboardOptions = KeyboardOptions(imeAction = ImeAction.Next)
                    )

                    // -- Email --
                    OutlinedTextField(
                        value = email,
                        onValueChange = { email = it; localError = null },
                        label = { Text("邮箱") },
                        placeholder = { Text("you@example.com", color = AppColors.TextMuted) },
                        leadingIcon = {
                            Icon(Icons.Default.Email, contentDescription = null, tint = AppColors.TextSecondary)
                        },
                        singleLine = true,
                        modifier = Modifier.fillMaxWidth(),
                        colors = textFieldColors(),
                        keyboardOptions = KeyboardOptions(
                            keyboardType = KeyboardType.Email,
                            imeAction = ImeAction.Next
                        )
                    )

                    // -- Password --
                    OutlinedTextField(
                        value = password,
                        onValueChange = { password = it; localError = null },
                        label = { Text("密码") },
                        placeholder = { Text("至少6位字符", color = AppColors.TextMuted) },
                        leadingIcon = {
                            Icon(Icons.Default.Lock, contentDescription = null, tint = AppColors.TextSecondary)
                        },
                        trailingIcon = {
                            IconButton(onClick = { passwordVisible = !passwordVisible }) {
                                Icon(
                                    if (passwordVisible) Icons.Default.VisibilityOff else Icons.Default.Visibility,
                                    contentDescription = if (passwordVisible) "隐藏密码" else "显示密码",
                                    tint = AppColors.TextSecondary
                                )
                            }
                        },
                        singleLine = true,
                        visualTransformation = if (passwordVisible) VisualTransformation.None else PasswordVisualTransformation(),
                        modifier = Modifier.fillMaxWidth(),
                        colors = textFieldColors(),
                        keyboardOptions = KeyboardOptions(
                            keyboardType = KeyboardType.Password,
                            imeAction = ImeAction.Next
                        )
                    )

                    // -- Password strength indicator --
                    AnimatedVisibility(
                        visible = password.isNotEmpty(),
                        enter = fadeIn(),
                        exit = fadeOut()
                    ) {
                        PasswordStrengthBar(password)
                    }

                    // -- Confirm Password --
                    OutlinedTextField(
                        value = confirmPassword,
                        onValueChange = { confirmPassword = it; localError = null },
                        label = { Text("确认密码") },
                        placeholder = { Text("再次输入密码", color = AppColors.TextMuted) },
                        leadingIcon = {
                            Icon(Icons.Default.Lock, contentDescription = null, tint = AppColors.TextSecondary)
                        },
                        trailingIcon = {
                            IconButton(onClick = { confirmPasswordVisible = !confirmPasswordVisible }) {
                                Icon(
                                    if (confirmPasswordVisible) Icons.Default.VisibilityOff else Icons.Default.Visibility,
                                    contentDescription = if (confirmPasswordVisible) "隐藏密码" else "显示密码",
                                    tint = AppColors.TextSecondary
                                )
                            }
                        },
                        singleLine = true,
                        visualTransformation = if (confirmPasswordVisible) VisualTransformation.None else PasswordVisualTransformation(),
                        modifier = Modifier.fillMaxWidth(),
                        colors = textFieldColors(),
                        keyboardOptions = KeyboardOptions(
                            keyboardType = KeyboardType.Password,
                            imeAction = ImeAction.Done
                        ),
                        keyboardActions = KeyboardActions(
                            onDone = { focusManager.clearFocus() }
                        ),
                        isError = confirmPassword.isNotEmpty() && password != confirmPassword
                    )

                    // -- Confirm password match hint --
                    if (confirmPassword.isNotEmpty() && password != confirmPassword) {
                        Text(
                            text = "两次输入的密码不一致",
                            color = AppColors.Red,
                            fontSize = 12.sp
                        )
                    }

                    // ── Register Button ──────────────────────────────────────────
                    Button(
                        onClick = {
                            focusManager.clearFocus()
                            val validationError = validateInputs(email, password, confirmPassword)
                            if (validationError != null) {
                                localError = validationError
                                return@Button
                            }
                            localError = null
                            vm.register(
                                email = email.trim().lowercase(),
                                password = password,
                                nickname = nickname
                            )
                        },
                        enabled = !isLoading,
                        modifier = Modifier
                            .fillMaxWidth()
                            .height(52.dp),
                        shape = RoundedCornerShape(14.dp),
                        colors = ButtonDefaults.buttonColors(
                            containerColor = AppColors.Mint,
                            contentColor = Color.Black,
                            disabledContainerColor = AppColors.Mint.copy(alpha = 0.4f),
                            disabledContentColor = Color.Black.copy(alpha = 0.5f)
                        )
                    ) {
                        if (isLoading) {
                            CircularProgressIndicator(
                                modifier = Modifier.size(22.dp),
                                color = Color.Black,
                                strokeWidth = 2.dp
                            )
                            Spacer(Modifier.width(10.dp))
                            Text("注册中…", fontWeight = FontWeight.Bold, fontSize = 16.sp)
                        } else {
                            Text("注册", fontWeight = FontWeight.Bold, fontSize = 16.sp)
                        }
                    }
                }
            }

            // ── Error message ────────────────────────────────────────────────────
            AnimatedVisibility(
                visible = localError != null || apiError != null,
                enter = fadeIn(),
                exit = fadeOut()
            ) {
                val errorText = apiError ?: localError ?: ""
                Text(
                    text = errorText,
                    color = AppColors.Red,
                    fontSize = 13.sp,
                    textAlign = TextAlign.Center,
                    modifier = Modifier
                        .padding(top = 16.dp)
                        .fillMaxWidth()
                )
            }

            Spacer(Modifier.height(24.dp))

            // ── Bottom link to login ─────────────────────────────────────────────
            Row(
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.Center
            ) {
                Text(
                    text = "已有账号？",
                    color = AppColors.TextSecondary,
                    fontSize = 14.sp
                )
                TextButton(onClick = {
                    vm.resetLoginState()
                    onNavigateToLogin()
                }) {
                    Text(
                        text = "去登录",
                        color = AppColors.Mint,
                        fontSize = 14.sp,
                        fontWeight = FontWeight.Bold
                    )
                }
            }

            Spacer(Modifier.height(16.dp))
        }
    }
}

// ── Password Strength Bar ──────────────────────────────────────────────────────

@Composable
private fun PasswordStrengthBar(password: String) {
    val strength = evaluatePasswordStrength(password)

    Column(modifier = Modifier.fillMaxWidth()) {
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.spacedBy(6.dp)
        ) {
            repeat(3) { index ->
                val isActive = when (strength) {
                    PasswordStrength.WEAK -> index == 0
                    PasswordStrength.MEDIUM -> index <= 1
                    PasswordStrength.STRONG -> true
                }
                val color = when {
                    !isActive -> AppColors.Border
                    strength == PasswordStrength.WEAK -> AppColors.Red
                    strength == PasswordStrength.MEDIUM -> AppColors.Orange
                    strength == PasswordStrength.STRONG -> AppColors.Green
                    else -> AppColors.Border
                }
                Box(
                    modifier = Modifier
                        .weight(1f)
                        .height(4.dp)
                        .background(color, RoundedCornerShape(2.dp))
                )
            }
        }
        Spacer(Modifier.height(4.dp))
        Text(
            text = when (strength) {
                PasswordStrength.WEAK -> "弱 — 建议使用8位以上混合字符"
                PasswordStrength.MEDIUM -> "中 — 建议添加特殊字符"
                PasswordStrength.STRONG -> "强 — 密码强度良好"
            },
            color = when (strength) {
                PasswordStrength.WEAK -> AppColors.Red
                PasswordStrength.MEDIUM -> AppColors.Orange
                PasswordStrength.STRONG -> AppColors.Green
            },
            fontSize = 11.sp
        )
    }
}

// ── Helpers ────────────────────────────────────────────────────────────────────

private fun evaluatePasswordStrength(password: String): PasswordStrength {
    if (password.length < 6) return PasswordStrength.WEAK
    val hasLower = password.any { it.isLowerCase() }
    val hasUpper = password.any { it.isUpperCase() }
    val hasDigit = password.any { it.isDigit() }
    val hasSpecial = password.any { !it.isLetterOrDigit() }
    val variety = listOf(hasLower, hasUpper, hasDigit, hasSpecial).count { it }

    return when {
        password.length >= 12 && variety >= 3 -> PasswordStrength.STRONG
        password.length >= 8 && variety >= 2 -> PasswordStrength.MEDIUM
        else -> PasswordStrength.WEAK
    }
}

private fun validateInputs(email: String, password: String, confirmPassword: String): String? {
    val trimmedEmail = email.trim()
    if (trimmedEmail.isEmpty()) return "请输入邮箱地址"
    if (!isValidEmail(trimmedEmail)) return "请输入有效的邮箱地址"

    if (password.isEmpty()) return "请输入密码"
    if (password.length < 6) return "密码至少需要6位字符"

    if (confirmPassword.isEmpty()) return "请确认密码"
    if (password != confirmPassword) return "两次输入的密码不一致"

    return null
}

private fun isValidEmail(email: String): Boolean {
    val trimmed = email.trim()
    if (trimmed.isEmpty() || trimmed.contains(" ")) return false
    // Simple RFC-like validation: must contain @ and a dot after @
    val atIndex = trimmed.indexOf('@')
    if (atIndex <= 0 || atIndex == trimmed.lastIndex) return false
    val domain = trimmed.substring(atIndex + 1)
    return domain.contains('.') && !domain.startsWith('.') && !domain.endsWith('.')
}

@Composable
private fun textFieldColors() = OutlinedTextFieldDefaults.colors(
    focusedBorderColor = AppColors.Mint,
    unfocusedBorderColor = AppColors.Border,
    focusedTextColor = Color.White,
    unfocusedTextColor = Color.White,
    cursorColor = AppColors.Mint,
    focusedLabelColor = AppColors.Mint,
    unfocusedLabelColor = AppColors.TextSecondary,
    focusedLeadingIconColor = AppColors.Mint,
    unfocusedLeadingIconColor = AppColors.TextSecondary,
    errorBorderColor = AppColors.Red,
    errorTextColor = AppColors.Red,
    errorLabelColor = AppColors.Red
)
