import { CONFIG } from '../lib/config.js';
import { ApiClient } from '../lib/api-client.js';
import { fullUserFlow } from '../flows/full-user-flow.js';

/**
 * Rapid Stress Test (M1 Max Optimized)
 * Purpose: Find the breaking point quickly
 * VUs: Ramp from 0 to 750 concurrent users
 * Duration: 7 minutes
 */
export const options = {
  stages: [
    { duration: '3m', target: 750 },   // Agresywny ramp-up do 750 w 3 minuty
    { duration: '3m', target: 750 },   // Utrzymanie (sustain) przez 3 minuty
    { duration: '1m', target: 0 },     // Ramp down w 1 minutę
  ],
  thresholds: CONFIG.stressThresholds,
  tags: { test_type: 'stress' },
};

export function setup() {
  console.log('Running health check...');
  const isHealthy = ApiClient.healthCheck();
  if (!isHealthy) {
    throw new Error('API health check failed - aborting stress test');
  }
  console.log('API is healthy, starting rapid stress test (7 min)...');
  console.log('Target: 750 concurrent VUs');
}

export default function() {
  fullUserFlow();
}

export function teardown(data) {
  console.log('Rapid stress test completed');
}