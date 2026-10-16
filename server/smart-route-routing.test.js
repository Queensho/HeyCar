const assert = require('node:assert/strict');
const test = require('node:test');
const { preview } = require('./smart-route-routing');

test('routing refuses to call provider without a configured key', async () => {
  const old = process.env.TOMTOM_API_KEY;
  delete process.env.TOMTOM_API_KEY;
  try {
    const result = await preview({ origin: {lat:41,lon:28}, destination: {lat:41.1,lon:28.1} });
    assert.deepEqual(result, {available:false,reason:'NOT_CONFIGURED'});
  } finally {
    if (old !== undefined) process.env.TOMTOM_API_KEY = old;
  }
});

test('routing rejects malformed coordinates before database access', async () => {
  const old = process.env.TOMTOM_API_KEY;
  process.env.TOMTOM_API_KEY = 'local-test-key';
  try {
    const result = await preview({origin:{lat:999,lon:28},destination:{lat:41,lon:28}});
    assert.equal(result.available,false);
    assert.equal(result.reason,'INVALID_COORDINATES');
  } finally {
    if (old === undefined) delete process.env.TOMTOM_API_KEY;
    else process.env.TOMTOM_API_KEY = old;
  }
});

test('routing refuses provider calls without a durable quota database', async () => {
  const old = process.env.TOMTOM_API_KEY;
  process.env.TOMTOM_API_KEY = 'local-test-key';
  try {
    const result = await preview({origin:{lat:41,lon:28},destination:{lat:41.1,lon:28.1}});
    assert.equal(result.reason,'BUDGET_UNAVAILABLE');
  } finally {
    if (old === undefined) delete process.env.TOMTOM_API_KEY;
    else process.env.TOMTOM_API_KEY = old;
  }
});
