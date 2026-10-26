# Public HTTPS marketplace release

Continues PR #265 on feature/isolated-marketplace-staging-20261025. Never merge
main or run a production backend/Nginx deployment for this workflow.

## Observed prerequisites

The refreshed SSH/HTTPS preflight on 2026-10-26 returned HTTP 301 and valid HTTPS
200 for https://staging-api-185-165-46-213.nip.io/api/environment. Identity is
staging / heycar_staging / 8091 with external services disabled. Nginx now has
zz-cepqontag-staging.conf proxying 127.0.0.1:8091. Production host config hashes,
production API health and Pages index hash are recorded by the read-only probe.
Do not rerun the clean-install root installer over this now-existing host. No
root/sudo or Nginx/certificate mutation is needed by the public release workflow.

## Workflow and artifacts

Public HTTPS Marketplace Release verifies actual TLS/identity, analyzes/tests,
builds staging-business-panel-direct-https and cepqontag-staging-direct-https-apk.
Builds use APP_ENV=staging and the verified public HTTPS API without an SSH flag.
Android package is com.cepqar.app.staging, name CepQontag STAGING, cleartext false,
production Firebase configuration absent and external registrations disabled.
A physical phone needs no SSH tunnel or adb reverse for this artifact.

The same tested Chrome/Android UI lifecycle runner is reused with
STAGING_PUBLIC_API. SSH is used ONLY for staging fixture setup/approval and
PostgreSQL readback/cleanup; all browser and Android API requests use public TLS.
Chrome creates/edits/publishes, Android Owner/Driver opens the same campaign and
its detail, Chrome deactivates, PostgreSQL verifies and Android verifies removal.
Only a uniquely generated fixture account is written/deleted in heycar_staging.
The downloadable APK itself is launched on the emulator before integration UI
binaries are built; its screenshot is separate evidence. This is not a claim
that every Owner/Driver onboarding/login flow or a physical phone was tested.

## Preserve the active Pages site

public_pages.py requires the exact existing github-pages deployment's Actions
run and SHA, and its unexpired complete github-pages artifact. It refuses an
unknown workflow, an unidentifiable source, expired archive, unsafe tar entries,
missing production paths or any critical live hash mismatch. It overlays ONLY
isletme-staging/, proving all other file bytes identical. It retains the original
complete Pages tar and preservation JSON as pages-before-staging-rollback-and-proof.

The publishing job serializes with the existing heycar-pages concurrency group,
rechecks source/deployed bytes just before publishing, then verifies production
paths and staging index over public HTTPS. It does NOT change Pages settings,
environment protection rules or existing production workflows. If the github-pages
environment disallows the staging branch, that exact permission is a blocker;
never work around it by changing the site's source branch or merging main.

A real Chromium release-panel smoke verifies startup from the actual public
Pages URL, observes the HTTPS staging identity request, blocks production API
requests and captures a screenshot. Campaign lifecycle UI tests are official
Flutter Chrome/Android integration tests against public HTTPS, separate from
that published release smoke; do not conflate the two types of evidence.

## Rollback and later production deploys

The archived original Pages tar is the complete rollback payload. If required,
review the saved proof and republish that complete original Pages artifact using
the Pages deployment action. Never publish a staging-only folder as the site.
This removes/rolls back only the added staging payload while preserving the
original production bytes. No database migration or Nginx rollback is involved.

The current main/scheduled heycar-pages workflow builds a whole site without
isletme-staging/. A later authorized production Pages deployment can remove this
staging folder. Review and explicitly address that implication before any merge;
this staging PR does not modify or trigger that production workflow.

CI follow-up: the first APK launch succeeded, then the runner lacked ripgrep.
The foreground assertion now uses Python (tested against both dumpsys variants)
and captures the actual APK screenshot before the assertion. Cached public
clients are reused only after lib/assets/pubspec/platform-preparation sources
AND compilation flags match; artifact build commit remains recorded. The UI
job locks staging backend writes, while distinct fixture accounts allow the
private/public UI regressions to run independently without sharing credentials.

Native launch follow-up: screenshot review found that disabled staging calling
services still led to call-permission onboarding. The entry gate now skips that
setup only for APP_ENV=staging; production/web permission behavior is unchanged.
Android UI Automator opens the real downloaded APK guest login form, checks
accessible phone/password fields plus the staging banner, and captures a
screenshot without entering credentials. The full application guest entry is
kept separate from the Flutter integration binding: that binding repeatedly
terminated the emulator, even after precompilation/Gradle cleanup and with no
host OOM event. Owner/Driver campaign widgets retain their real Flutter native
integration tests; neither guest nor campaign validation is inferred from API
responses. Native binaries are compiled before AVD startup; a stale fixture/API/
source context is rejected. Runner memory diagnostics contain no credentials.
