#!/usr/bin/env node

// Simple CORS proxy for vscode-command-server
// Forwards requests to localhost:3000 with CORS headers added

const http = require('http');

const PORT = 3001;
const TARGET_HOST = 'localhost';
const TARGET_PORT = 3000;

const server = http.createServer((req, res) => {
  // Handle CORS preflight
  if (req.method === 'OPTIONS') {
    res.writeHead(200, {
      'Access-Control-Allow-Origin': '*',
      'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
      'Access-Control-Allow-Headers': 'Content-Type',
      'Access-Control-Max-Age': '86400',
    });
    res.end();
    return;
  }

  // Forward request to vscode-command-server
  // Clean up headers - remove Host and origin-related headers that would confuse the target
  const headers = { ...req.headers };
  delete headers.host;
  delete headers.origin;
  delete headers.referer;

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
      'Access-Control-Allow-Origin': '*',
    });
    proxyRes.pipe(res);
  });

  proxy.on('error', (err) => {
    console.error('Proxy error:', err);
    res.writeHead(502, { 'Content-Type': 'text/plain' });
    res.end('Bad Gateway');
  });

  req.pipe(proxy);
});

server.listen(PORT, '0.0.0.0', () => {
  console.log(`CORS proxy running on port ${PORT}, forwarding to ${TARGET_HOST}:${TARGET_PORT}`);
});
