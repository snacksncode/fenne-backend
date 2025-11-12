Rails.application.config.action_cable.allowed_request_origins = [
  "http://localhost:8081",
  "http://127.0.0.1:8081",
  "http://10.0.2.2:8081",
  # Add your specific local IP if you're testing on physical devices:
  # 'http://YOUR_LOCAL_IP_ADDRESS:8081',
  "http://172.20.10.13:8081",
  /http:\/\/localhost:\d+/, # Generic localhost on any port
  /http:\/\/127\.0\.0\.1:\d+/, # Generic 127.0.0.1 on any port
  /http:\/\/10\.0\.2\.2:\d+/ # Generic Android emulator on any port
]
