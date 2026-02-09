import { CONFIG } from '../lib/config.js';
import { ApiClient } from '../lib/api-client.js';
import { fullUserFlow } from '../flows/full-user-flow.js';

export const options = {
  stages: [
    { duration: '30s', target: 3 },
    { duration: '3m', target: 10 },
  ],
  thresholds: CONFIG.smokeThresholds,
  tags: { test_type: 'smoke' },
};

export function setup() {
  // Verify API is healthy before starting
  console.log('Running health check...');
  const isHealthy = ApiClient.healthCheck();
  if (!isHealthy) {
    throw new Error('API health check failed - aborting smoke test');
  }
  console.log('API is healthy, starting smoke test...');
}

export default function() {
  fullUserFlow();
}

export function teardown(data) {
  console.log('Smoke test completed');
}
