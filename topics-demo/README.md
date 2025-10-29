# topics-api
### Give the localhost a Topics eligible name:
#### Open up /etc/hosts
```bash
sudo nano /etc/hosts
```
#### Add the following line:
```bash
127.0.0.1  sports.test
127.0.0.1  games.test
127.0.0.1  news.test
127.0.0.1  cooking.test
127.0.0.1  travel.test
127.0.0.1  tennis.test
```

### Install mkcert
```bash
brew install mkcert
```

### Install the Root Certificate
```bash
mkcert -install
```

### Generate certificates for https connection
```bash
mkcert sports.test games.test news.test cooking.test travel.test tennis.test
```

### Run https_server
```bash
python3 https_server.py
```

### Run Chrome in development mode
```bash
/Applications/Google\ Chrome.app/Contents/MacOS/Google\ Chrome \
  --enable-features=BrowsingTopics,BrowsingTopicsParameters:time_period_per_epoch/60s,max_epoch_introduction_delay/3s,PrivacySandboxAdsAPIsOverride,PrivacySandboxSettings3,OverridePrivacySandboxSettingsLocalTesting,BrowsingTopicsBypassIPIsPubliclyRoutableCheck,BrowsingTopicsBypassIPIsPubliclyRoutableCheck \
  --privacy-sandbox-enrollment-overrides=https://sports.test:8080,https://games.test:8080,https://news.test:8080,https://cooking.test:8080,https://travel.test:8080,https://tennis.test:8080 \
  --user-data-dir="chrome-topics-profile"
```

### Useful:
```bash
chrome://flags/
chrome://topics-internals/
```
