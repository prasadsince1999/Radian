import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sectograph_mcp/core/constants/app_strings.dart';
import 'package:sectograph_mcp/data/repositories/local_event_repository.dart';
import 'package:sectograph_mcp/domain/models/dial_settings.dart';
import 'package:sectograph_mcp/domain/models/sector_event.dart';
import 'package:sectograph_mcp/mcp/mcp_server.dart';

void main() {
  group('McpServer Automated Integration Tests', () {
    late LocalEventRepository repository;
    late McpServer server;
    DialSettings settings = const DialSettings();
    const testPort = 8989;

    setUp(() async {
      repository = LocalEventRepository();
      server = McpServer(
        repository: repository,
        getSettings: () => settings,
        updateSettings: (s) async => settings = s,
      );
      final ok = await server.start(port: testPort);
      expect(ok, isTrue);
    });

    tearDown(() async {
      await server.stop();
    });

    test(
      'MCP initialize handshake returns correct protocol and serverInfo',
      () async {
        final client = HttpClient();
        final request = await client.postUrl(
          Uri.parse('http://127.0.0.1:$testPort/mcp'),
        );
        request.headers.contentType = ContentType.json;
        request.write(
          jsonEncode({
            'jsonrpc': '2.0',
            'id': 1,
            'method': 'initialize',
            'params': {},
          }),
        );
        final response = await request.close();
        expect(response.statusCode, HttpStatus.ok);

        final respBody = await response.transform(utf8.decoder).join();
        final decoded = jsonDecode(respBody) as Map<String, dynamic>;

        expect(decoded['jsonrpc'], '2.0');
        expect(decoded['id'], 1);
        final result = decoded['result'] as Map<String, dynamic>;
        expect(result['serverInfo']['name'], AppStrings.appName);
        expect(result['protocolVersion'], '2024-11-05');
        client.close();
      },
    );

    test('MCP ping returns empty result', () async {
      final client = HttpClient();
      final request = await client.postUrl(
        Uri.parse('http://127.0.0.1:$testPort/mcp'),
      );
      request.headers.contentType = ContentType.json;
      request.write(
        jsonEncode({
          'jsonrpc': '2.0',
          'id': 'ping-1',
          'method': 'ping',
          'params': {},
        }),
      );
      final response = await request.close();
      expect(response.statusCode, HttpStatus.ok);

      final respBody = await response.transform(utf8.decoder).join();
      final decoded = jsonDecode(respBody) as Map<String, dynamic>;
      expect(decoded['result'], isEmpty);
      client.close();
    });

    test('MCP notifications/initialized returns acknowledged', () async {
      final client = HttpClient();
      final request = await client.postUrl(
        Uri.parse('http://127.0.0.1:$testPort/mcp'),
      );
      request.headers.contentType = ContentType.json;
      request.write(
        jsonEncode({
          'jsonrpc': '2.0',
          'method': 'notifications/initialized',
          'params': {},
        }),
      );
      final response = await request.close();
      expect(response.statusCode, HttpStatus.ok);

      final respBody = await response.transform(utf8.decoder).join();
      final decoded = jsonDecode(respBody) as Map<String, dynamic>;
      expect(decoded['status'], 'acknowledged');
      client.close();
    });

    test(
      'MCP tools/list returns all required autonomous planning tools',
      () async {
        final client = HttpClient();
        final request = await client.postUrl(
          Uri.parse('http://127.0.0.1:$testPort/mcp'),
        );
        request.headers.contentType = ContentType.json;
        request.write(
          jsonEncode({
            'jsonrpc': '2.0',
            'id': 2,
            'method': 'tools/list',
            'params': {},
          }),
        );
        final response = await request.close();
        final respBody = await response.transform(utf8.decoder).join();
        final decoded = jsonDecode(respBody) as Map<String, dynamic>;

        final tools = decoded['result']['tools'] as List<dynamic>;
        final toolNames = tools.map((t) => t['name'] as String).toList();

        expect(toolNames, contains('get_clock_state'));
        expect(toolNames, contains('list_sectors'));
        expect(toolNames, contains('find_free_gaps'));
        expect(toolNames, contains('bulk_schedule_sectors'));
        expect(toolNames, contains('replace_day_schedule'));
        expect(toolNames, contains('smart_auto_plan'));
        expect(toolNames, contains('schedule_sector'));
        expect(toolNames, contains('update_sector'));
        expect(toolNames, contains('delete_sector'));
        expect(toolNames, contains('clear_sectors'));
        expect(toolNames, contains('get_dial_settings'));
        expect(toolNames, contains('update_dial_settings'));
        expect(toolNames, contains('analyze_day_balance'));
        client.close();
      },
    );

    test(
      'MCP resources/list and resources/read return dial resources',
      () async {
        final client = HttpClient();
        final today = DateTime.now();
        await repository.addEvent(
          SectorEvent(
            id: 'res-event-1',
            title: 'Resource Read Test',
            start: DateTime(today.year, today.month, today.day, 10, 0),
            end: DateTime(today.year, today.month, today.day, 11, 0),
          ),
        );

        // 1. resources/list
        final listReq = await client.postUrl(
          Uri.parse('http://127.0.0.1:$testPort/mcp'),
        );
        listReq.headers.contentType = ContentType.json;
        listReq.write(
          jsonEncode({
            'jsonrpc': '2.0',
            'id': 10,
            'method': 'resources/list',
            'params': {},
          }),
        );
        final listResp = await listReq.close();
        final listBody = await listResp.transform(utf8.decoder).join();
        final listDecoded = jsonDecode(listBody) as Map<String, dynamic>;
        final resources = listDecoded['result']['resources'] as List<dynamic>;
        expect(
          resources.any((r) => r['uri'] == 'sectograph://dial/today'),
          isTrue,
        );
        expect(
          resources.any((r) => r['uri'] == 'sectograph://dial/free_slots'),
          isTrue,
        );

        // 2. resources/read for today
        final readReq = await client.postUrl(
          Uri.parse('http://127.0.0.1:$testPort/mcp'),
        );
        readReq.headers.contentType = ContentType.json;
        readReq.write(
          jsonEncode({
            'jsonrpc': '2.0',
            'id': 11,
            'method': 'resources/read',
            'params': {'uri': 'sectograph://dial/today'},
          }),
        );
        final readResp = await readReq.close();
        final readBody = await readResp.transform(utf8.decoder).join();
        final readDecoded = jsonDecode(readBody) as Map<String, dynamic>;
        final contents = readDecoded['result']['contents'] as List<dynamic>;
        expect(contents.first['uri'], 'sectograph://dial/today');
        expect(contents.first['text'], contains('Resource Read Test'));

        client.close();
      },
    );

    test('MCP error handling for unknown method and invalid request', () async {
      final client = HttpClient();

      // Unknown method
      final req1 = await client.postUrl(
        Uri.parse('http://127.0.0.1:$testPort/mcp'),
      );
      req1.headers.contentType = ContentType.json;
      req1.write(
        jsonEncode({
          'jsonrpc': '2.0',
          'id': 99,
          'method': 'unknown_method_xyz',
          'params': {},
        }),
      );
      final resp1 = await req1.close();
      final body1 = await resp1.transform(utf8.decoder).join();
      final decoded1 = jsonDecode(body1) as Map<String, dynamic>;
      expect(decoded1['error']['code'], -32601);

      // Invalid request format (array instead of map)
      final req2 = await client.postUrl(
        Uri.parse('http://127.0.0.1:$testPort/mcp'),
      );
      req2.headers.contentType = ContentType.json;
      req2.write(jsonEncode([1, 2, 3]));
      final resp2 = await req2.close();
      expect(resp2.statusCode, HttpStatus.badRequest);

      client.close();
    });

    test(
      'MCP bulk_schedule_sectors creates events and updates dial state',
      () async {
        final client = HttpClient();
        final today = DateTime.now();
        final start = DateTime(
          today.year,
          today.month,
          today.day,
          13,
          0,
        ).toIso8601String();
        final end = DateTime(
          today.year,
          today.month,
          today.day,
          14,
          0,
        ).toIso8601String();

        final request = await client.postUrl(
          Uri.parse('http://127.0.0.1:$testPort/mcp'),
        );
        request.headers.contentType = ContentType.json;
        request.write(
          jsonEncode({
            'jsonrpc': '2.0',
            'id': 3,
            'method': 'tools/call',
            'params': {
              'name': 'bulk_schedule_sectors',
              'arguments': {
                'events': [
                  {
                    'title': 'Autonomous AI Study Block',
                    'start': start,
                    'end': end,
                    'category': 'Learning',
                    'colorHex': '#10B981',
                  },
                ],
              },
            },
          }),
        );
        final response = await request.close();
        expect(response.statusCode, HttpStatus.ok);

        final respBody = await response.transform(utf8.decoder).join();
        final decoded = jsonDecode(respBody) as Map<String, dynamic>;
        final content = decoded['result']['content'][0]['text'] as String;
        final payload = jsonDecode(content) as Map<String, dynamic>;

        expect(payload['success'], isTrue);
        expect(payload['scheduledCount'], 1);

        // Verify event is now present in repository
        final events = await repository.getEventsForDay(today);
        expect(
          events.any((e) => e.title == 'Autonomous AI Study Block'),
          isTrue,
        );
        client.close();
      },
    );

    // --- SSE Protocol Tests ---
    test(
      'SSE GET /sse initializes stream and POST /messages responds',
      () async {
        final client = HttpClient();
        final sseReq = await client.getUrl(
          Uri.parse('http://127.0.0.1:$testPort/sse'),
        );
        final sseResp = await sseReq.close();
        expect(sseResp.statusCode, HttpStatus.ok);
        expect(sseResp.headers.contentType?.mimeType, 'text/event-stream');

        final completer = Completer<String>();
        late StreamSubscription sub;
        sub = sseResp.transform(utf8.decoder).listen((chunk) {
          for (final line in chunk.split('\n')) {
            if (line.startsWith('data: /messages?sessionId=')) {
              final uri = line.substring(6).trim();
              if (!completer.isCompleted) {
                completer.complete(uri);
              }
            }
          }
        }, onError: (_) {});

        final endpointUri = await completer.future.timeout(
          const Duration(seconds: 3),
        );
        expect(endpointUri, contains('/messages?sessionId='));

        // Send JSON-RPC message to SSE endpoint
        final msgReq = await client.postUrl(
          Uri.parse('http://127.0.0.1:$testPort$endpointUri'),
        );
        msgReq.headers.contentType = ContentType.json;
        msgReq.write(
          jsonEncode({
            'jsonrpc': '2.0',
            'id': 100,
            'method': 'initialize',
            'params': {},
          }),
        );
        final msgResp = await msgReq.close();
        expect(msgResp.statusCode, HttpStatus.ok);

        await sub.cancel();
        client.close(force: true);
      },
    );

    // --- REST Endpoints Tests ---
    test(
      'REST /api/state returns current dial state and active status',
      () async {
        final client = HttpClient();
        final request = await client.getUrl(
          Uri.parse('http://127.0.0.1:$testPort/api/state'),
        );
        final response = await request.close();
        expect(response.statusCode, HttpStatus.ok);

        final respBody = await response.transform(utf8.decoder).join();
        final decoded = jsonDecode(respBody) as Map<String, dynamic>;
        expect(decoded.containsKey('currentTime'), isTrue);
        expect(decoded.containsKey('is24HourMode'), isTrue);
        client.close();
      },
    );

    test('REST /api/sectors returns sectors for requested date', () async {
      final today = DateTime.now();
      await repository.addEvent(
        SectorEvent(
          id: 'rest-s1',
          title: 'REST Sector',
          start: DateTime(today.year, today.month, today.day, 14, 0),
          end: DateTime(today.year, today.month, today.day, 15, 0),
        ),
      );

      final client = HttpClient();
      final request = await client.getUrl(
        Uri.parse(
          'http://127.0.0.1:$testPort/api/sectors?date=${today.toIso8601String().substring(0, 10)}',
        ),
      );
      final response = await request.close();
      expect(response.statusCode, HttpStatus.ok);

      final respBody = await response.transform(utf8.decoder).join();
      final decoded = jsonDecode(respBody) as Map<String, dynamic>;
      expect(decoded['count'], 1);
      client.close();
    });

    test('REST /api/settings GET and POST mutates visual settings', () async {
      final client = HttpClient();

      // GET initial
      final getReq = await client.getUrl(
        Uri.parse('http://127.0.0.1:$testPort/api/settings'),
      );
      final getResp = await getReq.close();
      expect(getResp.statusCode, HttpStatus.ok);

      // POST update
      final postReq = await client.postUrl(
        Uri.parse('http://127.0.0.1:$testPort/api/settings'),
      );
      postReq.headers.contentType = ContentType.json;
      postReq.write(
        jsonEncode({'is24HourMode': true, 'seedColorHex': '#6366F1'}),
      );
      final postResp = await postReq.close();
      expect(postResp.statusCode, HttpStatus.ok);

      expect(settings.is24HourMode, isTrue);
      expect(settings.seedColorHex, '#6366F1');
      client.close();
    });

    test('REST /api/openapi.json returns valid OpenAPI 3.0 specification for ChatGPT Actions', () async {
      final client = HttpClient();
      final request = await client.getUrl(
        Uri.parse('http://127.0.0.1:$testPort/api/openapi.json'),
      );
      final response = await request.close();
      expect(response.statusCode, HttpStatus.ok);

      final respBody = await response.transform(utf8.decoder).join();
      final openApi = jsonDecode(respBody) as Map<String, dynamic>;

      expect(openApi['openapi'], '3.0.1');
      expect(openApi['info']['title'], contains('Sectograph'));
      expect(openApi['paths']['/api/bulk_plan'], isNotNull);
      expect(openApi['paths']['/api/state'], isNotNull);
      expect(openApi['paths']['/api/sectors'], isNotNull);
      expect(openApi['paths']['/api/settings'], isNotNull);
      client.close();
    });

    test(
      'REST /api/grok/tools.json returns valid xAI Grok tool schema',
      () async {
        final client = HttpClient();
        final request = await client.getUrl(
          Uri.parse('http://127.0.0.1:$testPort/api/grok/tools.json'),
        );
        final response = await request.close();
        expect(response.statusCode, HttpStatus.ok);

        final respBody = await response.transform(utf8.decoder).join();
        final decoded = jsonDecode(respBody) as Map<String, dynamic>;
        final tools = decoded['tools'] as List<dynamic>;
        expect(tools.length, 13);
        expect(tools.first['type'], 'function');
        client.close();
      },
    );

    test(
      'GET /mcp returns valid server discovery info and tools catalog',
      () async {
        final client = HttpClient();
        final request = await client.getUrl(
          Uri.parse('http://127.0.0.1:$testPort/mcp'),
        );
        final response = await request.close();
        expect(response.statusCode, HttpStatus.ok);
        expect(
          response.headers.value('content-type'),
          contains('application/json'),
        );

        final respBody = await response.transform(utf8.decoder).join();
        final decoded = jsonDecode(respBody) as Map<String, dynamic>;
        expect(decoded['name'], AppStrings.appName);
        expect(decoded['protocolVersion'], '2024-11-05');
        expect(decoded['status'], 'online');
        expect(decoded['tools'], hasLength(13));
        client.close();
      },
    );
  });
}
