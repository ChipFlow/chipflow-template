#!/usr/bin/env node

// CORS proxy for vscode-command-server with security restrictions
// Only allows safe commands from trusted origins

const http = require('http');

const PORT = 3001;
const TARGET_HOST = 'localhost';
const TARGET_PORT = 3000;

// Security: Only allow these specific commands
const ALLOWED_COMMANDS = [
  'workbench.action.terminal.openUrlLink',
  'simpleBrowser.api.open'
];

// Security: Only allow requests from these origins
const ALLOWED_ORIGINS = [
  'https://configurator.chipflow.io',
  'https://configurator.chipflow-infra.com'
];

// Security: Only allow HTTPS URLs from these domains
const ALLOWED_URL_DOMAINS = [
  'docs.chipflow.io',
  'configurator.chipflow.io',
  'github.com',
  'chipflow.io'
];

function isAllowedOrigin(origin) {
  if (!origin) return false;
  return ALLOWED_ORIGINS.some(allowed =>
    origin === allowed || origin.startsWith(allowed + '.')
  );
}

function isAllowedUrl(url) {
  try {
    const parsed = new URL(url);
    // Must be HTTPS
    if (parsed.protocol !== 'https:') return false;
    // Must be from allowed domain
    return ALLOWED_URL_DOMAINS.some(domain =>
      parsed.hostname === domain || parsed.hostname.endsWith('.' + domain)
    );
  } catch {
    return false;
  }
}

function validateRequest(body, origin) {
  // Check origin
  if (!isAllowedOrigin(origin)) {
    return { valid: false, error: 'Unauthorized origin' };
  }

  // Parse and validate request body
  let data;
  try {
    data = JSON.parse(body);
  } catch {
    return { valid: false, error: 'Invalid JSON' };
  }

  // Check command is allowed
  if (!ALLOWED_COMMANDS.includes(data.command)) {
    return { valid: false, error: 'Command not allowed' };
  }

  // Validate URL argument for URL-opening commands
  if (data.command === 'workbench.action.terminal.openUrlLink' ||
      data.command === 'simpleBrowser.api.open') {
    const url = Array.isArray(data.args) ? data.args[0] : null;
    if (!url || !isAllowedUrl(url)) {
      return { valid: false, error: 'URL not allowed' };
    }
  }

  return { valid: true };
}

const server = http.createServer((req, res) => {
  const origin = req.headers.origin || req.headers.referer;

  // Handle CORS preflight
  if (req.method === 'OPTIONS') {
    // Only respond with CORS headers for allowed origins
    if (isAllowedOrigin(origin)) {
      res.writeHead(200, {
        'Access-Control-Allow-Origin': origin,
        'Access-Control-Allow-Methods': 'POST, OPTIONS',
        'Access-Control-Allow-Headers': 'Content-Type',
        'Access-Control-Max-Age': '86400',
      });
    } else {
      res.writeHead(403, { 'Content-Type': 'text/plain' });
      res.end('Forbidden origin');
      return;
    }
    res.end();
    return;
  }

  // Only allow POST requests to /execute endpoint
  if (req.method !== 'POST' || req.url !== '/execute') {
    res.writeHead(405, {
      'Content-Type': 'application/json',
      'Access-Control-Allow-Origin': isAllowedOrigin(origin) ? origin : ''
    });
    res.end(JSON.stringify({ success: false, error: 'Method not allowed' }));
    return;
  }

  // Read and validate request body
  let body = '';
  req.on('data', chunk => {
    body += chunk.toString();
  });

  req.on('end', () => {
    const validation = validateRequest(body, origin);

    if (!validation.valid) {
      console.error(`Security violation: ${validation.error} from ${origin}`);
      res.writeHead(403, {
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': isAllowedOrigin(origin) ? origin : ''
      });
      res.end(JSON.stringify({ success: false, error: validation.error }));
      return;
    }

    // Forward validated request to vscode-command-server
    const headers = { ...req.headers };
    delete headers.host;
    delete headers.origin;
    delete headers.referer;
    headers['content-length'] = Buffer.byteLength(body);

    const options = {
      hostname: TARGET_HOST,
      port: TARGET_PORT,
      path: req.url,
      method: req.method,
      headers: headers,
    };

    const proxy = http.request(options, (proxyRes) => {
      // Add CORS headers to response
      res.writeHead(proxyRes.statusCode, {
        ...proxyRes.headers,
        'Access-Control-Allow-Origin': origin,
      });
      proxyRes.pipe(res);
    });

    proxy.on('error', (err) => {
      console.error('Proxy error:', err);
      res.writeHead(502, {
        'Content-Type': 'text/plain',
        'Access-Control-Allow-Origin': origin
      });
      res.end('Bad Gateway');
    });

    proxy.write(body);
    proxy.end();
  });
});

server.listen(PORT, '0.0.0.0', () => {
  console.log(`Secure CORS proxy running on port ${PORT}`);
  console.log(`Allowed commands: ${ALLOWED_COMMANDS.join(', ')}`);
  console.log(`Allowed origins: ${ALLOWED_ORIGINS.join(', ')}`);
});
