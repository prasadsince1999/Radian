import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_strings.dart';
import '../../mcp/mcp_server.dart';
import 'clock_controller.dart';

class McpServerState {
  final bool isRunning;
  final int port;
  final String localIp;
  final List<String> logs;

  const McpServerState({
    this.isRunning = false,
    this.port = AppStrings.mcpDefaultPort,
    this.localIp = AppStrings.mcpFallbackHost,
    this.logs = const [],
  });

  String get sseUrl => 'http://$localIp:$port/sse';
  String get rpcUrl => 'http://$localIp:$port/mcp';
  String get openApiUrl => 'http://$localIp:$port/api/openapi.json';
  String get grokToolsUrl => 'http://$localIp:$port/api/grok/tools.json';

  McpServerState copyWith({
    bool? isRunning,
    int? port,
    String? localIp,
    List<String>? logs,
  }) {
    return McpServerState(
      isRunning: isRunning ?? this.isRunning,
      port: port ?? this.port,
      localIp: localIp ?? this.localIp,
      logs: logs ?? this.logs,
    );
  }
}

class McpServerController extends StateNotifier<McpServerState> {
  final Ref _ref;
  McpServer? _server;

  McpServerController(this._ref, {bool autoStart = true})
    : super(const McpServerState()) {
    if (autoStart) {
      _init();
    }
  }

  Future<void> _init() async {
    final ip = await _detectLocalIp();
    state = state.copyWith(localIp: ip);
    // Auto-start embedded server
    await startServer();
  }

  Future<String> _detectLocalIp() async {
    try {
      final interfaces = await NetworkInterface.list(
        includeLoopback: false,
        type: InternetAddressType.IPv4,
      );
      for (final iface in interfaces) {
        for (final addr in iface.addresses) {
          if (!addr.isLoopback && addr.address.startsWith('192.') ||
              addr.address.startsWith('10.') ||
              addr.address.startsWith('172.')) {
            return addr.address;
          }
        }
      }
    } catch (_) {}
    return AppStrings.mcpFallbackHost;
  }

  void _addLog(String msg) {
    final timestamp = DateTime.now().toIso8601String().substring(11, 19);
    final entry = '[$timestamp] $msg';
    final updated = [entry, ...state.logs];
    if (updated.length > 50) updated.removeLast();
    state = state.copyWith(logs: updated);
  }

  Future<void> startServer([int? port]) async {
    if (_server != null) return;
    final targetPort = port ?? state.port;

    final repo = _ref.read(eventRepositoryProvider);
    _server = McpServer(
      repository: repo,
      getSettings: () => _ref.read(dialSettingsProvider),
      updateSettings: (s) =>
          _ref.read(dialSettingsProvider.notifier).updateSettings(s),
      onLog: _addLog,
    );

    final success = await _server!.start(port: targetPort);
    state = state.copyWith(isRunning: success, port: _server!.port);
  }

  Future<void> stopServer() async {
    await _server?.stop();
    _server = null;
    state = state.copyWith(isRunning: false);
  }

  Future<void> restartWithPort(int newPort) async {
    await stopServer();
    await startServer(newPort);
  }

  @override
  void dispose() {
    _server?.stop();
    super.dispose();
  }
}

final mcpServerControllerProvider =
    StateNotifierProvider<McpServerController, McpServerState>((ref) {
      return McpServerController(ref);
    });
