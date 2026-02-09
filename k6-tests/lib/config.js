// Configuration for k6 load tests

export const CONFIG = {
  // Base API URL - can be overridden with API_URL environment variable
  baseUrl: __ENV.API_URL || 'http://127.0.0.1:3000',

  // Thresholds for smoke tests (light load, quick validation)
  smokeThresholds: {
    http_req_duration: ['p(95)<500', 'p(99)<1000'],  // 95% under 500ms, 99% under 1s
    http_req_failed: ['rate<0.01'],                  // Less than 1% errors
    checks: ['rate>0.99'],                           // More than 99% successful checks
  },

  // Thresholds for load tests (sustained realistic traffic)
  loadThresholds: {
    http_req_duration: ['p(95)<1000', 'p(99)<2000'], // 95% under 1s, 99% under 2s
    http_req_failed: ['rate<0.05'],                  // Less than 5% errors
    checks: ['rate>0.95'],                           // More than 95% successful checks
  },

  // Thresholds for stress tests (finding breaking point)
  stressThresholds: {
    http_req_duration: ['p(95)<2000', 'p(99)<5000'], // 95% under 2s, 99% under 5s
    http_req_failed: ['rate<0.10'],                  // Less than 10% errors allowed
    checks: ['rate>0.90'],                           // More than 90% successful checks
  },

  // Think times (in seconds) - realistic delays between user actions
  thinkTime: {
    min: __ENV.K6_THINK_TIME_MIN || 1,
    max: __ENV.K6_THINK_TIME_MAX || 5,
  },
};
