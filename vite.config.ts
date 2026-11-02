import { defineConfig, Plugin } from 'vite';
import react from '@vitejs/plugin-react';
import tailwindcss from '@tailwindcss/vite';
import http from 'http';
import https from 'https';
import { execFile } from 'child_process';
import net from 'net';
import { URL, fileURLToPath } from 'url';
import path from 'path';

const __dirname = path.dirname(fileURLToPath(import.meta.url));

// Vite dev and preview server plugin to proxy requests to MikroTik RouterOS and bypass CORS during web preview
function mikrotikProxyPlugin(): Plugin {
  const handler = (req: http.IncomingMessage, res: http.ServerResponse) => {
    if (req.method === 'OPTIONS') {
      res.setHeader('Access-Control-Allow-Origin', '*');
      res.setHeader('Access-Control-Allow-Methods', 'GET, POST, PUT, PATCH, DELETE, OPTIONS');
      res.setHeader('Access-Control-Allow-Headers', '*');
      res.statusCode = 204;
      res.end();
      return;
    }

    const targetUrlStr = req.headers['x-target-url'] as string;
    const authHeader = req.headers['x-auth-header'] as string;

    if (!targetUrlStr) {
      res.statusCode = 400;
      res.setHeader('Content-Type', 'application/json');
      res.end(JSON.stringify({ error: 'Missing x-target-url header' }));
      return;
    }

    try {
      const targetUrl = new URL(targetUrlStr);
      const isHttps = targetUrl.protocol === 'https:';
      const requester = isHttps ? https : http;

      const options: https.RequestOptions = {
        hostname: targetUrl.hostname.replace(/^\[|\]$/g, ''),
        port: targetUrl.port || (isHttps ? 443 : 80),
        path: targetUrl.pathname + targetUrl.search,
        method: req.method,
        headers: {
          'Accept': 'application/json',
          'User-Agent': 'FNet-MikroTik-Client',
          ...(req.headers['content-type'] ? { 'Content-Type': req.headers['content-type'] } : {}),
          ...(req.headers['content-length'] ? { 'Content-Length': req.headers['content-length'] } : {}),
          ...(authHeader ? { 'Authorization': authHeader } : {}),
        },
        rejectUnauthorized: false, // Allow self-signed SSL on local routers
        timeout: 8000,
      };

      const proxyReq = requester.request(options, (proxyRes) => {
        res.setHeader('Access-Control-Allow-Origin', '*');
        res.setHeader('Access-Control-Allow-Methods', 'GET, POST, PUT, PATCH, DELETE, OPTIONS');
        res.setHeader('Content-Type', proxyRes.headers['content-type'] || 'application/json');
        res.statusCode = proxyRes.statusCode || 200;
        proxyRes.pipe(res);
      });

      proxyReq.on('timeout', () => {
        proxyReq.destroy();
        if (!res.headersSent) {
          res.statusCode = 504;
          res.setHeader('Content-Type', 'application/json');
          res.end(JSON.stringify({ error: 'Connection timed out to MikroTik router' }));
        }
      });

      proxyReq.on('error', (err) => {
        if (!res.headersSent) {
          res.statusCode = 502;
          res.setHeader('Content-Type', 'application/json');
          res.end(JSON.stringify({ error: `Connection failed: ${err.message}` }));
        }
      });

      req.pipe(proxyReq);
    } catch (err: any) {
      res.statusCode = 500;
      res.setHeader('Content-Type', 'application/json');
      res.end(JSON.stringify({ error: `Invalid URL: ${err.message}` }));
    }
  };

  const pingHandler = (req: http.IncomingMessage, res: http.ServerResponse) => {
    if (req.method === 'OPTIONS') {
      res.setHeader('Access-Control-Allow-Origin', '*');
      res.setHeader('Access-Control-Allow-Methods', 'GET, OPTIONS');
      res.setHeader('Access-Control-Allow-Headers', '*');
      res.statusCode = 204;
      res.end();
      return;
    }

    res.setHeader('Access-Control-Allow-Origin', '*');
    res.setHeader('Content-Type', 'application/json');

    const reqUrl = new URL(req.url || '/', 'http://localhost');
    const rawHost = (reqUrl.searchParams.get('host') || '').trim();
    const portStr = reqUrl.searchParams.get('port');
    const port = portStr ? parseInt(portStr, 10) : 80;

    if (!rawHost) {
      res.statusCode = 400;
      res.end(JSON.stringify({ success: false, reply: false, error: 'Host is required' }));
      return;
    }

    const cleanHost = rawHost
      .replace(/^https?:\/\//i, '')
      .replace(/^\[|\]$/g, '')
      .split('/')[0]
      .split(':')[0]
      .trim();

    // Security check: validate host format
    if (!/^[a-zA-Z0-9.-]+$/.test(cleanHost)) {
      res.statusCode = 400;
      res.end(JSON.stringify({ success: false, reply: false, error: 'Invalid host' }));
      return;
    }

    const startTime = Date.now();

    // 1. First attempt ICMP ping with 1s timeout
    execFile('ping', ['-c', '1', '-W', '1', cleanHost], (err, stdout) => {
      if (!err) {
        const timeMatch = stdout.match(/time[=<]([\d.]+)\s*ms/i);
        const latency = timeMatch ? parseFloat(timeMatch[1]) : (Date.now() - startTime);
        res.statusCode = 200;
        res.end(JSON.stringify({ success: true, reply: true, timeMs: Math.round(latency) }));
        return;
      }

      // 2. If ICMP ping failed or dropped by firewall, test TCP socket connection
      const socket = new net.Socket();
      let finished = false;

      const finish = (result: { success: boolean; reply: boolean; timeMs?: number; via?: string; error?: string }) => {
        if (finished) return;
        finished = true;
        socket.destroy();
        res.statusCode = 200;
        res.end(JSON.stringify(result));
      };

      socket.setTimeout(1500);

      socket.on('connect', () => {
        const latency = Date.now() - startTime;
        finish({ success: true, reply: true, timeMs: Math.max(1, Math.round(latency)), via: 'tcp' });
      });

      socket.on('timeout', () => {
        finish({ success: false, reply: false, error: 'Request timed out' });
      });

      socket.on('error', (sockErr: any) => {
        // If connection refused (ECONNREFUSED), host still replied to TCP handshake!
        if (sockErr.code === 'ECONNREFUSED') {
          const latency = Date.now() - startTime;
          finish({ success: true, reply: true, timeMs: Math.max(1, Math.round(latency)), via: 'tcp-refused' });
        } else {
          finish({ success: false, reply: false, error: sockErr.message || 'Host unreachable' });
        }
      });

      socket.connect(port > 0 && port <= 65535 ? port : 80, cleanHost);
    });
  };

  return {
    name: 'mikrotik-dev-proxy',
    configureServer(server) {
      server.middlewares.use('/api-proxy', handler);
      server.middlewares.use('/api-ping', pingHandler);
    },
    configurePreviewServer(server) {
      server.middlewares.use('/api-proxy', handler);
      server.middlewares.use('/api-ping', pingHandler);
    },
  };
}

export default defineConfig({
  plugins: [tailwindcss(), react(), mikrotikProxyPlugin()],
  resolve: {
    alias: {
      '@': path.resolve(__dirname, './src'),
    },
  },
  server: {
    host: '0.0.0.0',
    port: 5173
  },
  preview: {
    host: '0.0.0.0',
    port: 4173
  },
  build: {
    chunkSizeWarningLimit: 1000,
    rollupOptions: {
      output: {
        manualChunks(id) {
          if (id.includes('node_modules')) {
            if (id.includes('@radix-ui')) return 'radix';
            if (id.includes('framer-motion')) return 'motion';
            if (id.includes('lucide-react')) return 'icons';
            return 'vendor';
          }
        }
      }
    }
  }
});
