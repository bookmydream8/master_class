# Master Class Cloud Functions

These functions send fee reminders, class announcements, interest alerts, and event reminders. The app still records class reminders in each learner's in-app inbox (`profiles/{uid}/notifications`) even before the functions are deployed. Push delivery needs Firebase Cloud Messaging.

## What you deploy

- `feeReminders` runs every day at 09:00 UTC. For each class fee that is still pending, it notifies the enrolled learner on the enrolled date and again 3 days later. That 3-day gap matches `feeReminderAfterDue` in `lib/notification_inbox.dart`.
- `announce` runs when a master creates `listings/{listingId}/announcements/{id}` and pushes the message to the enrolled learners (or one batch, when `batchId` is set).
- `interestNotice` runs when a learner creates `listings/{listingId}/interests/{uid}`. It writes an inbox entry for the class master and sends an FCM push to the master's saved device tokens.
- `eventReminders` runs every day at 03:30 UTC, which is 09:00 IST. It finds events whose `start_date` is tomorrow, writes one inbox entry per matching user, and sends one FCM message to the topic `city_<slug>` (for example `city_bangalore`). A user matches when `profiles/{uid}.city` or `preferredEventCity` equals the event city. The app subscribes the device to those topics on launch, sign-in, and when the city changes. A marker at `eventReminders/{listingId}_{yyyy-mm-dd}` stops a second run from sending the same reminder. Demo listings are skipped.

## One-time setup

1. Install the Firebase CLI and sign in with the account that owns the Firebase project: `npm install -g firebase-tools` then `firebase login`.
2. From the repository root, link the project: `firebase use --add` and pick the same project the Flutter app uses (`google-services.json` / `GoogleService-Info.plist`).
3. In the Firebase console, enable Cloud Messaging. No extra API key is required beyond the Firebase project the app already uses.
4. Android already applies the Google services plugin. iOS needs the `GoogleService-Info.plist` you download from the same project, and Push Notifications plus Background Modes → Remote notifications turned on in Xcode.
5. The app asks for notification permission and stores the device token on `profiles/{uid}.fcmTokens`. It also subscribes the device to `city_<slug>` for the profile city and the event city.
6. Profile photos upload to Cloud Storage at `profile_photos/{uid}/avatar.jpg`. Enable Storage in the Firebase console for the same project if it is not already on. The Storage rules are in `storage.rules`.

## Deploy the security rules

Firestore rules live in `firestore.rules`. Storage rules live in `storage.rules`. `firebase.json` points at both. Publishing them does not change the Flutter app. Firestore rules cover listings, profiles (including an immutable `mcId` and `pictureUrl`), the MC ID counter, enrolments, attendance, fees, reviews, batches, announcements, class interests, private master contact (`listings_contact`), and the community collections. A learner can create only `listings/{id}/interests/{their uid}`. The master can read interests for their class. Phone, email, and UPI on `listings_contact` are readable by the master, by a learner who has recorded interest, and by an enrolled learner.

From the repository root, after `firebase login` and `firebase use --add`:

```bash
firebase deploy --only firestore:rules
firebase deploy --only storage
```

Check the rules locally first, from `test/firestore`:

```bash
npm install
npm test
```

## Deploy the functions

```bash
cd functions
npm install
cd ..
firebase deploy --only functions
```

The first deploy asks you to enable the required Google APIs (Cloud Functions, Cloud Build, Artifact Registry, Cloud Scheduler). Confirm those prompts. After it finishes, fee reminders and event reminders run on their schedules, announcements push when a master posts one, and a new class interest notifies the master.

Deploy Storage together with the functions if profile photos are new for this project:

```bash
firebase deploy --only functions,storage,firestore:rules
```

## Firestore your rules should allow

Do not change production rules until you have reviewed them. The app writes:

- `profiles/{uid}` fields `upiId`, `role`, `topicInterests`, `fcmTokens`, `pictureUrl`, `city`, `preferredEventCity`
- `listings/{id}/interests/{uid}` with the learner name, MC ID, contact, and timestamp
- `listings_contact/{id}` with the master's phone, email, and UPI ID (not on the public listing)
- `profiles/{uid}/notifications/{id}` for the inbox
- `profiles/{uid}/saved/{listingId}` for the wishlist
- `profiles/{uid}/receivedReviews/{id}` for reviews of a master
- `listings/{id}/reviews/{uid}`
- `listings/{id}/batches/{batchId}`
- `listings/{id}/announcements/{id}`
- fee fields `utr`, `utrStatus`, `claimedAmount` on `listings/{id}/fees/{id}`
- `batchId` on an attendee inside `listings/{id}/enrollments/{mcId}`

Learners should read announcements and their own inbox. Only the class master should create batches and announcements. Fee UTR submissions should be writable by the enrolled learner; marking the fee paid stays with the master.
