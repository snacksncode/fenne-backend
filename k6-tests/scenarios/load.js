import { CONFIG } from '../lib/config.js';
import { ApiClient } from '../lib/api-client.js';
import { fullUserFlow } from '../flows/full-user-flow.js';

/**
 * Load Test
 * Purpose: Test sustained realistic traffic and measure performance
 * VUs: Ramp from 10 to 100 concurrent users
 * Duration: 27 minutes
 * Thresholds: p95 < 1000ms, p99 < 2000ms, errors < 5%
 */
export const options = {
  stages: [
    { duration: '2m', target: 10 },   // Ramp up to 10 users
    { duration: '5m', target: 50 },   // Ramp up to 50 users
    { duration: '10m', target: 50 },  // Stay at 50 users (sustained load)
    { duration: '3m', target: 100 },  // Spike to 100 users
    { duration: '5m', target: 100 },  // Stay at 100 users (peak load)
    { duration: '2m', target: 0 },    // Ramp down gracefully
  ],
  thresholds: CONFIG.loadThresholds,
  tags: { test_type: 'load' },
};

export function setup() {
  console.log('Running health check...');
  const isHealthy = ApiClient.healthCheck();
  if (!isHealthy) {
    throw new Error('API health check failed - aborting load test');
  }
  console.log('API is healthy, starting load test...');
  console.log('This test will run for approximately 27 minutes');
}

export default function() {
  fullUserFlow();
}

export function teardown(data) {
  console.log('Load test completed');
}
