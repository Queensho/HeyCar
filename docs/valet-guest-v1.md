# CepQontag Vale Misafir — V1 implementation contract

## Product goal
An unknown customer can scan the business's NFC/QR sign, register as a **guest**, see the existing valet session on the familiar CepQontag owner home, request vehicle retrieval, and confirm handover. After **verified delivery**, send a transactional delivery SMS. Invite the guest to create a free account only when lawful marketing permission exists. The valet may hand over an **unactivated** CepQontag vehicle QR label. Activation must be explicitly confirmed by the customer.

## Trust boundaries and order
1. Staff/business accepts a car in the **existing** valet_sessions flow. A guest visit links to this session, not a second independent valet state machine.
2. Public business NFC/QR opens the guest introduction page. **Do not** expose an active session based on plate alone. A per-visit high-entropy, single-use invitation from authorized staff is required to bind the visit.
3. Collect full name, plate, phone. Verify phone by OTP using an actual SMS provider with server-side TTL, attempt limits, rate limits, and replay protection. No guest status or vehicle actions until OTP and visit invitation are both verified.
4. Issue a short-lived, revocable, hashed guest bearer token scoped to exactly one valet session. Guest status responses must exclude key location, parking slot, staff details, other customers, and delivery code hashes.
5. Guest 'Aracımı Çağır' uses the existing requested -> retrieving -> ready -> delivered valet transition rules, idempotency and dispatch queue. Staff completes delivery with the existing verified delivery code. Guest cannot set delivered directly.
6. After a successful **ready -> delivered** transaction, enqueue a **single** transactional delivery notification. Use a durable outbox with idempotency keyed by session ID + event; don't send inside the database transaction. An optional account-creation invitation is a **separate** communication requiring appropriate consent/legal review, not an automatic marketing SMS.
7. Valet may record a physical QR label code when handing it to the customer. Do not bind it to a vehicle or claim ownership automatically. A verified account holder must activate it through the existing secure activation flow.
8. Guest token expires after delivery (allow a short read-only receipt grace period) and is revocable. Data retention, access control, KVKK notice, IYS/consent and audit logging are required before launch.

## V1 screens
- Business NFC/QR: landing with business name, privacy notice and 'Misafir olarak devam et'.
- Guest registration: name, plate, phone, consent **separately** from terms and privacy acknowledgement.
- OTP verification and secure valet visit matching.
- Owner home (guest mode): a single active vehicle card with valet status and 'Aracımı Çağır'; no unrelated account data.
- Delivery receipt: 'Aracınız başarıyla teslim edildi', optional QR label instructions, and voluntary 'Ücretsiz Hesap Oluştur'.

## Delivery safety gate
This PR is **schema and product/security contract only**. The feature remains **disabled** until guest API, SMS OTP provider, frontend, staff-issued invitation, consent handling, notification outbox, end-to-end tests, and deployment migrations are implemented and reviewed. Existing valet and owner routes must remain unchanged. No SMS is sent by this foundation.
