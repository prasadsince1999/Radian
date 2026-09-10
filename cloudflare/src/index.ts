import { Env, JsonRpcRequest } from './types';
import { D1Repository } from './d1_repository';
import { McpHandler } from './mcp_handler';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
  'Access-Control-Allow-Headers': 'Content-Type, Authorization',
};

export default {
  async fetch(request: Request, env: Env, ctx: ExecutionContext): Promise<Response> {
    const url = new URL(request.url);

    // Handle CORS Preflight
    if (request.method === 'OPTIONS') {
      return new Response(null, { status: 204, headers: corsHeaders });
    }

    const repo = new D1Repository(env.DB);
    const mcp = new McpHandler(repo);

    // 1. JSON-RPC 2.0 MCP Endpoint (ChatGPT & Claude HTTP Transport)
    if (request.method === 'POST' && (url.pathname === '/mcp' || url.pathname === '/rpc')) {
      try {
        const body: JsonRpcRequest = await request.json();
        const response = await mcp.handleJsonRpc(body);
        return new Response(JSON.stringify(response), {
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        });
      } catch (err: any) {
        return new Response(
          JSON.stringify({
            jsonrpc: '2.0',
            id: null,
            error: { code: -32700, message: 'Parse error', data: err.message },
          }),
          { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
        );
      }
    }

    // 2. Server-Sent Events Endpoint (SSE for Claude Desktop & Custom Webhooks)
    if (request.method === 'GET' && url.pathname === '/sse') {
      const { readable, writable } = new TransformStream();
      const writer = writable.getWriter();
      const encoder = new TextEncoder();

      // Initial SSE handshake
      const sessionUrl = `${url.origin}/messages?session=${crypto.randomUUID()}`;
      writer.write(encoder.encode(`event: endpoint\ndata: ${sessionUrl}\n\n`));

      return new Response(readable, {
        headers: {
          ...corsHeaders,
          'Content-Type': 'text/event-stream',
          'Cache-Control': 'no-cache',
          Connection: 'keep-alive',
        },
      });
    }

    // 3. REST Endpoint: Delta Events Sync for Flutter App
    if (request.method === 'GET' && url.pathname === '/api/events') {
      const since = url.searchParams.get('since') || undefined;
      const events = await repo.getDeltaEvents(since);
      return new Response(JSON.stringify({ count: events.length, events }), {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    // 4. REST Endpoint: Batch Sync Push/Pull from Flutter App
    if (request.method === 'POST' && url.pathname === '/api/sync') {
      try {
        const payload: {
          since?: string;
          mutations?: Array<{ action: 'upsert' | 'delete'; event?: any; id?: string }>;
        } = await request.json();

        // Apply client mutations
        if (payload.mutations && payload.mutations.length > 0) {
          for (const mut of payload.mutations) {
            if (mut.action === 'upsert' && mut.event) {
              await repo.upsertEvent(mut.event);
            } else if (mut.action === 'delete' && mut.id) {
              await repo.softDeleteEvent(mut.id);
            }
          }
        }

        // Return latest delta
        const delta = await repo.getDeltaEvents(payload.since);
        const serverTime = new Date().toISOString();

        return new Response(
          JSON.stringify({
            success: true,
            serverTime,
            deltaCount: delta.length,
            delta,
          }),
          { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
        );
      } catch (err: any) {
        return new Response(
          JSON.stringify({ success: false, error: err.message }),
          { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
        );
      }
    }

    // 5. OpenAPI 3.0 Specification for ChatGPT Custom Actions
    if (request.method === 'GET' && url.pathname === '/api/openapi.json') {
      const openApi = {
        openapi: '3.0.1',
        info: {
          title: 'Sectograph Cloudflare API',
          description: 'Cloudflare D1-backed time planning and circular dial automation API',
          version: '1.0.0',
        },
        servers: [{ url: url.origin }],
        paths: {
          '/api/events': {
            get: {
              summary: 'Get scheduled events',
              parameters: [{ name: 'since', in: 'query', schema: { type: 'string' } }],
              responses: { '200': { description: 'List of events' } },
            },
          },
          '/api/sync': {
            post: {
              summary: 'Sync local changes with Cloudflare D1',
              responses: { '200': { description: 'Sync result' } },
            },
          },
        },
      };

      return new Response(JSON.stringify(openApi, null, 2), {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    // Root info
    if (url.pathname === '/') {
      return new Response(
        JSON.stringify({
          service: 'Sectograph Remote MCP Server',
          status: 'online',
          database: 'Cloudflare D1',
          mcpEndpoint: `${url.origin}/mcp`,
          sseEndpoint: `${url.origin}/sse`,
          docs: 'https://modelcontextprotocol.io',
        }, null, 2),
        { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    return new Response('Not Found', { status: 404, headers: corsHeaders });
  },
};
