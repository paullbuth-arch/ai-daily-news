package com.example.voskasr.ui

import android.bluetooth.BluetoothDevice
import android.bluetooth.BluetoothManager
import android.content.ClipData
import android.content.ClipboardManager
import android.content.Context
import android.widget.Toast
import androidx.activity.compose.BackHandler
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Button
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.SegmentedButton
import androidx.compose.material3.SegmentedButtonDefaults
import androidx.compose.material3.SingleChoiceSegmentedButtonRow
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.TopAppBar
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.window.Dialog
import androidx.compose.ui.window.DialogProperties
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewmodel.compose.viewModel
import com.example.voskasr.audio.AsrEngine
import com.example.voskasr.audio.RecognizerState
import com.example.voskasr.domain.ConnectionState
import com.example.voskasr.domain.StreamingState
import com.example.voskasr.viewmodel.MainUiState
import com.example.voskasr.viewmodel.MainViewModel

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun MainScreen() {
    val context = LocalContext.current
    val factory = remember { MainViewModelFactory(context) }
    val viewModel: MainViewModel = viewModel(factory = factory)
    val uiState by viewModel.uiState.collectAsStateWithLifecycle()

    LaunchedEffect(Unit) {
        viewModel.events.collect { event ->
            when (event) {
                is MainViewModel.UiEvent.Toast -> Toast.makeText(context, event.message, Toast.LENGTH_SHORT).show()
            }
        }
    }

    var showDeviceDialog by remember { mutableStateOf(false) }
    var showResultFull by remember { mutableStateOf(false) }
    var showLogFull by remember { mutableStateOf(false) }

    // ---- Full-screen dialogs (dismissed by system back gesture) ----

    if (showResultFull) {
        FullScreenDialog(
            title = "识别结果",
            onDismiss = { showResultFull = false },
            onCopy = { copyToClipboard(context, buildString {
                if (uiState.finalText.isNotEmpty()) append(uiState.finalText + "\n\n")
                if (uiState.partialText.isNotEmpty()) append("[部分] " + uiState.partialText)
            }) },
            onClear = { viewModel.clearResults() },
            emptyHint = "等待识别..."
        ) {
            if (uiState.finalText.isNotEmpty()) {
                Text(uiState.finalText, style = MaterialTheme.typography.bodyLarge)
            }
            if (uiState.partialText.isNotEmpty()) {
                Text("[部分] " + uiState.partialText, color = Color.Gray,
                    style = MaterialTheme.typography.bodyMedium, modifier = Modifier.padding(top = 8.dp))
            }
        }
    }

    if (showLogFull) {
        FullScreenDialog(
            title = "日志",
            onDismiss = { showLogFull = false },
            onCopy = { copyToClipboard(context, uiState.logs.joinToString("\n")) },
            onClear = { viewModel.clearLogs() },
            emptyHint = "暂无日志"
        ) {
            val listState = rememberLazyListState()
            LaunchedEffect(uiState.logs.size) {
                if (uiState.logs.isNotEmpty()) listState.animateScrollToItem(uiState.logs.size - 1)
            }
            LazyColumn(state = listState, modifier = Modifier.fillMaxSize(),
                contentPadding = PaddingValues(vertical = 4.dp),
                verticalArrangement = Arrangement.spacedBy(2.dp)) {
                items(uiState.logs) { log ->
                    Text(log, style = MaterialTheme.typography.bodySmall)
                }
            }
        }
    }

    // ---- Main layout (original style) ----

    Scaffold(
        topBar = {
            TopAppBar(title = { Text("Glass ASR") })
        }
    ) { paddingValues ->
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(paddingValues)
                .padding(16.dp),
            verticalArrangement = Arrangement.spacedBy(12.dp)
        ) {
            StatusCard(uiState)
            EngineSelector(uiState, onSelect = { viewModel.setEngine(it) })
            ActionButtons(
                uiState = uiState,
                onConnectClick = { showDeviceDialog = true },
                onDisconnectClick = { viewModel.disconnect() },
                onStartClick = { viewModel.startStreaming() },
                onStopClick = { viewModel.stopStreaming() },
                onClearClick = { viewModel.clearResults() }
            )
            RecognitionResult(partial = uiState.partialText, final = uiState.finalText,
                onClick = { showResultFull = true })
            LogPanel(uiState.logs, onClick = { showLogFull = true })
        }
    }

    if (showDeviceDialog) {
        DeviceSelectionDialog(
            onDeviceSelected = { device -> viewModel.selectDevice(device); viewModel.connect(); showDeviceDialog = false },
            onDismiss = { showDeviceDialog = false }
        )
    }
}

// ---- Full-screen dialog with system back support ----

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun FullScreenDialog(
    title: String,
    onDismiss: () -> Unit,
    onCopy: () -> Unit,
    onClear: () -> Unit,
    emptyHint: String,
    content: @Composable () -> Unit
) {
    // System back gesture/button dismisses the dialog
    BackHandler(onBack = onDismiss)

    Dialog(
        onDismissRequest = onDismiss,
        properties = DialogProperties(usePlatformDefaultWidth = false) // full-screen
    ) {
        Scaffold(
            topBar = {
                TopAppBar(
                    title = { Text(title) },
                    navigationIcon = {
                        TextButton(onClick = onDismiss) { Text("关闭") }
                    },
                    actions = {
                        TextButton(onClick = onCopy) { Text("复制") }
                        TextButton(onClick = onClear) { Text("清空") }
                    }
                )
            }
        ) { paddingValues ->
            Surface(
                modifier = Modifier
                    .fillMaxSize()
                    .padding(paddingValues)
                    .padding(16.dp)
            ) {
                content()
            }
        }
    }
}

// ---- Status card ----

@Composable
private fun StatusCard(uiState: MainUiState) {
    Card(modifier = Modifier.fillMaxWidth(), elevation = CardDefaults.cardElevation(defaultElevation = 2.dp)) {
        Column(modifier = Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
            Text("状态", style = MaterialTheme.typography.titleMedium)
            Text("连接: ${connectionLabel(uiState.connectionState)}")
            Text("SCO: ${scoLabel(uiState.scoState)} ${if (uiState.scoReady) "✓" else ""}")
            Text("推流: ${streamingLabel(uiState.streamingState)}")
            Text("模型: ${if (uiState.modelLoaded) "已加载" else "加载中/失败"}")
            Text("引擎: ${uiState.activeEngineName.ifEmpty { "未选择" }} (${engineStateLabel(uiState.engineState)})")
        }
    }
}

// ---- Engine selector ----

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun EngineSelector(uiState: MainUiState, onSelect: (AsrEngine) -> Unit) {
    val options = listOf(AsrEngine.VOSK to "Vosk", AsrEngine.BAIDU to "百度", AsrEngine.AUTO to "AUTO")
    val selectedIndex = options.indexOfFirst { it.first == uiState.selectedEngine }.coerceAtLeast(0)

    Column(verticalArrangement = Arrangement.spacedBy(4.dp)) {
        Text("引擎", style = MaterialTheme.typography.titleMedium)
        SingleChoiceSegmentedButtonRow(modifier = Modifier.fillMaxWidth()) {
            options.forEachIndexed { index, (engine, label) ->
                SegmentedButton(
                    selected = index == selectedIndex,
                    onClick = { onSelect(engine) },
                    shape = SegmentedButtonDefaults.itemShape(index = index, count = options.size)
                ) { Text(label) }
            }
        }
    }
}

// ---- Action buttons ----

@Composable
private fun ActionButtons(
    uiState: MainUiState,
    onConnectClick: () -> Unit,
    onDisconnectClick: () -> Unit,
    onStartClick: () -> Unit,
    onStopClick: () -> Unit,
    onClearClick: () -> Unit
) {
    val connected = uiState.connectionState is ConnectionState.Connected
    val streaming = uiState.streamingState is StreamingState.Streaming

    Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
        Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            Button(onClick = onConnectClick, enabled = !uiState.isConnecting && !connected, modifier = Modifier.weight(1f)) {
                Text("连接设备")
            }
            Button(onClick = onDisconnectClick, enabled = connected, modifier = Modifier.weight(1f)) {
                Text("断开")
            }
        }
        Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            Button(onClick = onStartClick, enabled = connected && !streaming, modifier = Modifier.weight(1f)) {
                Text("开始推流")
            }
            Button(onClick = onStopClick, enabled = connected && streaming, modifier = Modifier.weight(1f)) {
                Text("停止推流")
            }
        }
        Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            Button(onClick = onClearClick, modifier = Modifier.weight(1f)) {
                Text("清空结果")
            }
            Button(onClick = { }, modifier = Modifier.weight(1f), enabled = false) { }
        }
    }
}

// ---- Recognition result (compact) ----

@Composable
private fun RecognitionResult(partial: String, final: String, onClick: () -> Unit) {
    Card(
        modifier = Modifier.fillMaxWidth().clickable { onClick() },
        elevation = CardDefaults.cardElevation(defaultElevation = 2.dp)
    ) {
        Column(modifier = Modifier.padding(16.dp)) {
            Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                Text("识别结果", style = MaterialTheme.typography.titleMedium)
                Text("展开 >", style = MaterialTheme.typography.labelSmall, color = Color.Gray)
            }
            if (final.isNotEmpty()) {
                Text(final, maxLines = 3, overflow = TextOverflow.Ellipsis, modifier = Modifier.padding(top = 8.dp))
            }
            Text(
                partial.ifEmpty { if (final.isEmpty()) "等待识别..." else "" },
                color = Color.Gray, maxLines = 1, overflow = TextOverflow.Ellipsis,
                modifier = Modifier.padding(top = 4.dp)
            )
        }
    }
}

// ---- Log panel (compact) ----

@Composable
private fun LogPanel(logs: List<String>, onClick: () -> Unit) {
    val listState = rememberLazyListState()
    LaunchedEffect(logs.size) {
        if (logs.isNotEmpty()) listState.animateScrollToItem(logs.size - 1)
    }

    Card(
        modifier = Modifier
            .fillMaxWidth()
            .height(240.dp)
            .clickable { onClick() },
        elevation = CardDefaults.cardElevation(defaultElevation = 2.dp)
    ) {
        Column(modifier = Modifier.padding(8.dp)) {
            Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                Text("日志", style = MaterialTheme.typography.titleMedium)
                Text("展开 >", style = MaterialTheme.typography.labelSmall, color = Color.Gray)
            }
            LazyColumn(state = listState, modifier = Modifier.fillMaxSize(),
                contentPadding = PaddingValues(vertical = 4.dp),
                verticalArrangement = Arrangement.spacedBy(2.dp)) {
                items(logs) { log ->
                    Text(log, style = MaterialTheme.typography.bodySmall)
                }
            }
        }
    }
}

// ---- Device selection dialog ----

@Composable
private fun DeviceSelectionDialog(
    onDeviceSelected: (BluetoothDevice) -> Unit,
    onDismiss: () -> Unit
) {
    val context = LocalContext.current
    val bluetoothManager = context.getSystemService(Context.BLUETOOTH_SERVICE) as? BluetoothManager
    val bondedDevices = remember {
        try { bluetoothManager?.adapter?.bondedDevices?.toList() ?: emptyList() } catch (_: SecurityException) { emptyList() }
    }

    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text("选择已配对的 glass 设备") },
        text = {
            LazyColumn {
                items(bondedDevices) { device ->
                    val name = try { device.name } catch (_: SecurityException) { "Unknown" }
                    TextButton(onClick = { onDeviceSelected(device) }, modifier = Modifier.fillMaxWidth()) {
                        Column(horizontalAlignment = Alignment.Start) {
                            Text(name)
                            Text(device.address, style = MaterialTheme.typography.bodySmall)
                        }
                    }
                }
            }
        },
        confirmButton = { TextButton(onClick = onDismiss) { Text("取消") } }
    )
}

// ---- Helpers ----

private fun copyToClipboard(context: Context, text: String) {
    if (text.isBlank()) return
    val clipboard = context.getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager
    clipboard.setPrimaryClip(ClipData.newPlainText("Glass ASR", text))
    Toast.makeText(context, "已复制", Toast.LENGTH_SHORT).show()
}

private fun connectionLabel(state: ConnectionState): String = when (state) {
    is ConnectionState.Disconnected -> "已断开"
    is ConnectionState.ConnectingControl -> "连接控制通道..."
    is ConnectionState.ConnectingData -> "连接数据通道..."
    is ConnectionState.Connected -> "已连接 (控制:${if (state.control) "是" else "否"}, 数据:${if (state.data) "是" else "否"})"
    is ConnectionState.Error -> "错误: ${state.reason}"
}
private fun streamingLabel(state: StreamingState): String = when (state) {
    is StreamingState.Idle -> "空闲"
    is StreamingState.Starting -> "启动中..."
    is StreamingState.Streaming -> "推流中"
    is StreamingState.Stopping -> "停止中..."
}
private fun engineStateLabel(state: RecognizerState): String = when (state) {
    is RecognizerState.Idle -> "空闲"
    is RecognizerState.Connecting -> "连接中"
    is RecognizerState.Ready -> "就绪"
    is RecognizerState.Error -> "错误: ${state.message}"
    is RecognizerState.Closed -> "已关闭"
}
private fun scoLabel(state: com.example.voskasr.bluetooth.HfpScoManager.ScoState): String = when (state) {
    com.example.voskasr.bluetooth.HfpScoManager.ScoState.DISCONNECTED -> "未连接"
    com.example.voskasr.bluetooth.HfpScoManager.ScoState.CONNECTING -> "连接中"
    com.example.voskasr.bluetooth.HfpScoManager.ScoState.CONNECTED -> "已连接"
    com.example.voskasr.bluetooth.HfpScoManager.ScoState.ERROR -> "错误"
}
