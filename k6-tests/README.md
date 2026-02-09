# k6 Load Testing Suite for Fenne Planner API

Comprehensive load testing implementation for the Rails API at `api.fenneplanner.com`.

## What is k6?

**k6** is a modern, open-source load testing tool that allows you to:
- **Simulate realistic traffic**: Create hundreds/thousands of virtual users hitting your API simultaneously
- **Find performance bottlenecks**: Discover how much load your API can handle before degrading
- **Measure performance**: Track response times, throughput, and error rates under different loads
- **Write tests in JavaScript**: Simple, familiar scripting language for defining user scenarios

Think of it as controlled "hammering" of your API to stress-test it before real users do.

## Prerequisites

- **k6** installed on your machine
- Access to the API (production or staging environment)

### Installing k6

**macOS:**
```bash
brew install k6
```

**Linux:**
```bash
sudo gpg -k
sudo gpg --no-default-keyring --keyring /usr/share/keyrings/k6-archive-keyring.gpg --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys C5AD17C747E3415A3642D57D77C6C491D6AC1D69
echo "deb [signed-by=/usr/share/keyrings/k6-archive-keyring.gpg] https://dl.k6.io/deb stable main" | sudo tee /etc/apt/sources.list.d/k6.list
sudo apt-get update
sudo apt-get install k6
```

**Windows:**
```powershell
choco install k6
```

**Or download from:** https://k6.io/docs/getting-started/installation/

## Quick Start

```bash
# Navigate to k6-tests directory
cd k6-tests

# Run smoke test (quick validation - 2 minutes)
k6 run scenarios/smoke.js

# Run load test (sustained load - 27 minutes)
k6 run scenarios/load.js

# Run stress test (find breaking point - 30 minutes)
k6 run scenarios/stress.js
```

## Environment Configuration

You can configure the API URL and other settings:

**Option 1: Environment Variables**
```bash
API_URL=https://staging.fenneplanner.com k6 run scenarios/smoke.js
```

**Option 2: .env file** (not natively supported by k6, but useful for documentation)
```bash
cp .env.example .env
# Edit .env with your configuration
```

## Test Scenarios

### Smoke Test (`scenarios/smoke.js`)

**Purpose:** Quick validation that the API is working correctly

**Configuration:**
- **VUs:** 3 concurrent users
- **Duration:** 2 minutes
- **Total requests:** ~100-150

**Success Criteria:**
- p95 response time < 500ms
- p99 response time < 1000ms
- Error rate < 1%
- Check success rate > 99%

**When to use:**
- Before deploying to production
- After configuration changes
- Quick health check
- Before running longer tests

### Load Test (`scenarios/load.js`)

**Purpose:** Test sustained realistic traffic and measure performance under normal conditions

**Configuration:**
- **VUs:** Ramps from 10 → 50 → 100 concurrent users
- **Duration:** 27 minutes
- **Stages:**
  - 2 min: Ramp to 10 users
  - 5 min: Ramp to 50 users
  - 10 min: Sustain 50 users
  - 3 min: Spike to 100 users
  - 5 min: Sustain 100 users
  - 2 min: Ramp down

**Success Criteria:**
- p95 response time < 1000ms
- p99 response time < 2000ms
- Error rate < 5%
- Check success rate > 95%

**When to use:**
- Testing production-like traffic
- Capacity planning
- Performance baseline establishment
- Before major releases

### Stress Test (`scenarios/stress.js`)

**Purpose:** Find the breaking point and maximum capacity of the API

**Configuration:**
- **VUs:** Ramps from 50 → 1000 concurrent users
- **Duration:** 30 minutes
- **Stages:**
  - 2 min: Ramp to 50 users
  - 5 min: Ramp to 100 users
  - 5 min: Ramp to 200 users
  - 5 min: Ramp to 500 users
  - 5 min: Ramp to 1000 users
  - 5 min: Sustain 1000 users
  - 3 min: Ramp down

**Success Criteria:**
- p95 response time < 2000ms
- p99 response time < 5000ms
- Error rate < 10%
- Check success rate > 90%

**When to use:**
- Finding infrastructure limits
- Identifying bottlenecks
- Capacity planning for growth
- Testing auto-scaling behavior

**WARNING:** This test will push your API to its limits. Monitor server resources (CPU, memory, database connections) during execution.

## User Flow

All scenarios execute the same realistic user journey:

1. **Signup** - Create new user account
2. **Get user info** - Verify authentication
3. **Create recipes** - Add 2-3 recipes with ingredients
4. **View recipes** - List all recipes
5. **View recipe details** - Get specific recipe
6. **Create schedule** - Plan 7 days of meals
7. **View schedule** - Retrieve schedule for date range
8. **Generate groceries** - Create grocery list from schedule
9. **View grocery items** - List all items
10. **Update groceries** - Mark some as completed
11. **Add manual item** - Create grocery item manually
12. **Search** - Autocomplete for food items
13. **Checkout** - Delete completed items
14. **View remaining** - Check remaining groceries
15. **Update recipe** - Modify existing recipe
16. **Check invitations** - View family invitations
17. **Logout** - End session

This flow covers all major API endpoints and mimics realistic user behavior with think times between actions.

## Project Structure

```
k6-tests/
├── scenarios/           # Test scenarios
│   ├── smoke.js        # Quick validation (3 VUs, 2 min)
│   ├── load.js         # Sustained load (10-100 VUs, 27 min)
│   └── stress.js       # Breaking point (50-1000 VUs, 30 min)
├── flows/              # User journey flows
│   └── full-user-flow.js  # Complete user journey
├── lib/                # Reusable libraries
│   ├── auth.js         # Authentication helpers
│   ├── api-client.js   # API client wrapper
│   ├── data-generators.js  # Test data generation
│   ├── config.js       # Configuration & thresholds
│   └── constants.js    # Enums and valid values
├── .env.example        # Environment configuration template
└── README.md           # This file
```

## Understanding Results

### Key Metrics

**http_req_duration** - Time for complete request/response cycle
- p50 (median): Middle value, half requests faster/slower
- p95: 95% of requests completed within this time
- p99: 99% of requests completed within this time
- **What's good?**
  - p95 < 1000ms: Excellent
  - p95 < 2000ms: Acceptable
  - p95 > 2000ms: Needs optimization

**http_req_failed** - Percentage of failed requests
- **What's good?**
  - < 1%: Excellent
  - < 5%: Good
  - > 5%: Issues detected, investigate

**checks** - Percentage of successful assertions
- **What's good?**
  - > 95%: Good
  - < 95%: Investigate failures

**iterations** - Complete user flow executions
- Higher is better (more throughput)

### Sample Output

```
     ✓ signup successful
     ✓ get recipes successful
     ✓ create recipe successful

     checks.........................: 99.12% ✓ 2847    ✗ 25
     data_received..................: 8.2 MB 68 kB/s
     data_sent......................: 3.4 MB 28 kB/s
     http_req_duration..............: avg=245ms min=12ms med=198ms max=1.2s p(95)=567ms p(99)=892ms
     http_req_failed................: 0.84%  ✓ 15      ✗ 1770
     http_reqs......................: 1785   14.87/s
     iterations.....................: 42     0.35/s
     vus............................: 3      min=3     max=3
     vus_max........................: 3      min=3     max=3
```

**What this tells you:**
- 99.12% of checks passed (excellent)
- Average response time: 245ms (good)
- p95 response time: 567ms (excellent)
- 0.84% error rate (very good)
- 42 complete user journeys in 2 minutes
- All thresholds passed

## Advanced Usage

### Custom VUs and Duration

```bash
# Override VUs and duration
k6 run --vus 20 --duration 5m scenarios/smoke.js
```

### Test Against Different Environment

```bash
# Test staging environment
API_URL=https://staging.fenneplanner.com k6 run scenarios/smoke.js
```

### Debug Mode

```bash
# See detailed HTTP request/response logs
k6 run --http-debug scenarios/smoke.js
```

### Save Results to JSON

```bash
# Export results for analysis
k6 run --out json=results.json scenarios/load.js
```

### Run with Specific Thresholds

```bash
# Set custom thresholds via environment
K6_THINK_TIME_MIN=2 K6_THINK_TIME_MAX=10 k6 run scenarios/load.js
```

## Troubleshooting

### API Unreachable

**Problem:** `health check failed - aborting test`

**Solution:**
```bash
# Verify API is accessible
curl https://api.fenneplanner.com/up

# Check if you need to specify a different URL
API_URL=https://your-api-url.com k6 run scenarios/smoke.js
```

### High Error Rates

**Problem:** Error rate > 5%

**Possible causes:**
- Rate limiting on the server
- Database connection pool exhausted
- Memory/CPU limits reached
- Network issues

**Solution:**
- Check server logs
- Monitor server resources (CPU, memory, DB connections)
- Reduce VUs or ramp-up rate
- Scale infrastructure

### Failed Checks

**Problem:** Check success rate < 95%

**Solution:**
- Review which specific checks are failing
- Verify API response format hasn't changed
- Check for validation errors (422 responses)
- Look for authentication issues (401 responses)

### Timeouts

**Problem:** Many requests timing out

**Solution:**
- Increase timeout in k6 (default is 60s per request)
- Optimize slow database queries
- Check for N+1 query problems
- Review server resource limits

## Best Practices

1. **Start Small:** Always run smoke test before load/stress tests
2. **Monitor Servers:** Watch CPU, memory, database during tests
3. **Test Staging First:** Never stress test production without warning
4. **Baseline Metrics:** Establish performance baseline with load test
5. **Off-Peak Testing:** Run stress tests during low-traffic periods
6. **Archive Results:** Save results for trend analysis over time
7. **Gradual Ramps:** Use staged ramp-ups to identify capacity thresholds
8. **Clean Data:** Tests create test users - plan for cleanup if needed

## Common Issues & Solutions

### Database Connection Pool Exhaustion

**Symptoms:** Errors spike at specific VU count

**Solution:** Increase database connection pool size

### Memory Leaks

**Symptoms:** Performance degrades over time during sustained load

**Solution:** Review code for memory leaks, monitor memory usage

### N+1 Queries

**Symptoms:** Response times increase with data volume

**Solution:** Add eager loading, optimize database queries

### Rate Limiting

**Symptoms:** 429 errors at high VU counts

**Solution:** Adjust rate limits or implement better caching

## CI/CD Integration

### GitHub Actions Example

```yaml
name: Load Test

on:
  workflow_dispatch:  # Manual trigger
  schedule:
    - cron: '0 2 * * 0'  # Weekly on Sunday at 2 AM

jobs:
  smoke-test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - name: Install k6
        run: |
          sudo gpg -k
          sudo gpg --no-default-keyring --keyring /usr/share/keyrings/k6-archive-keyring.gpg --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys C5AD17C747E3415A3642D57D77C6C491D6AC1D69
          echo "deb [signed-by=/usr/share/keyrings/k6-archive-keyring.gpg] https://dl.k6.io/deb stable main" | sudo tee /etc/apt/sources.list.d/k6.list
          sudo apt-get update
          sudo apt-get install k6
      - name: Run smoke test
        run: |
          cd k6-tests
          k6 run scenarios/smoke.js --quiet
```

## Resources

- [k6 Documentation](https://k6.io/docs/)
- [k6 Community Forum](https://community.k6.io/)
- [k6 GitHub](https://github.com/grafana/k6)
- [Performance Testing Best Practices](https://k6.io/docs/testing-guides/automated-performance-testing/)

## Support

For issues or questions about the Fenne Planner API, contact the development team.

For k6-specific questions, refer to the [official documentation](https://k6.io/docs/).
