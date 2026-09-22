import { Env, JsonRpcRequest } from './types';
import { D1Repository } from './d1_repository';
import { McpHandler } from './mcp_handler';
import { getIcon512Bytes, getFaviconIcoBytes, LOGO_SVG, ICON_DATA_URL } from './assets';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
  'Access-Control-Allow-Headers': 'Content-Type, Authorization, X-Radian-Sync-Key, X-Sync-Key',
};

function extractSyncKey(request: Request, url: URL, body?: any): string {
  const fromHeader = request.headers.get('x-radian-sync-key') || request.headers.get('x-sync-key');
  if (fromHeader && fromHeader.trim()) return fromHeader.trim();

  const fromQuery = url.searchParams.get('sync') || url.searchParams.get('sync_key');
  if (fromQuery && fromQuery.trim()) return fromQuery.trim();

  if (body && typeof body === 'object') {
    if (typeof body.syncKey === 'string' && body.syncKey.trim()) return body.syncKey.trim();
    if (typeof body.sync_key === 'string' && body.sync_key.trim()) return body.sync_key.trim();
    if (body.params && typeof body.params === 'object') {
      if (typeof body.params.syncKey === 'string' && body.params.syncKey.trim()) return body.params.syncKey.trim();
      if (typeof body.params.sync_key === 'string' && body.params.sync_key.trim()) return body.params.sync_key.trim();
    }
  }
  return 'default';
}

export default {
  async fetch(request: Request, env: Env, ctx: ExecutionContext): Promise<Response> {
    const url = new URL(request.url);

    // Handle CORS Preflight
    if (request.method === 'OPTIONS') {
      return new Response(null, { status: 204, headers: corsHeaders });
    }

    // Static Asset Endpoints (Favicon, Logo, App Icon for MCP Dashboards & Crawlers)
    if (url.pathname === '/favicon.ico') {
      const bytes = getFaviconIcoBytes();
      return new Response(bytes as any, {
        headers: {
          ...corsHeaders,
          'Content-Type': 'image/x-icon',
          'Cache-Control': 'public, max-age=86400',
        },
      });
    }

    if (
      url.pathname === '/icon.png' ||
      url.pathname === '/icon_512.png' ||
      url.pathname === '/icon_192.png' ||
      url.pathname === '/logo.png' ||
      url.pathname === '/app_logo.png' ||
      url.pathname === '/apple-touch-icon.png' ||
      url.pathname === '/apple-touch-icon-precomposed.png' ||
      url.pathname === '/favicon.png'
    ) {
      const bytes = getIcon512Bytes();
      return new Response(bytes as any, {
        headers: {
          ...corsHeaders,
          'Content-Type': 'image/png',
          'Cache-Control': 'public, max-age=86400',
        },
      });
    }

    if (
      url.pathname === '/icon.svg' ||
      url.pathname === '/logo.svg' ||
      url.pathname === '/favicon.svg'
    ) {
      return new Response(LOGO_SVG, {
        headers: {
          ...corsHeaders,
          'Content-Type': 'image/svg+xml; charset=utf-8',
          'Cache-Control': 'public, max-age=86400',
        },
      });
    }

    const repo = new D1Repository(env.DB);
    const mcp = new McpHandler(repo);

    // 1. GET /mcp or GET /rpc: MCP Discovery / Manifest Endpoint (for Gemini Custom Connector, Claude, etc.)
    if (
      request.method === 'GET' &&
      (url.pathname === '/mcp' ||
        url.pathname === '/rpc' ||
        url.pathname === '/.well-known/mcp.json' ||
        url.pathname === '/manifest.json')
    ) {
      const manifest = {
        name: 'Radian',
        title: 'Radian MCP Server',
        description: '360° AI-Native Circular Time Blocking & Schedule Planner',
        protocol: 'Model Context Protocol (MCP)',
        protocolVersion: '2024-11-05',
        status: 'online',
        transport: 'StreamableHTTP',
        icon: `${url.origin}/icon.png`,
        iconUrl: `${url.origin}/icon.png`,
        logo: `${url.origin}/icon.png`,
        logoUrl: `${url.origin}/icon.png`,
        icons: [
          { src: `${url.origin}/icon.png`, sizes: '512x512', type: 'image/png' },
          { src: `${url.origin}/favicon.ico`, sizes: '16x16 24x24 32x32', type: 'image/x-icon' },
          { src: `${url.origin}/logo.svg`, sizes: 'any', type: 'image/svg+xml' },
        ],
        _meta: {
          icon: `${url.origin}/icon.png`,
          logo: `${url.origin}/icon.png`,
        },
        endpoints: {
          mcp: `${url.origin}/mcp`,
          rpc: `${url.origin}/rpc`,
          sse: `${url.origin}/sse`,
          events: `${url.origin}/api/events`,
          sync: `${url.origin}/api/sync`,
        },
        capabilities: {
          tools: { listChanged: true },
          resources: {},
          prompts: {},
          logging: {},
        },
        tools: McpHandler.getToolDefinitions(),
      };
      return new Response(JSON.stringify(manifest, null, 2), {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    // 2. POST /mcp or POST /rpc: JSON-RPC 2.0 MCP Endpoint (Gemini, ChatGPT, Claude HTTP Transport)
    if (request.method === 'POST' && (url.pathname === '/mcp' || url.pathname === '/rpc')) {
      try {
        const text = await request.text();
        if (!text || text.trim() === '' || text.trim() === '{}') {
          return new Response(
            JSON.stringify({
              jsonrpc: '2.0',
              id: null,
              result: {
                protocolVersion: '2024-11-05',
                capabilities: { tools: { listChanged: false } },
                serverInfo: {
                  name: 'radian-mcp',
                  version: '1.0.7',
                  description: '360° AI-Native Circular Time Blocking & Schedule Planner',
                  icon: `${url.origin}/icon.png`,
                  iconUrl: `${url.origin}/icon.png`,
                  logo: `${url.origin}/icon.png`,
                  logoUrl: `${url.origin}/icon.png`,
                  icons: [
                    { src: `${url.origin}/icon.png`, sizes: '512x512', type: 'image/png' },
                    { src: `${url.origin}/favicon.ico`, sizes: '16x16 24x24 32x32', type: 'image/x-icon' },
                    { src: `${url.origin}/logo.svg`, sizes: 'any', type: 'image/svg+xml' },
                  ],
                },
                tools: McpHandler.getToolDefinitions(),
              },
            }),
            { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
          );
        }
        const body: JsonRpcRequest = JSON.parse(text);
        const syncKey = extractSyncKey(request, url, body);
        const response = await mcp.handleJsonRpc(body, url.origin, syncKey);
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
      const syncKey = extractSyncKey(request, url);
      const since = url.searchParams.get('since') || undefined;
      const events = await repo.getDeltaEvents(since, syncKey);
      return new Response(JSON.stringify({ count: events.length, syncKey, events }), {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    // 4. REST Endpoint: Batch Sync Push/Pull from Flutter App
    if (request.method === 'POST' && url.pathname === '/api/sync') {
      try {
        const text = await request.text();
        const payload: {
          since?: string;
          syncKey?: string;
          sync_key?: string;
          mutations?: Array<{ action: 'upsert' | 'delete'; event?: any; id?: string }>;
        } = text ? JSON.parse(text) : {};

        const syncKey = extractSyncKey(request, url, payload);

        // Apply client mutations
        if (payload.mutations && payload.mutations.length > 0) {
          for (const mut of payload.mutations) {
            if (mut.action === 'upsert' && mut.event) {
              await repo.upsertEvent({ ...mut.event, sync_key: syncKey }, syncKey);
            } else if (mut.action === 'delete' && mut.id) {
              await repo.softDeleteEvent(mut.id, syncKey);
            }
          }
        }

        // Return latest delta
        const delta = await repo.getDeltaEvents(payload.since, syncKey);
        const serverTime = new Date().toISOString();

        return new Response(
          JSON.stringify({
            success: true,
            syncKey,
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

    // 5. REST Endpoint: OTA App Updates (fetches latest GitHub Release with edge cache)
    if (request.method === 'GET' && (url.pathname === '/api/updates/latest' || url.pathname === '/api/version')) {
      try {
        const ghRes = await fetch('https://api.github.com/repos/prasadsince1999/Radian/releases/latest', {
          headers: {
            'User-Agent': 'Radian-Updater/1.0.1',
            Accept: 'application/vnd.github.v3+json',
          },
          cf: {
            cacheTtl: 300,
            cacheEverything: true,
          },
        });

        if (ghRes.ok) {
          const release: any = await ghRes.json();
          const tag = release.tag_name || 'v1.0.1';
          const version = tag.replace(/^v/, '');
          const apkAsset =
            release.assets?.find(
              (a: any) =>
                typeof a.name === 'string' &&
                a.name.includes(tag) &&
                a.name.endsWith('.apk')
            ) ||
            release.assets?.find(
              (a: any) =>
                typeof a.name === 'string' && a.name.endsWith('.apk')
            );
          const downloadUrl = apkAsset?.browser_download_url ||
            `https://github.com/prasadsince1999/Radian/releases/download/${tag}/Radian-${tag}.apk`;

          return new Response(
            JSON.stringify(
              {
                success: true,
                tag,
                version,
                downloadUrl,
                apkName: apkAsset?.name || `Radian-${tag}.apk`,
                sizeBytes: apkAsset?.size || 58123885,
                releaseNotes: release.body || '',
                publishedAt: release.published_at || new Date().toISOString(),
                htmlUrl: release.html_url || `https://github.com/prasadsince1999/Radian/releases/tag/${tag}`,
              },
              null,
              2
            ),
            {
              headers: {
                ...corsHeaders,
                'Content-Type': 'application/json',
                'Cache-Control': 'public, max-age=300',
              },
            }
          );
        }
      } catch (_) {}

      // Robust fallback if GitHub API rate-limited or error
      return new Response(
        JSON.stringify(
          {
            success: true,
            tag: 'v1.0.18',
            version: '1.0.18',
            downloadUrl:
              'https://github.com/prasadsince1999/Radian/releases/download/v1.0.18/Radian-v1.0.18.apk',
            apkName: 'Radian-v1.0.18.apk',
            sizeBytes: 74832208,
            releaseNotes:
              '### Radian v1.0.18 - 1:1 Parity: Stretched Active Blocks, River Pebble Subtasks & High-Contrast Center Clock\n\n- **Full Fisheye & Stretched Active Blocks**: Widget dial now perfectly inherits Fisheye Time Lens warping and sector layout stretching, expanding the active sector and revealing subtasks with ample breathing room.\n- **Visible Current Time Subtasks**: River pebble chips (e.g. Coffee, Rest, Cardio, Gym) are organically placed and clearly visible in active and upcoming sectors on both in-app and widget dials.\n- **High-Contrast Digital Center Clock**: Crisp, bold dark charcoal (#0F172A) time on light backgrounds and white (#F8FAFC) on dark backgrounds, perfectly centered with no intrusive chip in digital clock mode.\n- **Harmonic Minute Needle Alignment**: Native Android minute needle warps in sync with the Fisheye lens angle, guaranteeing 0.0° drift against the active stretched sector.',
            publishedAt: new Date().toISOString(),
            htmlUrl: 'https://github.com/prasadsince1999/Radian/releases/tag/v1.0.18',
          },
          null,
          2
        ),
        {
          headers: {
            ...corsHeaders,
            'Content-Type': 'application/json',
            'Cache-Control': 'public, max-age=60',
          },
        }
      );
    }

    // 6. OpenAPI 3.0 Specification for ChatGPT Custom Actions
    if (request.method === 'GET' && url.pathname === '/api/openapi.json') {
      const openApi = {
        openapi: '3.0.1',
        info: {
          title: 'Sectograph Cloudflare API',
          description: 'Cloudflare D1-backed time planning and circular dial automation API',
          version: '1.0.5',
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

    // Root info / Landing page (Provides icon, meta tags, and endpoints)
    if (url.pathname === '/') {
      const accept = request.headers.get('accept') || '';
      const wantsJson = accept.includes('application/json') && !accept.includes('text/html') && !url.searchParams.has('html');
      if (!wantsJson) {
        const html = `<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Radian — 360° AI-Native Circular Routine & Life Dial | KSM × Tech</title>
  <link rel="icon" type="image/x-icon" href="/favicon.ico">
  <link rel="icon" type="image/png" sizes="512x512" href="/icon.png">
  <link rel="apple-touch-icon" href="/apple-touch-icon.png">
  
  <meta property="og:title" content="Radian — Your Day is a Circle, Not a Checklist | KSM × Tech">
  <meta property="og:description" content="A single 360° circular dial widget that visualizes your entire day, sub-tasks, and biological circadian rhythm at a single glance. Plan days simply by chatting with AI via MCP.">
  <meta property="og:image" content="${url.origin}/icon.png">
  <meta property="og:logo" content="${url.origin}/icon.png">
  <meta name="twitter:card" content="summary_large_image">
  <meta name="twitter:image" content="${url.origin}/icon.png">

  <!-- Google Fonts: Outfit, Space Grotesk, JetBrains Mono, Eczar -->
  <link rel="preconnect" href="https://fonts.googleapis.com">
  <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
  <link href="https://fonts.googleapis.com/css2?family=Eczar:wght@600;800&family=JetBrains+Mono:wght@400;500;700&family=Outfit:wght@400;500;600;700;800;900&family=Space+Grotesk:wght@500;700&display=swap" rel="stylesheet">

  <style>
    :root {
      --bg: #07090E;
      --bg-card: rgba(15, 20, 32, 0.75);
      --bg-card-hover: rgba(22, 30, 48, 0.85);
      --border: rgba(255, 255, 255, 0.09);
      --border-focus: rgba(56, 189, 248, 0.4);
      --accent-cyan: #38BDF8;
      --accent-indigo: #6366F1;
      --accent-amber: #F59E0B;
      --accent-rose: #F43F5E;
      --accent-emerald: #10B981;
      --accent-violet: #A855F7;
      --text: #F8FAFC;
      --text-muted: #94A3B8;
      --text-dim: #64748B;
      --ksm-terracotta: #B33A2B;
      --ksm-gold: #E8A33D;
      --ksm-paper: #F4EBD9;
    }
    * { box-sizing: border-box; margin: 0; padding: 0; }
    body {
      background: var(--bg);
      background-image: 
        radial-gradient(circle at 50% 0%, rgba(99, 102, 241, 0.18) 0%, transparent 50%),
        radial-gradient(circle at 85% 30%, rgba(56, 189, 248, 0.08) 0%, transparent 40%),
        radial-gradient(circle at 15% 70%, rgba(244, 63, 94, 0.06) 0%, transparent 40%);
      color: var(--text);
      font-family: 'Outfit', -apple-system, BlinkMacSystemFont, sans-serif;
      line-height: 1.6;
      overflow-x: hidden;
      -webkit-font-smoothing: antialiased;
    }

    /* ─── KSM × TECH HEADER ─── */
    .site-header {
      position: sticky;
      top: 0;
      z-index: 100;
      background: rgba(7, 9, 14, 0.85);
      backdrop-filter: blur(20px);
      -webkit-backdrop-filter: blur(20px);
      border-bottom: 1px solid var(--border);
      padding: 16px 24px;
    }
    .header-inner {
      max-width: 1200px;
      margin: 0 auto;
      display: flex;
      justify-content: space-between;
      align-items: center;
    }
    .brand {
      display: flex;
      align-items: center;
      gap: 12px;
      text-decoration: none;
      color: var(--text);
    }
    .brand-logo-wrap {
      width: 34px;
      height: 34px;
      border-radius: 50%;
      background: linear-gradient(135deg, var(--accent-indigo), var(--accent-cyan));
      display: flex;
      align-items: center;
      justify-content: center;
      box-shadow: 0 0 16px rgba(99, 102, 241, 0.5);
    }
    .brand-name {
      font-weight: 800;
      font-size: 17px;
      letter-spacing: -0.02em;
    }
    .brand-name span.x {
      color: var(--accent-cyan);
      font-weight: 400;
      margin: 0 2px;
    }
    .nav-links {
      display: flex;
      gap: 20px;
      align-items: center;
    }
    .nav-links a {
      color: var(--text-muted);
      text-decoration: none;
      font-size: 14px;
      font-weight: 600;
      transition: color 140ms ease;
    }
    .nav-links a:hover {
      color: #FFFFFF;
    }
    .nav-cta {
      background: rgba(56, 189, 248, 0.1);
      border: 1px solid rgba(56, 189, 248, 0.3);
      color: var(--accent-cyan) !important;
      padding: 6px 14px;
      border-radius: 9999px;
      font-size: 13px;
      font-weight: 700;
      transition: all 140ms ease;
    }
    .nav-cta:hover {
      background: var(--accent-cyan);
      color: #07090E !important;
      box-shadow: 0 0 18px rgba(56, 189, 248, 0.4);
    }

    /* ─── CONTAINER ─── */
    .container {
      max-width: 1140px;
      margin: 0 auto;
      padding: 0 24px;
    }

    /* ─── HERO SECTION ─── */
    .hero {
      padding: 70px 0 40px;
      text-align: center;
      position: relative;
    }
    .eyebrow {
      display: inline-flex;
      align-items: center;
      gap: 8px;
      padding: 6px 16px;
      background: rgba(99, 102, 241, 0.1);
      border: 1px solid rgba(99, 102, 241, 0.3);
      border-radius: 9999px;
      font-family: 'Space Grotesk', sans-serif;
      font-size: 11.5px;
      font-weight: 700;
      letter-spacing: 0.1em;
      text-transform: uppercase;
      color: #A5B4FC;
      margin-bottom: 20px;
    }
    .eyebrow .dot {
      width: 7px;
      height: 7px;
      background: #10B981;
      border-radius: 50%;
      box-shadow: 0 0 8px #10B981;
    }
    .deva-tag {
      font-family: 'Eczar', serif;
      font-size: 26px;
      font-weight: 800;
      color: var(--ksm-gold);
      letter-spacing: 0.05em;
      margin-bottom: 6px;
    }
    h1.hero-title {
      font-size: clamp(2.6rem, 5.5vw, 4.4rem);
      font-weight: 900;
      line-height: 1.08;
      letter-spacing: -0.04em;
      margin-bottom: 18px;
    }
    .gradient-text {
      background: linear-gradient(135deg, #FFFFFF 20%, #38BDF8 60%, #818CF8 100%);
      -webkit-background-clip: text;
      -webkit-text-fill-color: transparent;
    }
    p.hero-lead {
      font-size: clamp(1.05rem, 2vw, 1.2rem);
      color: var(--text-muted);
      max-width: 740px;
      margin: 0 auto 32px;
      line-height: 1.7;
    }
    .hero-ctas {
      display: flex;
      justify-content: center;
      gap: 16px;
      flex-wrap: wrap;
      margin-bottom: 44px;
    }
    .btn {
      display: inline-flex;
      align-items: center;
      gap: 8px;
      padding: 13px 26px;
      border-radius: 12px;
      font-family: 'Space Grotesk', sans-serif;
      font-size: 14px;
      font-weight: 700;
      text-decoration: none;
      cursor: pointer;
      transition: all 160ms ease;
      border: 1px solid transparent;
    }
    .btn:active {
      transform: scale(0.97);
    }
    .btn-primary {
      background: linear-gradient(135deg, var(--accent-indigo), #38BDF8);
      color: #FFFFFF;
      box-shadow: 0 4px 24px rgba(99, 102, 241, 0.4);
    }
    .btn-primary:hover {
      box-shadow: 0 6px 30px rgba(56, 189, 248, 0.6);
      transform: translateY(-2px);
    }
    .btn-outline {
      background: rgba(255, 255, 255, 0.04);
      border: 1px solid var(--border);
      color: var(--text);
    }
    .btn-outline:hover {
      background: rgba(255, 255, 255, 0.08);
      border-color: rgba(255, 255, 255, 0.2);
      transform: translateY(-2px);
    }

    /* ─── AUTHENTIC RADIAN SHOWCASE ─── */
    .rd-showcase-shell {
      background: linear-gradient(180deg, #090B12 0%, #06080D 100%);
      border: 1px solid rgba(255, 255, 255, 0.08);
      border-radius: 28px;
      padding: 44px 36px;
      box-shadow: 0 20px 60px rgba(0, 0, 0, 0.6);
      margin-bottom: 72px;
    }
    .rd-showcase-grid {
      display: grid;
      grid-template-columns: 390px 1fr;
      gap: 52px;
      align-items: start;
    }
    @media (max-width: 960px) {
      .rd-showcase-grid {
        grid-template-columns: 1fr;
        gap: 36px;
      }
      .rd-showcase-shell {
        padding: 24px 20px;
      }
    }

    /* Authentic OLED Phone Chassis */
    .rd-phone-chassis {
      width: 100%;
      max-width: 390px;
      margin: 0 auto;
      background: #0C0E14;
      border-radius: 40px;
      border: 3px solid #222634;
      box-shadow: 
        0 25px 60px -15px rgba(0, 0, 0, 0.9),
        0 0 0 1px rgba(255, 255, 255, 0.08),
        inset 0 1px 0 rgba(255, 255, 255, 0.15);
      overflow: hidden;
      position: relative;
      font-family: 'Outfit', -apple-system, BlinkMacSystemFont, sans-serif;
      color: #F8FAFC;
      user-select: none;
      text-align: left;
    }

    /* Status Bar */
    .rd-status-bar {
      padding: 12px 20px 4px;
      display: flex;
      justify-content: space-between;
      align-items: center;
      font-size: 13px;
      font-weight: 700;
      color: #F8FAFC;
      letter-spacing: -0.2px;
    }
    .rd-status-icons {
      display: flex;
      align-items: center;
      gap: 6px;
      font-size: 11px;
      color: #94A3B8;
    }

    /* App Header */
    .rd-app-header {
      padding: 8px 18px 14px;
      display: flex;
      justify-content: space-between;
      align-items: center;
    }
    .rd-app-logo {
      display: flex;
      align-items: center;
      gap: 8px;
    }
    .rd-logo-icon {
      width: 26px;
      height: 26px;
      border-radius: 50%;
      background: conic-gradient(from 180deg, #6366F1, #38BDF8, transparent);
      position: relative;
      border: 1px solid rgba(255,255,255,0.15);
    }
    .rd-logo-icon::after {
      content: '';
      position: absolute;
      inset: 4px;
      background: #0C0E14;
      border-radius: 50%;
    }
    .rd-app-title {
      font-size: 20px;
      font-weight: 800;
      color: #FFFFFF;
      letter-spacing: -0.3px;
      position: relative;
    }
    .rd-app-title::after {
      content: '✦';
      font-size: 9px;
      color: #38BDF8;
      position: absolute;
      top: -2px;
      right: -10px;
      text-shadow: 0 0 6px #38BDF8;
    }
    .rd-app-actions {
      display: flex;
      gap: 8px;
    }
    .rd-icon-btn {
      width: 34px;
      height: 34px;
      background: #1B1E28;
      border: 1px solid rgba(255, 255, 255, 0.08);
      border-radius: 10px;
      display: flex;
      align-items: center;
      justify-content: center;
      color: #94A3B8;
      cursor: pointer;
      transition: all 140ms ease;
      font-size: 14px;
    }
    .rd-icon-btn:hover {
      background: #252A38;
      color: #FFFFFF;
    }

    /* 360° Circular Dial Stage */
    .rd-dial-stage {
      position: relative;
      width: 100%;
      padding: 10px 0 16px;
      display: flex;
      justify-content: center;
    }
    .rd-dial-svg-frame {
      width: 290px;
      height: 290px;
    }

    /* Date Navigation Bar */
    .rd-nav-bar {
      padding: 4px 16px 14px;
      display: flex;
      gap: 8px;
      align-items: center;
    }
    .rd-nav-pill {
      background: #181A24;
      border: 1px solid rgba(255, 255, 255, 0.08);
      border-radius: 100px;
      padding: 7px 14px;
      font-size: 12px;
      font-weight: 700;
      color: #F8FAFC;
      display: inline-flex;
      align-items: center;
      gap: 6px;
      cursor: pointer;
      transition: all 140ms ease;
    }
    .rd-nav-pill:hover {
      background: #222634;
    }
    .rd-nav-pill-center {
      flex-grow: 1;
      justify-content: space-between;
      padding: 7px 12px;
    }
    .rd-nav-arrow {
      color: #94A3B8;
      cursor: pointer;
      padding: 0 4px;
    }

    /* Event Cards List */
    .rd-events-list {
      padding: 0 16px 20px;
      display: flex;
      flex-direction: column;
      gap: 10px;
      max-height: 280px;
      overflow-y: auto;
    }
    .rd-event-card {
      background: #151722;
      border: 1px solid rgba(255, 255, 255, 0.07);
      border-radius: 20px;
      padding: 14px 16px;
      display: flex;
      align-items: center;
      gap: 14px;
      position: relative;
      overflow: hidden;
      transition: transform 140ms ease, border-color 140ms ease, background 140ms ease;
      cursor: pointer;
    }
    .rd-event-card:hover {
      transform: translateY(-2px);
      background: #1B1E2C;
      border-color: rgba(255, 255, 255, 0.15);
    }
    .rd-card-bar {
      width: 3.5px;
      height: 38px;
      border-radius: 4px;
      flex-shrink: 0;
    }
    .rd-card-icon {
      width: 42px;
      height: 42px;
      border-radius: 12px;
      display: flex;
      align-items: center;
      justify-content: center;
      font-size: 18px;
      flex-shrink: 0;
    }
    .rd-card-body {
      flex-grow: 1;
      min-width: 0;
    }
    .rd-card-title {
      font-size: 14.5px;
      font-weight: 800;
      color: #FFFFFF;
      margin-bottom: 2px;
    }
    .rd-card-time {
      font-size: 12px;
      color: #94A3B8;
    }
    .rd-card-badge {
      display: inline-flex;
      align-items: center;
      gap: 4px;
      padding: 2px 8px;
      background: #251E38;
      border: 1px solid #4338CA;
      color: #A5B4FC;
      border-radius: 6px;
      font-size: 10px;
      font-weight: 700;
      margin-top: 4px;
    }

    /* Floating Bottom Pill */
    .rd-floating-pill {
      padding: 8px 16px;
      background: #1F2332;
      border: 1px solid rgba(255, 255, 255, 0.1);
      border-radius: 100px;
      font-size: 11.5px;
      font-weight: 700;
      color: #CBD5E1;
      display: flex;
      align-items: center;
      gap: 6px;
      margin: 0 auto 16px;
      width: fit-content;
      box-shadow: 0 4px 15px rgba(0,0,0,0.3);
    }

    /* Slide-Up Bottom Sheet */
    .rd-bottom-sheet {
      position: absolute;
      left: 0;
      right: 0;
      bottom: 0;
      background: #181A24;
      border-top: 1px solid rgba(255, 255, 255, 0.12);
      border-radius: 28px 28px 0 0;
      padding: 12px 18px 24px;
      box-shadow: 0 -10px 40px rgba(0, 0, 0, 0.8);
      transform: translateY(102%);
      transition: transform 300ms cubic-bezier(0.16, 1, 0.3, 1);
      z-index: 50;
    }
    .rd-bottom-sheet.open {
      transform: translateY(0);
    }
    .rd-sheet-handle {
      width: 36px;
      height: 4px;
      background: #475569;
      border-radius: 2px;
      margin: 0 auto 14px;
    }
    .rd-sheet-header {
      display: flex;
      justify-content: space-between;
      align-items: center;
      margin-bottom: 16px;
    }
    .rd-sheet-title-group {
      display: flex;
      align-items: center;
      gap: 10px;
    }
    .rd-sheet-title-icon {
      width: 32px;
      height: 32px;
      background: #312E81;
      color: #A5B4FC;
      border-radius: 10px;
      display: flex;
      align-items: center;
      justify-content: center;
      font-size: 14px;
    }
    .rd-sheet-title {
      font-size: 15px;
      font-weight: 800;
      color: #FFFFFF;
    }
    .rd-sheet-close {
      width: 28px;
      height: 28px;
      background: #232736;
      border-radius: 8px;
      display: flex;
      align-items: center;
      justify-content: center;
      color: #94A3B8;
      cursor: pointer;
      font-size: 12px;
      border: none;
    }

    /* Option Box inside Sheet */
    .rd-option-box {
      background: #11131C;
      border: 1px solid rgba(255, 255, 255, 0.06);
      border-radius: 16px;
      padding: 12px 14px;
      margin-bottom: 10px;
    }
    .rd-option-row {
      display: flex;
      justify-content: space-between;
      align-items: center;
    }
    .rd-option-label {
      font-size: 13px;
      font-weight: 700;
      color: #FFFFFF;
    }
    .rd-option-desc {
      font-size: 11px;
      color: #64748B;
      margin-top: 2px;
    }
    .rd-switch {
      width: 44px;
      height: 24px;
      background: #272B3B;
      border-radius: 100px;
      position: relative;
      cursor: pointer;
      transition: background 160ms ease;
      flex-shrink: 0;
    }
    .rd-switch.on {
      background: #6366F1;
    }
    .rd-switch-knob {
      width: 18px;
      height: 18px;
      background: #FFFFFF;
      border-radius: 50%;
      position: absolute;
      top: 3px;
      left: 3px;
      transition: transform 160ms ease;
    }
    .rd-switch.on .rd-switch-knob {
      transform: translateX(20px);
    }
    .rd-theme-segments {
      display: flex;
      background: #0B0D13;
      border-radius: 10px;
      padding: 3px;
      gap: 4px;
      margin-top: 8px;
    }
    .rd-theme-seg {
      flex: 1;
      text-align: center;
      padding: 6px 0;
      font-size: 11.5px;
      font-weight: 700;
      color: #94A3B8;
      border-radius: 8px;
      cursor: pointer;
      transition: all 120ms ease;
    }
    .rd-theme-seg.active {
      background: #3730A3;
      color: #FFFFFF;
    }
    .rd-palette-dots {
      display: flex;
      justify-content: space-between;
      margin-top: 10px;
    }
    .rd-color-dot {
      width: 28px;
      height: 28px;
      border-radius: 50%;
      cursor: pointer;
      display: flex;
      align-items: center;
      justify-content: center;
      font-size: 11px;
      color: #FFFFFF;
      transition: transform 140ms ease, box-shadow 140ms ease;
    }
    .rd-color-dot:hover {
      transform: scale(1.15);
    }
    .rd-color-dot.active {
      box-shadow: 0 0 0 2px #0C0E14, 0 0 0 4px #FFFFFF;
    }

    /* Dial Info / Schedule Inspection HUD */
    .dial-hud {
      text-align: left;
    }
    .dial-hud-eyebrow {
      font-family: 'Space Grotesk', sans-serif;
      font-size: 11px;
      font-weight: 700;
      letter-spacing: 0.14em;
      text-transform: uppercase;
      color: var(--accent-cyan);
      margin-bottom: 8px;
    }
    .dial-hud-title {
      font-size: 2.2rem;
      font-weight: 800;
      line-height: 1.15;
      margin-bottom: 12px;
    }
    .dial-hud-desc {
      color: var(--text-muted);
      font-size: 15px;
      margin-bottom: 24px;
      line-height: 1.65;
    }

    /* Active Sector Box */
    .active-sector-card {
      background: #131622;
      border: 1px solid rgba(255, 255, 255, 0.08);
      border-radius: 16px;
      padding: 18px 22px;
      margin-bottom: 20px;
      border-left: 4px solid var(--accent-indigo);
      transition: border-color 160ms ease;
    }
    .active-sector-time {
      font-family: 'JetBrains Mono', monospace;
      font-size: 12px;
      font-weight: 700;
      color: var(--accent-cyan);
      margin-bottom: 4px;
    }
    .active-sector-name {
      font-size: 18px;
      font-weight: 800;
      color: #FFFFFF;
      margin-bottom: 4px;
    }
    .active-sector-sub {
      font-size: 13px;
      color: var(--text-muted);
    }

    /* ─── MANIFESTO GRID ─── */
    .section-title-wrap {
      text-align: center;
      max-width: 720px;
      margin: 0 auto 48px;
    }
    .section-num {
      font-family: 'Space Grotesk', sans-serif;
      font-size: 11px;
      font-weight: 700;
      letter-spacing: 0.16em;
      text-transform: uppercase;
      color: var(--accent-cyan);
      margin-bottom: 8px;
      display: block;
    }
    h2.section-h2 {
      font-size: clamp(2rem, 4vw, 3rem);
      font-weight: 800;
      line-height: 1.15;
      letter-spacing: -0.03em;
      margin-bottom: 12px;
    }
    h2.section-h2 em {
      font-style: italic;
      color: var(--accent-cyan);
    }
    p.section-p {
      color: var(--text-muted);
      font-size: 16px;
    }

    .manifesto-grid {
      display: grid;
      grid-template-columns: repeat(auto-fit, minmax(250px, 1fr));
      gap: 20px;
      margin-bottom: 80px;
    }
    .manifesto-card {
      background: var(--bg-card);
      border: 1px solid var(--border);
      border-radius: 20px;
      padding: 30px 26px;
      transition: transform 160ms ease, border-color 160ms ease;
    }
    .manifesto-card:hover {
      transform: translateY(-4px);
      border-color: var(--border-focus);
    }
    .manifesto-icon {
      font-size: 28px;
      margin-bottom: 16px;
      display: block;
    }
    .manifesto-card h3 {
      font-size: 1.25rem;
      font-weight: 800;
      margin-bottom: 10px;
      color: #FFFFFF;
    }
    .manifesto-card p {
      font-size: 14px;
      color: var(--text-muted);
      line-height: 1.65;
    }

    /* ─── MCP CONNECT QUICK COPY ─── */
    .mcp-box {
      background: linear-gradient(135deg, rgba(15, 23, 42, 0.9), rgba(10, 13, 22, 0.9));
      border: 1.5px solid rgba(99, 102, 241, 0.35);
      border-radius: 24px;
      padding: 36px 32px;
      margin-bottom: 80px;
      box-shadow: 0 16px 40px rgba(0, 0, 0, 0.4);
    }
    .mcp-box-header {
      display: flex;
      justify-content: space-between;
      align-items: center;
      flex-wrap: wrap;
      gap: 16px;
      margin-bottom: 24px;
    }
    .mcp-title {
      font-size: 1.3rem;
      font-weight: 800;
      color: #FFFFFF;
    }
    .endpoint-pill {
      background: #060911;
      border: 1px solid rgba(56, 189, 248, 0.3);
      border-radius: 12px;
      padding: 12px 18px;
      display: flex;
      justify-content: space-between;
      align-items: center;
      gap: 16px;
      margin-bottom: 28px;
    }
    .endpoint-text {
      font-family: 'JetBrains Mono', monospace;
      font-size: 13.5px;
      color: #38BDF8;
      word-break: break-all;
    }
    .btn-copy {
      background: var(--accent-indigo);
      color: #FFFFFF;
      border: none;
      border-radius: 8px;
      padding: 8px 16px;
      font-family: 'Space Grotesk', sans-serif;
      font-size: 12px;
      font-weight: 700;
      cursor: pointer;
      flex-shrink: 0;
      transition: all 140ms ease;
    }
    .btn-copy:hover {
      background: #4F46E5;
    }
    .mcp-clients-grid {
      display: grid;
      grid-template-columns: repeat(auto-fit, minmax(280px, 1fr));
      gap: 16px;
    }
    .mcp-client-card {
      background: rgba(0, 0, 0, 0.25);
      border: 1px solid var(--border);
      border-radius: 14px;
      padding: 16px 18px;
    }
    .mcp-client-title {
      font-size: 13px;
      font-weight: 700;
      color: #E2E8F0;
      margin-bottom: 8px;
      display: flex;
      align-items: center;
      gap: 8px;
    }
    .code-snip {
      background: #020617;
      border: 1px solid rgba(255, 255, 255, 0.05);
      border-radius: 8px;
      padding: 10px 14px;
      font-family: 'JetBrains Mono', monospace;
      font-size: 11.5px;
      color: #94A3B8;
      overflow-x: auto;
      line-height: 1.5;
    }

    /* ─── TOOL CATALOG ─── */
    .tools-grid {
      display: grid;
      grid-template-columns: repeat(auto-fit, minmax(280px, 1fr));
      gap: 16px;
      margin-bottom: 80px;
    }
    .tool-card {
      background: var(--bg-card);
      border: 1px solid var(--border);
      border-radius: 16px;
      padding: 22px 20px;
      transition: all 140ms ease;
    }
    .tool-card:hover {
      border-color: rgba(99, 102, 241, 0.35);
      background: var(--bg-card-hover);
    }
    .tool-name {
      font-family: 'JetBrains Mono', monospace;
      font-size: 13px;
      font-weight: 700;
      color: var(--accent-cyan);
      margin-bottom: 6px;
    }
    .tool-desc {
      font-size: 13px;
      color: var(--text-muted);
      line-height: 1.55;
    }

    /* ─── KSM × TECH FOOTER ─── */
    .site-footer {
      border-top: 1px solid var(--border);
      background: #040508;
      padding: 60px 0 40px;
      color: var(--text-muted);
    }
    .footer-inner {
      display: grid;
      grid-template-columns: 2fr 1fr 1fr;
      gap: 40px;
      margin-bottom: 40px;
    }
    @media (max-width: 768px) {
      .footer-inner {
        grid-template-columns: 1fr;
      }
    }
    .footer-brand-title {
      font-size: 1.25rem;
      font-weight: 800;
      color: #FFFFFF;
      margin-bottom: 8px;
    }
    .footer-brand-p {
      font-size: 13.5px;
      line-height: 1.6;
      max-width: 360px;
    }
    .footer-links-col h4 {
      font-size: 12px;
      font-weight: 800;
      text-transform: uppercase;
      letter-spacing: 0.1em;
      color: #FFFFFF;
      margin-bottom: 12px;
    }
    .footer-links-col a {
      display: block;
      color: var(--text-muted);
      text-decoration: none;
      font-size: 13.5px;
      margin-bottom: 8px;
      transition: color 120ms ease;
    }
    .footer-links-col a:hover {
      color: var(--accent-cyan);
    }
    .footer-bottom {
      border-top: 1px solid rgba(255, 255, 255, 0.05);
      padding-top: 24px;
      display: flex;
      justify-content: space-between;
      align-items: center;
      flex-wrap: wrap;
      gap: 12px;
      font-size: 12.5px;
    }
    .footer-mantra {
      font-family: 'Eczar', serif;
      color: var(--ksm-gold);
      font-size: 14px;
    }
  </style>
</head>
<body>

  <!-- ─── HEADER ─── -->
  <header class="site-header">
    <div class="header-inner">
      <a href="https://ksmxtech.com/" class="brand" target="_blank" rel="noopener">
        <div class="brand-logo-wrap">
          <svg width="18" height="18" viewBox="0 0 100 100" fill="none" stroke="#FFFFFF" stroke-width="8">
            <circle cx="50" cy="50" r="42"/>
            <line x1="50" y1="8" x2="50" y2="92"/>
            <line x1="8" y1="50" x2="92" y2="50"/>
            <circle cx="50" cy="50" r="18"/>
          </svg>
        </div>
        <span class="brand-name">KSM<span class="x">×</span>Tech</span>
      </a>

      <nav class="nav-links">
        <a href="#dial-preview">The Dial</a>
        <a href="#manifesto">Anti-Todo</a>
        <a href="#mcp-connect">MCP Setup</a>
        <a href="https://github.com/prasadsince1999/Radian" target="_blank" rel="noopener">GitHub ↗</a>
        <a href="https://ksmxtech.com/radian/" class="nav-cta" target="_blank" rel="noopener">Studio Showcase ↗</a>
      </nav>
    </div>
  </header>

  <main>
    <!-- ─── HERO ─── -->
    <section class="hero">
      <div class="container">
        <div style="font-family:'Noto Serif Devanagari',serif; font-size:clamp(18px,2vw,24px); color:var(--cyan); margin-bottom:12px; font-weight:700; text-shadow:0 0 20px rgba(56,189,248,0.4);">
          रेडियन · अहोरात्र चक्र
        </div>
        <h1 style="font-family:'Eczar',Georgia,serif; font-size:clamp(3.5rem,7.5vw,6.5rem); font-weight:800; line-height:0.92; letter-spacing:-0.04em; color:#FFFFFF; margin-bottom:18px;">
          Ra<em style="font-style:italic; font-weight:600; color:var(--cyan); text-shadow:0 0 28px rgba(56,189,248,0.5);">dian</em>
        </h1>
        <div class="eyebrow">
          <span class="dot"></span>
          STATUS: LIVE MCP · 360° CIRCULAR ROUTINE &amp; LIFE DIAL
        </div>
        <h2 class="hero-title" style="font-size:clamp(1.6rem,2.8vw,2.5rem); margin-bottom:18px; line-height:1.15;">
          Your Day is a Circle.<br>
          <span class="gradient-text">Stop Living in a Checklist.</span>
        </h2>
        <p class="hero-lead">
          A 360° circular polar dial widget that visualizes your entire day, sub-tasks, and biological circadian rhythm at a single effortless glance. Plan days, weeks, months, or years simply by chatting with AI via the Model Context Protocol (MCP). Zero nagging alarms. Zero task guilt.
        </p>
        <div style="display:flex; justify-content:center; align-items:center; gap:14px; flex-wrap:wrap; font-size:13px; letter-spacing:0.06em; text-transform:uppercase; color:var(--text-muted); margin:0 auto 32px; max-width:820px;">
          <span>Not another to-do list</span> ·
          <span>Not shrill nagging alarms</span> ·
          <span style="color:var(--cyan); font-weight:700;">A living 360° dial widget where you visualize your day and live guilt-free</span>
        </div>
        <div class="hero-ctas">
          <button class="btn btn-primary" onclick="copyMcpUrl()">
            <span>⚡ Connect Remote MCP</span>
          </button>
          <a href="#dial-preview" class="btn btn-outline">
            <span>Explore 360° Live Dial ↓</span>
          </a>
          <a href="https://github.com/prasadsince1999/Radian" target="_blank" rel="noopener" class="btn btn-outline">
            <span>GitHub Repository ↗</span>
          </a>
        </div>

        <!-- ─── 360° LIVE INTERACTIVE DIAL SHOWCASE ─── -->
        <div class="rd-dial-stage-box" id="dial-preview" style="border-radius:28px; border:1px solid rgba(255,255,255,0.08); background:linear-gradient(180deg, rgba(14,19,32,0.85) 0%, rgba(8,11,18,0.95) 100%); backdrop-filter:blur(24px); -webkit-backdrop-filter:blur(24px); padding:48px 40px; box-shadow:0 24px 64px rgba(0,0,0,0.6); margin-bottom:72px;">
          <div style="display:grid; grid-template-columns:1fr 1fr; gap:48px; align-items:center;">
            
            <!-- Left: The Pure 360° Circular Dial -->
            <div style="display:flex; flex-direction:column; align-items:center;">
              <div style="position:relative; width:340px; height:340px; user-select:none;">
                <svg viewBox="0 0 300 300" style="width:100%; height:100%; filter:drop-shadow(0 0 36px rgba(99,102,241,0.22));" id="radian-app-dial">
                  <!-- Background Dial Face -->
                  <circle cx="150" cy="150" r="142" fill="#0C0E14" stroke="#1F2433" stroke-width="1.5"/>
                  <circle cx="150" cy="150" r="62" fill="none" stroke="#25293A" stroke-width="1" stroke-dasharray="3 3"/>
                  
                  <!-- Dial Numerals (1 to 12) in crisp white -->
                  <g font-family="'Outfit', sans-serif" font-size="11" font-weight="700" fill="#CBD5E1" text-anchor="middle" opacity="0.88">
                    <text x="150" y="26">12</text>
                    <text x="212" y="44">1</text>
                    <text x="257" y="88">2</text>
                    <text x="274" y="154">3</text>
                    <text x="257" y="218">4</text>
                    <text x="212" y="262">5</text>
                    <text x="150" y="280">6</text>
                    <text x="88" y="262">7</text>
                    <text x="43" y="218">8</text>
                    <text x="26" y="154">9</text>
                    <text x="43" y="88">10</text>
                    <text x="88" y="44">11</text>
                  </g>

                  <!-- Concentric Routine Sectors -->
                  <!-- 1. Nap Time (1:30 PM to 3:00 PM · 1h 30m) -->
                  <path id="sec-nap" d="M 150 150 L 192.42 107.57 A 136 136 0 0 1 286 150 Z" fill="#2563EB" fill-opacity="0.9" style="cursor:pointer;" onclick="inspectAppSector('nap')"/>
                  
                  <!-- 2. Deep Focus (3:15 PM to 4:15 PM · 1h) -->
                  <path id="sec-deep" d="M 150 150 L 284.84 167.74 A 136 136 0 0 1 257.90 232.79 Z" fill="#6366F1" fill-opacity="0.92" style="cursor:pointer;" onclick="inspectAppSector('deep')"/>
                  
                  <!-- 3. Bed Time (4:15 PM to 5:30 PM · 1h 15m) -->
                  <path id="sec-bed" d="M 150 150 L 257.90 232.79 A 136 136 0 0 1 185.20 281.36 Z" fill="#475569" fill-opacity="0.88" style="cursor:pointer;" onclick="inspectAppSector('bed')"/>

                  <!-- Sector labels on dial face -->
                  <g font-family="'Outfit', sans-serif" font-size="9" font-weight="700" fill="#FFFFFF" opacity="0.95" pointer-events="none">
                    <text x="236" y="116" transform="rotate(22 236 116)" text-anchor="middle">🌙 Nap Time</text>
                    <text x="242" y="128" transform="rotate(22 242 128)" font-size="7.5" fill="#93C5FD" text-anchor="middle">1h 30m</text>
                    <text x="235" y="195" transform="rotate(22 235 195)" text-anchor="middle">💻 Deep</text>
                    <text x="180" y="246" text-anchor="middle">🌙 Bed Time</text>
                  </g>

                  <!-- Center Donut Mask (Ratio 0.42) -->
                  <circle cx="150" cy="150" r="58" fill="#07090E" stroke="#1F2433" stroke-width="1.5"/>

                  <!-- Center Clock Display -->
                  <text x="150" y="132" text-anchor="middle" font-family="'Outfit', sans-serif" font-size="9" font-weight="800" letter-spacing="1" fill="#94A3B8">PM</text>
                  <text x="150" y="154" text-anchor="middle" font-family="'Outfit', sans-serif" font-size="22" font-weight="800" fill="#FFFFFF" id="dial-center-time">12:38</text>
                  <text x="150" y="170" text-anchor="middle" font-family="'Outfit', sans-serif" font-size="9" font-weight="600" fill="#64748B">Wed, 16 Sep</text>

                  <!-- Continuous Crimson Hour Needle with Celestial Beacon Tip -->
                  <g id="app-needle-assembly">
                    <line id="app-needle-line" x1="150" y1="150" x2="150" y2="28" stroke="#EF4444" stroke-width="3" stroke-linecap="round"/>
                    <circle cx="150" cy="150" r="5" fill="#0C0E14" stroke="#FFFFFF" stroke-width="1.5"/>
                    <g id="app-needle-beacon" transform="translate(150, 28)">
                      <circle cx="0" cy="0" r="6.5" fill="#EF4444" stroke="#FFFFFF" stroke-width="1.3"/>
                      <circle cx="0" cy="0" r="2" fill="#FFFFFF"/>
                    </g>
                  </g>
                </svg>
              </div>

              <!-- Polar Mode Switch -->
              <div style="display:flex; gap:8px; background:rgba(255,255,255,0.05); padding:4px; border-radius:100px; border:1px solid rgba(255,255,255,0.08); margin-top:24px;">
                <button id="btn-12h" onclick="setAppDialMode(false)" style="background:#38BDF8; color:#07090E; border:none; border-radius:100px; padding:6px 16px; font-size:12px; font-weight:700; cursor:pointer; font-family:'Space Grotesk', sans-serif;">12H Mode (0.5°/min)</button>
                <button id="btn-24h" onclick="setAppDialMode(true)" style="background:transparent; color:#94A3B8; border:none; border-radius:100px; padding:6px 16px; font-size:12px; font-weight:700; cursor:pointer; font-family:'Space Grotesk', sans-serif;">24H Mode (0.25°/min)</button>
              </div>
            </div>

            <!-- Right: Active Telemetry HUD & Polar Architecture -->
            <div class="dial-hud">
              <div class="dial-hud-eyebrow">POLAR TIME HUD · REAL-TIME TELEMETRY</div>
              <h2 class="dial-hud-title">Glanceable Geometry. <br><span class="gradient-text">Zero Checklist Guilt.</span></h2>
              <p class="dial-hud-desc">
                Past sectors fade into quiet memory. The crimson continuous beacon needle tracks the present moment with 0.5°/min polar accuracy. Concentric tracks handle nested sub-tasks and routines without turning into an anxiety list.
              </p>

              <!-- Dynamic Hover Inspector Card -->
              <div class="active-sector-card" id="hud-card">
                <div class="active-sector-time" id="hud-time">03:15 PM — 04:15 PM (1H BLOCK)</div>
                <div class="active-sector-name" id="hud-name">Deep Focus: Architecture &amp; MCP Sprint</div>
                <div class="active-sector-sub" id="hud-sub">Category: High-Cognitive Deep Work · Draft Mode</div>
              </div>

              <!-- Routine Sector Quick Selectors -->
              <div style="display:flex; gap:10px; flex-wrap:wrap; margin-bottom:24px;">
                <button onclick="inspectAppSector('nap')" style="background:#131826; border:1px solid rgba(37,99,235,0.4); color:#93C5FD; padding:7px 14px; border-radius:100px; font-size:12px; font-weight:700; cursor:pointer; display:flex; align-items:center; gap:6px;">
                  <span style="width:8px; height:8px; border-radius:50%; background:#2563EB;"></span> 🌙 1:30 PM Nap Time
                </button>
                <button onclick="inspectAppSector('deep')" style="background:#181A2D; border:1px solid rgba(99,102,241,0.4); color:#C7D2FE; padding:7px 14px; border-radius:100px; font-size:12px; font-weight:700; cursor:pointer; display:flex; align-items:center; gap:6px;">
                  <span style="width:8px; height:8px; border-radius:50%; background:#6366F1;"></span> 💻 3:15 PM Deep Focus
                </button>
                <button onclick="inspectAppSector('bed')" style="background:#161924; border:1px solid rgba(71,85,105,0.4); color:#CBD5E1; padding:7px 14px; border-radius:100px; font-size:12px; font-weight:700; cursor:pointer; display:flex; align-items:center; gap:6px;">
                  <span style="width:8px; height:8px; border-radius:50%; background:#64748B;"></span> 🌙 4:15 PM Bed Time
                </button>
              </div>

              <!-- Remote MCP Connect Box -->
              <div style="background:#131622; border:1px solid rgba(255,255,255,0.08); border-radius:16px; padding:18px 20px; margin-bottom:24px;">
                <div style="font-size:11px; font-weight:800; letter-spacing:0.12em; color:#38BDF8; text-transform:uppercase; margin-bottom:6px;">
                  ⚡ REMOTE MCP AGENT ENDPOINT (MODEL CONTEXT PROTOCOL)
                </div>
                <div style="font-family:'JetBrains Mono', monospace; font-size:13px; color:#CBD5E1; word-break:break-all; user-select:all; background:#0B0D14; padding:8px 12px; border-radius:8px; border:1px solid rgba(255,255,255,0.06);">
                  https://sectograph-mcp.kpr25121999.workers.dev/mcp
                </div>
              </div>

              <!-- Action Buttons -->
              <div style="display:flex; gap:12px; flex-wrap:wrap;">
                <button class="btn btn-primary" onclick="copyMcpUrl()">⚡ Copy MCP Endpoint</button>
                <a href="https://ksmxtech.com/radian/" target="_blank" rel="noopener" class="btn btn-outline">Studio Radian Page ↗</a>
                <a href="https://github.com/prasadsince1999/Radian" target="_blank" rel="noopener" class="btn btn-outline">GitHub Repository ↗</a>
              </div>
            </div>

          </div>
        </div>
      </div>
    </section>

    <!-- ─── /01 IN PLAIN WORDS ─── -->
    <section class="container" id="in-plain-words">
      <div class="section-title-wrap">
        <span class="section-num">/01 — IN PLAIN WORDS</span>
        <h2 class="section-h2">Not another to-do list. Not nagging alarms. <br><em>A living 360° circle of your whole day.</em></h2>
        <p class="section-p">Vertical checklists produce chronic anxiety, red badges, and guilt debt. Radian restores calm situational awareness by mapping time, sub-tasks, and biological rhythms into an intuitive circular dial widget on your home screen.</p>
      </div>
    </section>

    <!-- ─── /02 THE ANTI-TODO PHILOSOPHY ─── -->
    <section class="container" id="manifesto">
      <div class="section-title-wrap">
        <span class="section-num">/02 — THE ANTI-TODO PHILOSOPHY</span>
        <h2 class="section-h2">Time isn't a vertical list. <br><em>Time is a 360° circle.</em></h2>
        <p class="section-p">Vertical to-do lists induce shame and anxiety. Radian replaces overdue red counters with continuous biological situational awareness.</p>
      </div>

      <div class="manifesto-grid">
        <article class="manifesto-card">
          <span class="manifesto-icon">⭕</span>
          <h3>Glance, Don't Scroll</h3>
          <p>One single 360° dial shows your whole day in context. Past hours fade away; upcoming commitments unfold naturally along the arc.</p>
        </article>

        <article class="manifesto-card">
          <span class="manifesto-icon">💬</span>
          <h3>Chat to Plan (MCP)</h3>
          <p>Forget manual calendar math. Connect Claude, Gemini, ChatGPT, or Cursor. Simply say: <em>"Clear my morning, schedule 2h deep focus at 11, and leave evening free."</em></p>
        </article>

        <article class="manifesto-card">
          <span class="manifesto-icon">🕊️</span>
          <h3>Zero Guilt, Zero Nagging</h3>
          <p>No shrill alarm orders you around. When a block arrives: if you feel it, do it. If not, let the dial sweep forward. No debt, no shame.</p>
        </article>

        <article class="manifesto-card">
          <span class="manifesto-icon">🫀</span>
          <h3>Circadian Harmony</h3>
          <p>Synchronizes sleep debt, recovery scores, and circadian alertness peaks into your schedule so you never burn out on heavy tasks.</p>
        </article>
      </div>
    </section>

    <!-- ─── MCP QUICK SETUP & INTEGRATION ─── -->
    <section class="container" id="mcp-connect">
      <div class="mcp-box">
        <div class="mcp-box-header">
          <div>
            <span class="section-num" style="display:block; margin-bottom:8px;">/03 — MODEL CONTEXT PROTOCOL · STREAMABLE HTTP</span>
            <div class="mcp-title">⚡ Connect Your AI Assistant via Model Context Protocol</div>
            <p style="color: var(--text-muted); font-size: 14px; margin-top: 4px;">
              Paste this remote endpoint into Claude Desktop, Cursor, Gemini Custom Connector, or any MCP client:
            </p>
          </div>
        </div>

        <div class="endpoint-pill">
          <span class="endpoint-text">${url.origin}/mcp</span>
          <button class="btn-copy" id="copy-btn" onclick="copyMcpUrl()">Copy Endpoint</button>
        </div>

        <div class="mcp-clients-grid">
          <!-- Claude Desktop -->
          <div class="mcp-client-card">
            <div class="mcp-client-title">
              <span>🤖 Claude Desktop (claude_desktop_config.json)</span>
            </div>
            <pre class="code-snip">{
  "mcpServers": {
    "radian": {
      "command": "npx",
      "args": ["-y", "mcp-remote-client", "${url.origin}/mcp"]
    }
  }
}</pre>
          </div>

          <!-- Cursor -->
          <div class="mcp-client-card">
            <div class="mcp-client-title">
              <span>⚡ Cursor (Features &gt; MCP Servers)</span>
            </div>
            <pre class="code-snip">Type: SSE or HTTP
Name: Radian
URL: ${url.origin}/mcp</pre>
          </div>

          <!-- Gemini -->
          <div class="mcp-client-card">
            <div class="mcp-client-title">
              <span>💎 Google Gemini Custom Extension</span>
            </div>
            <pre class="code-snip">Manifest URL:
${url.origin}/.well-known/mcp.json</pre>
          </div>
        </div>
      </div>
    </section>

    <!-- ─── TOOL DEFINITIONS CATALOG ─── -->
    <section class="container" id="tools">
      <div class="section-title-wrap">
        <span class="section-num">/04 — EXPOSED MCP TOOLS</span>
        <h2 class="section-h2">Complete Agency Over Time.</h2>
        <p class="section-p">7 native tools callable by any LLM to create, inspect, query, and synchronize your schedule.</p>
      </div>

      <div class="tools-grid">
        <div class="tool-card">
          <div class="tool-name">add_event</div>
          <div class="tool-desc">Create a new circular time block with title, start, end, category, color, and optional sub-tasks.</div>
        </div>

        <div class="tool-card">
          <div class="tool-name">get_schedule</div>
          <div class="tool-desc">Retrieve the full circular schedule for a given date formatted for polar dial rendering.</div>
        </div>

        <div class="tool-card">
          <div class="tool-name">find_free_slots</div>
          <div class="tool-desc">Find available circular gaps of at least min_minutes duration between active commitments.</div>
        </div>

        <div class="tool-card">
          <div class="tool-name">get_current_event</div>
          <div class="tool-desc">Inspect what is on the dial right now at this exact moment and how many minutes remain.</div>
        </div>

        <div class="tool-card">
          <div class="tool-name">delete_event</div>
          <div class="tool-desc">Remove an event from the schedule by ID or title match with immediate delta sync.</div>
        </div>

        <div class="tool-card">
          <div class="tool-name">update_event</div>
          <div class="tool-desc">Modify timing, category, tags, or completion status of an existing scheduled block.</div>
        </div>

        <div class="tool-card">
          <div class="tool-name">optimize_day</div>
          <div class="tool-desc">AI schedule defragmentation — group deep work, inject restorative gaps, align with circadian peaks.</div>
        </div>
      </div>
    </section>
  </main>

  <!-- ─── KSM × TECH FOOTER ─── -->
  <footer class="site-footer">
    <div class="container">
      <div class="footer-inner">
        <div>
          <div class="footer-brand-title">KSM × Tech Applied AI Studio</div>
          <p class="footer-brand-p">
            Designing and engineering calm, timeless, AI-native tools that replace anxiety with clarity.
          </p>
        </div>
        <div class="footer-links-col">
          <h4>Systems</h4>
          <a href="https://ksmxtech.com/radian/" target="_blank" rel="noopener">Radian (Dial)</a>
          <a href="https://ksmxtech.com/margadarshak/" target="_blank" rel="noopener">Mārgadarshak</a>
          <a href="https://ksmxtech.com/byf/" target="_blank" rel="noopener">Build Your Frame</a>
        </div>
        <div class="footer-links-col">
          <h4>Studio</h4>
          <a href="https://ksmxtech.com/" target="_blank" rel="noopener">KSM × Tech Studio ↗</a>
          <a href="https://x.com/otto_explorer" target="_blank" rel="noopener">Notes on X as Otto ↗</a>
          <a href="mailto:support@ksmxtech.com">support@ksmxtech.com</a>
        </div>
      </div>
      <div class="footer-bottom">
        <div>© 2026 KSM × Tech. India. All rights reserved.</div>
        <div class="footer-mantra">सत्यं · मांगल्यम् · रूपान्तरम्</div>
      </div>
    </div>
  </footer>

  <!-- ─── INTERACTIVE CLIENT LOGIC ─── -->
  <script>
    const SECTORS_INFO = {
      'nap': {
        time: '01:30 PM — 03:00 PM (1H 30M)',
        name: 'Nap Time & Circadian Recharge',
        sub: 'Category: Rest & Recovery · Biological Energy Dip',
        color: '#2563EB'
      },
      'deep': {
        time: '03:15 PM — 04:15 PM (1H)',
        name: 'Deep Focus: Architecture & MCP Sprint',
        sub: 'Category: High-Cognitive Deep Work · Draft Block',
        color: '#6366F1'
      },
      'bed': {
        time: '04:15 PM — 05:30 PM (1H 15M)',
        name: 'Bed Time & Stillness',
        sub: 'Category: Health & Recovery · Zero Device Threshold',
        color: '#64748B'
      }
    };

    function inspectAppSector(key) {
      const d = SECTORS_INFO[key];
      if (!d) return;
      const card = document.getElementById('hud-card');
      if (card) {
        card.style.borderLeftColor = d.color;
        document.getElementById('hud-time').textContent = d.time;
        document.getElementById('hud-name').textContent = d.name;
        document.getElementById('hud-sub').textContent = d.sub;
      }
    }

    let is24H = false;

    function setAppDialMode(is24) {
      is24H = is24;
      const btn12 = document.getElementById('btn-12h');
      const btn24 = document.getElementById('btn-24h');
      if (btn12 && btn24) {
        btn12.style.background = is24 ? 'transparent' : '#38BDF8';
        btn12.style.color = is24 ? '#94A3B8' : '#07090E';
        btn24.style.background = is24 ? '#38BDF8' : 'transparent';
        btn24.style.color = is24 ? '#07090E' : '#94A3B8';
      }
      updateDialTime();
    }

    function updateDialTime() {
      const now = new Date();
      let h = now.getHours();
      const m = now.getMinutes();
      const s = now.getSeconds();

      const timeStr = String(h).padStart(2, '0') + ':' + String(m).padStart(2, '0');
      const centerClock = document.getElementById('dial-center-time');
      if (centerClock) centerClock.textContent = timeStr;

      // Needle angle
      let deg = 0;
      if (is24H) {
        const totalMins = h * 60 + m + (s / 60);
        deg = totalMins * 0.25;
      } else {
        const totalMins = (h % 12) * 60 + m + (s / 60);
        deg = totalMins * 0.5;
      }

      const needle = document.getElementById('app-needle-assembly');
      if (needle) {
        needle.setAttribute('transform', 'rotate(' + deg + ' 150 150)');
      }
    }

    setInterval(updateDialTime, 1000);
    updateDialTime();

    function copyMcpUrl() {
      const url = "${url.origin}/mcp";
      navigator.clipboard.writeText(url).then(() => {
        const btn = document.getElementById('copy-btn');
        if (btn) {
          const old = btn.textContent;
          btn.textContent = "Copied ✓";
          setTimeout(() => btn.textContent = old, 2000);
        }
      });
    }
  </script>
</body>
</html>`;;
        return new Response(html, {
          headers: { ...corsHeaders, 'Content-Type': 'text/html; charset=utf-8' },
        });
      }

      return new Response(
        JSON.stringify({
          service: 'Radian Remote MCP Server',
          status: 'online',
          icon: `${url.origin}/icon.png`,
          logo: `${url.origin}/icon.png`,
          icons: [
            { src: `${url.origin}/icon.png`, sizes: '512x512', type: 'image/png' },
            { src: `${url.origin}/favicon.ico`, sizes: '16x16 24x24 32x32', type: 'image/x-icon' },
            { src: `${url.origin}/logo.svg`, sizes: 'any', type: 'image/svg+xml' },
          ],
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
