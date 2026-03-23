const express = require('express');
const crypto = require('crypto');
const app = express();
const PORT = 3100;

// Store webhook endpoints and their received requests in memory
// Each endpoint expires after 24 hours
const endpoints = new Map();

// Parse incoming request bodies
app.use('/hook', express.raw({ type: '*/*', limit: '1mb' }));
app.use(express.json({ limit: '1mb' }));

// Clean up expired endpoints every 10 minutes
setInterval(function() {
  const now = Date.now();
  for (const [id, endpoint] of endpoints) {
    if (now - endpoint.created > 24 * 60 * 60 * 1000) {
      // Close any open SSE connections
      endpoint.clients.forEach(function(res) {
        res.end();
      });
      endpoints.delete(id);
    }
  }
}, 10 * 60 * 1000);

// Create a new webhook endpoint
app.post('/api/webhook/create', function(req, res) {
  const id = crypto.randomBytes(8).toString('hex');
  endpoints.set(id, {
    id: id,
    created: Date.now(),
    requests: [],
    clients: []
  });
  res.json({ id: id });
});

// Get endpoint info and all received requests
app.get('/api/webhook/:id', function(req, res) {
  const endpoint = endpoints.get(req.params.id);
  if (!endpoint) {
    return res.status(404).json({ error: 'Endpoint not found or expired' });
  }
  res.json({
    id: endpoint.id,
    created: endpoint.created,
    requestCount: endpoint.requests.length,
    requests: endpoint.requests
  });
});

// SSE stream for real-time updates
app.get('/api/webhook/:id/stream', function(req, res) {
  const endpoint = endpoints.get(req.params.id);
  if (!endpoint) {
    return res.status(404).json({ error: 'Endpoint not found or expired' });
  }

  res.writeHead(200, {
    'Content-Type': 'text/event-stream',
    'Cache-Control': 'no-cache',
    'Connection': 'keep-alive',
    'X-Accel-Buffering': 'no'
  });

  res.write('data: {"type":"connected"}\n\n');

  endpoint.clients.push(res);

  req.on('close', function() {
    endpoint.clients = endpoint.clients.filter(function(c) { return c !== res; });
  });
});

// Receive incoming webhooks — catch ALL methods
function handleWebhook(req, res) {
  const id = req.params.id;
  const endpoint = endpoints.get(id);

  if (!endpoint) {
    return res.status(404).json({ error: 'Endpoint not found or expired' });
  }

  // Build the request record
  var bodyStr = '';
  if (req.body) {
    if (Buffer.isBuffer(req.body)) {
      bodyStr = req.body.toString('utf8');
    } else if (typeof req.body === 'string') {
      bodyStr = req.body;
    } else {
      bodyStr = JSON.stringify(req.body);
    }
  }

  // Try to parse as JSON for pretty display
  var bodyParsed = null;
  try {
    bodyParsed = JSON.parse(bodyStr);
  } catch(e) {
    // not JSON, that's fine
  }

  var record = {
    id: crypto.randomBytes(4).toString('hex'),
    timestamp: Date.now(),
    method: req.method,
    path: req.path,
    query: req.query,
    headers: req.headers,
    body: bodyStr,
    bodyParsed: bodyParsed,
    ip: req.ip || req.connection.remoteAddress,
    size: bodyStr.length
  };

  // Store (keep last 50 requests per endpoint)
  endpoint.requests.unshift(record);
  if (endpoint.requests.length > 50) {
    endpoint.requests = endpoint.requests.slice(0, 50);
  }

  // Notify SSE clients
  var eventData = JSON.stringify({ type: 'request', data: record });
  endpoint.clients.forEach(function(client) {
    client.write('data: ' + eventData + '\n\n');
  });

  // Respond to the webhook sender
  res.status(200).json({ received: true });
}

app.all('/hook/:id', handleWebhook);
app.all('/hook/:id/*', handleWebhook);

app.listen(PORT, '127.0.0.1', function() {
  console.log('Webhook tester running on port ' + PORT);
});
