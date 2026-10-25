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
  rm -f staging-fixture.json staging-auth-state.json
}
trap cleanup EXIT
# The only exposed test listener is local to this ephemeral runner.
ssh -i "$HOME/.ssh/staging_key" -o BatchMode=yes -o StrictHostKeyChecking=yes -o ExitOnForwardFailure=yes -p "$SSH_PORT" -N -L 127.0.0.1:18091:127.0.0.1:8091 "$SSH_USER@$SSH_HOST" &
tunnel_pid=$!
python3 -m http.server 8085 --bind 127.0.0.1 --directory staging-site > /tmp/staging-site.log 2>&1 &
for attempt in $(seq 1 20); do
  if curl -fsS http://127.0.0.1:18091/api/environment > /tmp/staging-identity.json; then break; fi
  sleep 1
done
node -e "const x=require('/tmp/staging-identity.json');if(x.environment!=='staging'||x.database!=='heycar_staging'||x.externalServicesDisabled!==true)process.exit(1)"
"${SSH[@]}" 'node - seed' < tool/staging/fixture.cjs > staging-fixture.json
node tool/staging/panel_e2e.cjs create staging-fixture.json
node tool/staging/panel_e2e.cjs edit staging-fixture.json
"${SCP[@]}" staging-fixture.json "$SSH_USER@$SSH_HOST:$REMOTE_FIXTURE"
# Preserve the actual moderation boundary. Only this newly created test
# account's campaign is approved by a guarded staging-only SQL operation.
"${SSH[@]}" "node - approve $REMOTE_FIXTURE" < tool/staging/fixture.cjs
node tool/staging/panel_e2e.cjs publish staging-fixture.json
"${SSH[@]}" "node - active $REMOTE_FIXTURE" < tool/staging/fixture.cjs
campaign_id=$(node -p "require('./staging-fixture.json').campaignId")
adb install -r staging-apk/app-debug.apk
adb shell pm grant com.cepqar.app.staging android.permission.ACCESS_FINE_LOCATION
adb shell pm grant com.cepqar.app.staging android.permission.ACCESS_COARSE_LOCATION
adb emu geo fix 28.9784 41.0082
flutter drive --driver test_driver/staging_campaign_driver.dart --target integration_test/staging_campaign_test.dart --dart-define=APP_ENV=staging --dart-define=API_BASE_URL=http://10.0.2.2:18091 --dart-define=STAGING_SSH_TUNNEL=true --dart-define=STAGING_CAMPAIGN_ID="$campaign_id" --dart-define=STAGING_EXPECT_ACTIVE=true
node tool/staging/panel_e2e.cjs deactivate staging-fixture.json
"${SSH[@]}" "node - inactive $REMOTE_FIXTURE" < tool/staging/fixture.cjs
flutter drive --driver test_driver/staging_campaign_driver.dart --target integration_test/staging_campaign_test.dart --dart-define=APP_ENV=staging --dart-define=API_BASE_URL=http://10.0.2.2:18091 --dart-define=STAGING_SSH_TUNNEL=true --dart-define=STAGING_CAMPAIGN_ID="$campaign_id" --dart-define=STAGING_EXPECT_ACTIVE=false
printf '%s\n' '{"transport":"SSH loopback","database":"heycar_staging","panel":"real Chromium UI","mobile":"real Android emulator UI","campaignLifecycle":"passed"}' > staging-evidence/result.json
kill "$tunnel_pid" || true
