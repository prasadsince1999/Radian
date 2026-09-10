import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_cors_headers/shelf_cors_headers.dart';
import 'package:shelf_router/shelf_router.dart';
import 'package:uuid/uuid.dart';

import '../core/constants/app_strings.dart';
import '../domain/models/dial_settings.dart';
import '../domain/repositories/event_repository.dart';
import 'mcp_tools.dart';

/// Embedded MCP and REST HTTP/SSE server running inside the Flutter app.
class McpServer {
  final EventRepository repository;
  final DialSettings Function() getSettings;
  final Future<void> Function(DialSettings) updateSettings;
  final void Function(String message)? onLog;

  HttpServer? _server;
  int _port = AppStrings.mcpDefaultPort;
  final Map<String, StreamController<String>> _sseClients = {};

  McpServer({
    required this.repository,
    required this.getSettings,
    required this.updateSettings,
    this.onLog,
  });

  bool get isRunning => _server != null;
  int get port => _port;

  void _log(String msg) {
    onLog?.call(msg);
  }

  Future<bool> start({int port = AppStrings.mcpDefaultPort}) async {
    if (_server != null) return true;
    _port = port;

    final router = Router();

    // 1. Unified MCP Endpoint (StreamableHTTP & JSON-RPC 2.0 for Gemini Spark, Claude, Cursor)
    router.get('/mcp', _handleMcpGet);
    router.post('/mcp', _handleJsonRpc);
    router.get('/rpc', _handleMcpGet);
    router.post('/rpc', _handleJsonRpc);

    // 2. Server-Sent Events (SSE for Grok Bot & Claude Desktop)
    router.get('/sse', _handleSse);
    router.post('/messages', _handleSseMessage);

    // 3. Direct REST endpoints (For ChatGPT Custom Actions & Webhooks)
    router.get('/api/state', _handleRestGetState);
    router.get('/api/sectors', _handleRestGetSectors);
    router.post('/api/bulk_plan', _handleRestBulkPlan);
    router.get('/api/settings', _handleRestGetSettings);
    router.post('/api/settings', _handleRestPostSettings);
    router.get('/api/openapi.json', _handleOpenApiSchema);
    router.get('/api/grok/tools.json', _handleGrokToolsSchema);

    final corsOptions = {
      ACCESS_CONTROL_ALLOW_ORIGIN: '*',
      'Access-Control-Allow-Methods': 'GET, POST, OPTIONS, HEAD, PUT, DELETE',
      'Access-Control-Allow-Headers': 'Origin, Content-Type, Accept, Authorization, Mcp-Session-Id, mcp-session-id',
      'Access-Control-Expose-Headers': 'Mcp-Session-Id, mcp-session-id',
    };

    final handler = Pipeline()
        .addMiddleware(corsHeaders(headers: corsOptions))
        .addMiddleware(logRequests(logger: (msg, isError) => _log(msg)))
        .addHandler(router.call);

    try {
      _server = await shelf_io.serve(handler, InternetAddress.anyIPv4, _port);
      _log('Sectograph MCP Server listening on http://0.0.0.0:$_port');
      return true;
    } catch (e) {
      _log('Failed to bind port $_port: $e. Trying $_port + 1...');
      try {
        _port++;
        _server = await shelf_io.serve(handler, InternetAddress.anyIPv4, _port);
        _log(
          'Sectograph MCP Server listening on fallback port http://0.0.0.0:$_port',
        );
        return true;
      } catch (err) {
        _log('Fatal error starting server: $err');
        return false;
      }
    }
  }

  Future<void> stop() async {
    for (final client in List.of(_sseClients.values)) {
      await client.close();
    }
    _sseClients.clear();
    await _server?.close(force: true);
    _server = null;
    _log('Sectograph MCP Server stopped.');
  }

  // --- Unified MCP GET Handler (StreamableHTTP & Server Discovery) ---
  Future<Response> _handleMcpGet(Request request) async {
    final accept = request.headers['accept'] ?? '';
    if (accept.contains('text/event-stream')) {
      return _handleSse(request);
    }

    final sessionId =
        request.headers['mcp-session-id'] ??
        request.headers['Mcp-Session-Id'] ??
        const Uuid().v4();

    final tools = McpTools.getToolDefinitions();
    final toolNames = tools.map((t) => t['name'] as String).toList();

    final info = {
      'name': AppStrings.appName,
      'protocol': 'Model Context Protocol (MCP)',
      'protocolVersion': '2024-11-05',
      'status': 'online',
      'transport': 'StreamableHTTP & JSON-RPC 2.0',
      'serverInfo': {
        'name': AppStrings.appName,
        'version': AppStrings.appVersion,
      },
      'capabilities': {
        'tools': {'listChanged': false},
        'resources': {'subscribe': false},
      },
      'endpoints': {
        'mcp': '/mcp',
        'sse': '/sse',
        'messages': '/messages',
        'openapi': '/api/openapi.json',
      },
      'tools': toolNames,
    };

    return Response.ok(
      const JsonEncoder.withIndent('  ').convert(info),
      headers: {
        'content-type': 'application/json; charset=utf-8',
        'access-control-allow-origin': '*',
        'mcp-session-id': sessionId,
      },
    );
  }

  // --- JSON-RPC 2.0 MCP Handler ---
  Future<Response> _handleJsonRpc(Request request) async {
    final sessionId =
        request.headers['mcp-session-id'] ??
        request.headers['Mcp-Session-Id'] ??
        const Uuid().v4();

    try {
      final bodyStr = await request.readAsString();
      final dynamic body = jsonDecode(bodyStr);

      if (body is! Map<String, dynamic>) {
        return Response.badRequest(
          body: jsonEncode({
            'jsonrpc': '2.0',
            'error': {'code': -32600, 'message': 'Invalid Request'},
            'id': null,
          }),
          headers: {
            'content-type': 'application/json',
            'mcp-session-id': sessionId,
          },
        );
      }

      final id = body['id'];
      final method = body['method'] as String?;
      final params = body['params'] as Map<String, dynamic>? ?? {};

      _log('MCP RPC Call: method=$method');

      dynamic result;
      switch (method) {
        case 'initialize':
          result = {
            'protocolVersion': '2024-11-05',
            'capabilities': {
              'tools': {'listChanged': false},
              'resources': {'subscribe': false},
            },
            'serverInfo': {
              'name': AppStrings.appName,
              'version': AppStrings.appVersion,
            },
          };
          break;

        case 'notifications/initialized':
          return Response.ok(
            jsonEncode({'status': 'acknowledged'}),
            headers: {'content-type': 'application/json'},
          );

        case 'ping':
          result = {};
          break;

        case 'tools/list':
          result = {'tools': McpTools.getToolDefinitions()};
          break;

        case 'tools/call':
          final toolName = params['name'] as String;
          final toolArgs = params['arguments'] as Map<String, dynamic>? ?? {};
          _log('Executing tool "$toolName" with args: $toolArgs');

          final toolResult = await McpTools.executeTool(
            name: toolName,
            arguments: toolArgs,
            repository: repository,
            getSettings: getSettings,
            updateSettings: updateSettings,
          );
          result = {
            'content': [
              {'type': 'text', 'text': jsonEncode(toolResult)},
            ],
          };
          break;

        case 'resources/list':
          result = {
            'resources': [
              {
                'uri': 'sectograph://dial/today',
                'name': 'Today Dial Sectors',
                'mimeType': 'application/json',
              },
              {
                'uri': 'sectograph://dial/free_slots',
                'name': 'Available Free Gaps',
                'mimeType': 'application/json',
              },
            ],
          };
          break;

        case 'resources/read':
          final uri = params['uri'] as String;
          final today = DateTime.now();
          if (uri == 'sectograph://dial/today') {
            final events = await repository.getEventsForDay(today);
            result = {
              'contents': [
                {
                  'uri': uri,
                  'mimeType': 'application/json',
                  'text': jsonEncode(events.map((e) => e.toJson()).toList()),
                },
              ],
            };
          } else {
            final gaps = await repository.findFreeGaps(
              day: today,
              is24HourMode: getSettings().is24HourMode,
            );
            result = {
              'contents': [
                {
                  'uri': uri,
                  'mimeType': 'application/json',
                  'text': jsonEncode(gaps.map((g) => g.toJson()).toList()),
                },
              ],
            };
          }
          break;

        default:
          return Response.ok(
            jsonEncode({
              'jsonrpc': '2.0',
              'error': {'code': -32601, 'message': 'Method not found: $method'},
              'id': id,
            }),
            headers: {'content-type': 'application/json'},
          );
      }

      return Response.ok(
        jsonEncode({'jsonrpc': '2.0', 'id': id, 'result': result}),
        headers: {'content-type': 'application/json'},
      );
    } catch (e, stack) {
      _log('RPC Error: $e\n$stack');
      return Response.internalServerError(
        body: jsonEncode({
          'jsonrpc': '2.0',
          'error': {'code': -32603, 'message': e.toString()},
          'id': null,
        }),
        headers: {'content-type': 'application/json'},
      );
    }
  }

  // --- SSE (Server-Sent Events for Grok Bot & MCP SSE clients) ---
  Response _handleSse(Request request) {
    final sessionId = const Uuid().v4();
    late final StreamController<String> controller;
    controller = StreamController<String>(
      onListen: () {
        controller.add(
          'event: endpoint\ndata: /messages?sessionId=$sessionId\n\n',
        );
      },
      onCancel: () {
        _sseClients.remove(sessionId);
      },
    );
    _sseClients[sessionId] = controller;

    _log('New SSE connection established: sessionId=$sessionId');

    final stream = controller.stream.map((msg) => utf8.encode(msg));

    return Response.ok(
      stream,
      headers: {
        'content-type': 'text/event-stream',
        'cache-control': 'no-cache',
        'connection': 'keep-alive',
        'access-control-allow-origin': '*',
      },
      context: {'shelf.io.buffer_output': false},
    );
  }

  Future<Response> _handleSseMessage(Request request) async {
    final sessionId =
        request.requestedUri.queryParameters['sessionId'] ??
        request.url.queryParameters['sessionId'];
    if (sessionId == null || !_sseClients.containsKey(sessionId)) {
      return Response.badRequest(body: 'Invalid or missing sessionId');
    }

    final bodyStr = await request.readAsString();
    final dynamic body = jsonDecode(bodyStr);

    final id = body['id'];
    final method = body['method'] as String?;
    final params = body['params'] as Map<String, dynamic>? ?? {};

    _log('SSE Received Message: sessionId=$sessionId, method=$method');

    dynamic result;
    if (method == 'initialize') {
      result = {
        'protocolVersion': '2024-11-05',
        'capabilities': {'tools': {}},
        'serverInfo': {'name': 'sectograph-mcp', 'version': '1.0.0'},
      };
    } else if (method == 'tools/list') {
      result = {'tools': McpTools.getToolDefinitions()};
    } else if (method == 'tools/call') {
      final toolName = params['name'] as String;
      final toolArgs = params['arguments'] as Map<String, dynamic>? ?? {};
      final toolResult = await McpTools.executeTool(
        name: toolName,
        arguments: toolArgs,
        repository: repository,
        getSettings: getSettings,
        updateSettings: updateSettings,
      );
      result = {
        'content': [
          {'type': 'text', 'text': jsonEncode(toolResult)},
        ],
      };
    } else {
      result = {};
    }

    final ssePayload = jsonEncode({
      'jsonrpc': '2.0',
      'id': id,
      'result': result,
    });

    _sseClients[sessionId]?.add('event: message\ndata: $ssePayload\n\n');
    return Response.ok('Accepted');
  }

  // --- Direct REST Endpoints (For ChatGPT Custom Actions & Webhooks) ---

  Future<Response> _handleRestGetState(Request request) async {
    final res = await McpTools.executeTool(
      name: 'get_clock_state',
      arguments: {},
      repository: repository,
      getSettings: getSettings,
      updateSettings: updateSettings,
    );
    return Response.ok(
      jsonEncode(res),
      headers: {'content-type': 'application/json'},
    );
  }

  Future<Response> _handleRestGetSectors(Request request) async {
    final date =
        request.requestedUri.queryParameters['date'] ??
        request.url.queryParameters['date'];
    final res = await McpTools.executeTool(
      name: 'list_sectors',
      arguments: {'date': date},
      repository: repository,
      getSettings: getSettings,
      updateSettings: updateSettings,
    );
    return Response.ok(
      jsonEncode(res),
      headers: {'content-type': 'application/json'},
    );
  }

  Future<Response> _handleRestBulkPlan(Request request) async {
    final bodyStr = await request.readAsString();
    final body = jsonDecode(bodyStr) as Map<String, dynamic>;
    final res = await McpTools.executeTool(
      name: 'bulk_schedule_sectors',
      arguments: body,
      repository: repository,
      getSettings: getSettings,
      updateSettings: updateSettings,
    );
    return Response.ok(
      jsonEncode(res),
      headers: {'content-type': 'application/json'},
    );
  }

  Response _handleRestGetSettings(Request request) {
    return Response.ok(
      jsonEncode(getSettings().toJson()),
      headers: {'content-type': 'application/json'},
    );
  }

  Future<Response> _handleRestPostSettings(Request request) async {
    final bodyStr = await request.readAsString();
    final body = jsonDecode(bodyStr) as Map<String, dynamic>;
    final res = await McpTools.executeTool(
      name: 'update_dial_settings',
      arguments: body,
      repository: repository,
      getSettings: getSettings,
      updateSettings: updateSettings,
    );
    return Response.ok(
      jsonEncode(res),
      headers: {'content-type': 'application/json'},
    );
  }

  // Auto-generated OpenAPI 3.0 for ChatGPT Actions
  Response _handleOpenApiSchema(Request request) {
    final host = request.headers['host'] ?? '127.0.0.1:$_port';
    final openApi = {
      'openapi': '3.0.1',
      'info': {
        'title': 'Sectograph Circular Planner API',
        'description': 'Autonomous time-blocking and dial control API for ChatGPT and AI assistants.',
        'version': '1.0.0',
      },
      'servers': [
        {'url': 'http://$host'},
      ],
      'paths': {
        '/api/state': {
          'get': {
            'summary': 'Get current dial state and active time block',
            'operationId': 'getClockState',
            'responses': {
              '200': {'description': 'OK'},
            },
          },
        },
        '/api/sectors': {
          'get': {
            'summary': 'List sectors for a date',
            'operationId': 'listSectors',
            'parameters': [
              {
                'name': 'date',
                'in': 'query',
                'schema': {'type': 'string'},
              },
            ],
            'responses': {
              '200': {'description': 'OK'},
            },
          },
        },
        '/api/bulk_plan': {
          'post': {
            'summary': 'Bulk schedule time blocks on circular dial',
            'operationId': 'bulkPlan',
            'requestBody': {
              'required': true,
              'content': {
                'application/json': {
                  'schema': {
                    'type': 'object',
                    'properties': {
                      'events': {
                        'type': 'array',
                        'items': {
                          'type': 'object',
                          'properties': {
                            'title': {'type': 'string'},
                            'start': {'type': 'string'},
                            'end': {'type': 'string'},
                            'category': {'type': 'string'},
                            'colorHex': {'type': 'string'},
                          },
                          'required': ['title', 'start', 'end'],
                        },
                      },
                    },
                  },
                },
              },
            },
            'responses': {
              '200': {'description': 'OK'},
            },
          },
        },
        '/api/settings': {
          'get': {
            'summary': 'Get dial customization settings',
            'operationId': 'getSettings',
            'responses': {
              '200': {'description': 'OK'},
            },
          },
          'post': {
            'summary': 'Update dial customization settings',
            'operationId': 'updateSettings',
            'responses': {
              '200': {'description': 'OK'},
            },
          },
        },
      },
    };

    return Response.ok(
      jsonEncode(openApi),
      headers: {'content-type': 'application/json'},
    );
  }

  // Pre-formatted Grok / xAI Tool Schemas
  Response _handleGrokToolsSchema(Request request) {
    final tools = McpTools.getToolDefinitions().map((t) {
      return {
        'type': 'function',
        'function': {
          'name': t['name'],
          'description': t['description'],
          'parameters': t['inputSchema'],
        },
      };
    }).toList();

    return Response.ok(
      jsonEncode({'tools': tools}),
      headers: {'content-type': 'application/json'},
    );
  }
}
