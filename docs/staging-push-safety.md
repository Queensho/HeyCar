# Staging notification isolation

`server/external-services-policy.js` is the shared delivery policy for
`web-push-service.js` and `push-routes.js`. It is evaluated at send time.

External push delivery is disabled when **any** of these is true:

- `NODE_ENV=staging`
- `APP_ENV=staging`
- `STAGING_DISABLE_EXTERNAL_SERVICES` is `1`, `true`, `yes` or `on`.

Values ignore case and surrounding whitespace. A false/zero flag never overrides
an environment marked staging. The explicit true flag also acts as an opt-in
push kill switch outside staging. With no staging marker and no true flag,
production follows its existing delivery and invalid-token cleanup behavior.

The guard covers owner/driver sends, the `send` alias, native/web Firebase FCM,
direct `sendToken`, Firebase OAuth and direct Web Push. It is also checked after
asynchronous token lookups/OAuth and immediately before the delivery transports.
Staging sends return zero attempted/delivered with
`skipped: 'EXTERNAL_SERVICES_DISABLED'`. Direct `sendToken` retains its existing
boolean contract and returns false. No fake delivery success is reported.

Blocked sends do not query or mutate subscriptions/tokens and do not retire
records. Subscription/token registration and explicit user unsubscribe routes
are unchanged; no user data is deleted by enabling the guard. This policy
protects notification delivery in these modules, not every unrelated external
integration in the application.

Run `node server/tests/staging-push-safety.test.js` for the isolated mock tests,
`npm test --prefix server` for the existing backend regression suite, and
`npm run check --prefix server` for the existing syntax checks. All Firebase,
OAuth, Web Push and database operations in the new suite are mocks; actual
service credentials and network transports are never loaded.

No VPS service, PostgreSQL database, staging environment file or deployment is
changed by this repository patch. The protection takes effect after an approved
rollout of the updated backend code. Production deployment and PR merge are not
part of this change.
