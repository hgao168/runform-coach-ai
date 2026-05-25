package com.runformcoach.runformcoachai

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.DirectionsRun
import androidx.compose.material.icons.filled.History
import androidx.compose.material.icons.filled.Person
import androidx.compose.material.icons.filled.QueryStats
import androidx.compose.material3.Icon
import androidx.compose.material3.NavigationBar
import androidx.compose.material3.NavigationBarItem
import androidx.compose.material3.NavigationBarItemDefaults
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.lifecycle.viewmodel.compose.viewModel

data class TabItem(val label: String, val icon: ImageVector)

private val TABS = listOf(
    TabItem("Analyze", Icons.Default.DirectionsRun),
    TabItem("History", Icons.Default.History),
    TabItem("Plan", Icons.Default.QueryStats),
    TabItem("Profile", Icons.Default.Person)
)

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()
        setContent {
            RunFormTheme {
                AppRoot()
            }
        }
    }
}

@Composable
fun AppRoot(vm: AppViewModel = viewModel()) {
    val context = LocalContext.current

    // Initialize persistence on first composition
    LaunchedEffect(Unit) { vm.init(context) }

    var selectedTab by remember { mutableIntStateOf(0) }

    AppBackground {
        Scaffold(
            containerColor = Color.Transparent,
            bottomBar = {
                NavigationBar(
                    containerColor = AppColors.Ink,
                    tonalElevation = 0.dp
                ) {
                    TABS.forEachIndexed { index, tab ->
                        val selected = selectedTab == index
                        NavigationBarItem(
                            selected = selected,
                            onClick = { selectedTab = index },
                            icon = {
                                Icon(tab.icon, contentDescription = tab.label)
                            },
                            label = {
                                Text(
                                    tab.label,
                                    fontSize = 11.sp,
                                    fontWeight = if (selected) FontWeight.SemiBold else FontWeight.Normal
                                )
                            },
                            colors = NavigationBarItemDefaults.colors(
                                selectedIconColor = AppColors.Mint,
                                selectedTextColor = AppColors.Mint,
                                unselectedIconColor = AppColors.TextMuted,
                                unselectedTextColor = AppColors.TextMuted,
                                indicatorColor = AppColors.Mint.copy(alpha = 0.15f)
                            )
                        )
                    }
                }
            }
        ) { innerPadding ->
            Box(
                modifier = Modifier
                    .fillMaxSize()
                    .padding(innerPadding)
            ) {
                when (selectedTab) {
                    0 -> AnalyzeScreen(vm)
                    1 -> HistoryScreen(vm)
                    2 -> PlanScreen(vm)
                    3 -> ProfileScreen(vm)
                }
            }
        }
    }
}

