#!/usr/bin/env bash
set -euo pipefail
umask 077
SSH=(ssh -i "$HOME/.ssh/staging_key" -o BatchMode=yes -o StrictHostKeyChecking=yes -p "$SSH_PORT" "$SSH_USER@$SSH_HOST")
SCP=(scp -q -i "$HOME/.ssh/staging_key" -o BatchMode=yes -o StrictHostKeyChecking=yes -P "$SSH_PORT")
REMOTE_FIXTURE="/home/cepqontag-deploy/staging-fixture-$GITHUB_RUN_ID.json"
cleanup() {
  if [ -f staging-fixture.json ]; then
    "${SCP[@]}" staging-fixture.json "$SSH_USER@$SSH_HOST:$REMOTE_FIXTURE" || true
    "${SSH[@]}" "node - cleanup $REMOTE_FIXTURE" < tool/staging/fixture.cjs || true
    "${SSH[@]}" "rm -f $REMOTE_FIXTURE" || true
  fi
  for file in .staging-tunnel.pid .staging-site.pid .staging-chromedriver.pid; do
    if [ -f "$file" ]; then kill "$(cat "$file")" 2>/dev/null || true; rm -f "$file"; fi
  done
  rm -f staging-fixture.json staging-auth-state.json web/staging-fixture.json
}
if [ "${1:-all}" = cleanup ]; then cleanup; exit; fi
if [ "${1:-all}" = prepare ]; then
trap 'status=$?; if [ "$status" -ne 0 ]; then cleanup; fi' EXIT
# The only exposed test listener is local to this ephemeral runner.
nohup ssh -i "$HOME/.ssh/staging_key" -o BatchMode=yes -o StrictHostKeyChecking=yes -o ExitOnForwardFailure=yes -p "$SSH_PORT" -N -L 127.0.0.1:18091:127.0.0.1:8091 "$SSH_USER@$SSH_HOST" < /dev/null > /tmp/staging-tunnel.log 2>&1 &
tunnel_pid=$!
printf '%s\n' "$tunnel_pid" > .staging-tunnel.pid
command -v chromedriver
nohup chromedriver --port=4444 < /dev/null > /tmp/staging-chromedriver.log 2>&1 &
printf '%s\n' "$!" > .staging-chromedriver.pid
for attempt in $(seq 1 20); do
  if curl -fsS http://127.0.0.1:18091/api/environment > /tmp/staging-identity.json; then break; fi
  sleep 1
done
node -e "const x=require('/tmp/staging-identity.json');if(x.environment!=='staging'||x.database!=='heycar_staging'||x.externalServicesDisabled!==true)process.exit(1)"
"${SSH[@]}" 'node - seed' < tool/staging/fixture.cjs > staging-fixture.json
cp staging-fixture.json web/staging-fixture.json
flutter drive --driver test_driver/staging_campaign_driver.dart --target integration_test/staging_business_test.dart -d web-server --web-hostname=127.0.0.1 --web-port=8085 --browser-name=chrome --headless --dart-define=APP_ENV=staging --dart-define=API_BASE_URL=http://127.0.0.1:18091 --dart-define=STAGING_SSH_TUNNEL=true --dart-define=STAGING_PHASE=create
node -e "const fs=require('fs');const f=require('./staging-fixture.json');f.campaignId=require('./staging-ui-result.json').campaignId;fs.writeFileSync('staging-fixture.json',JSON.stringify(f),{mode:0o600})"
cp staging-fixture.json web/staging-fixture.json
"${SCP[@]}" staging-fixture.json "$SSH_USER@$SSH_HOST:$REMOTE_FIXTURE"
# Preserve the actual moderation boundary. Only this newly created test
# account's campaign is approved by a guarded staging-only SQL operation.
"${SSH[@]}" "node - approve $REMOTE_FIXTURE" < tool/staging/fixture.cjs
flutter drive --driver test_driver/staging_campaign_driver.dart --target integration_test/staging_business_test.dart -d web-server --web-hostname=127.0.0.1 --web-port=8085 --browser-name=chrome --headless --dart-define=APP_ENV=staging --dart-define=API_BASE_URL=http://127.0.0.1:18091 --dart-define=STAGING_SSH_TUNNEL=true --dart-define=STAGING_PHASE=publish
"${SSH[@]}" "node - active $REMOTE_FIXTURE" < tool/staging/fixture.cjs
exit 0
fi
trap cleanup EXIT
tunnel_pid=$(cat .staging-tunnel.pid)
campaign_id=$(node -p "require('./staging-fixture.json').campaignId")
device_id=$(adb devices | awk 'NR>1 && $2=="device" && $1 ~ /^emulator-/ {print $1; exit}')
test -n "$device_id"
adb emu geo fix 28.9784 41.0082
while kill -0 "$tunnel_pid" 2>/dev/null; do adb emu geo fix 28.9784 41.0082 > /dev/null 2>&1; sleep 3; done &
# Build and grant the exact integration binary with this runner's signing key.
# Installing the downloadable artifact first loses grants when Flutter replaces
# its differently signed package. Never grant or uninstall the production ID.
android_phase() {
  local active="$1"
  flutter build apk --debug --target integration_test/staging_campaign_test.dart --dart-define=APP_ENV=staging --dart-define=API_BASE_URL=http://10.0.2.2:18091 --dart-define=STAGING_SSH_TUNNEL=true --dart-define=STAGING_CAMPAIGN_ID="$campaign_id" --dart-define=STAGING_EXPECT_ACTIVE="$active"
  adb -s "$device_id" install -r -g build/app/outputs/flutter-apk/app-debug.apk
  adb -s "$device_id" shell pm grant com.cepqar.app.staging android.permission.ACCESS_FINE_LOCATION
  adb -s "$device_id" shell pm grant com.cepqar.app.staging android.permission.ACCESS_COARSE_LOCATION
  adb -s "$device_id" shell settings put secure location_mode 3
  flutter drive -d "$device_id" --driver test_driver/staging_campaign_driver.dart --target integration_test/staging_campaign_test.dart --use-application-binary=build/app/outputs/flutter-apk/app-debug.apk
}
android_phase true
flutter drive --driver test_driver/staging_campaign_driver.dart --target integration_test/staging_business_test.dart -d web-server --web-hostname=127.0.0.1 --web-port=8085 --browser-name=chrome --headless --dart-define=APP_ENV=staging --dart-define=API_BASE_URL=http://127.0.0.1:18091 --dart-define=STAGING_SSH_TUNNEL=true --dart-define=STAGING_PHASE=deactivate
"${SSH[@]}" "node - inactive $REMOTE_FIXTURE" < tool/staging/fixture.cjs
android_phase false
printf '%s\n' '{"transport":"SSH loopback","database":"heycar_staging","panel":"real Chromium UI","mobile":"real Android emulator UI","campaignLifecycle":"passed"}' > staging-evidence/result.json
kill "$tunnel_pid" || true
