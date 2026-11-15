# Master Class Cloud Functions

These functions send fee reminders and class announcements. The app still records the same messages in each learner's in-app inbox (`profiles/{uid}/notifications`) even before the functions are deployed. Push delivery needs Firebase Cloud Messaging.

## What you deploy

- `feeReminders` runs every day at 09:00 UTC. For each class fee that is still pending, it notifies the enrolled learner on the enrolled date and again 3 days later. That 3-day gap matches `feeReminderAfterDue` in `lib/notification_inbox.dart`.
- `announce` runs when a master creates `listings/{listingId}/announcements/{id}` and pushes the message to the enrolled learners (or one batch, when `batchId` is set).

## One-time setup

1. Install the Firebase CLI and sign in with the account that owns the Firebase project: `npm install -g firebase-tools` then `firebase login`.
2. From the repository root, link the project: `firebase use --add` and pick the same project the Flutter app uses (`google-services.json` / `GoogleService-Info.plist`).
3. In the Firebase console, enable Cloud Messaging. No extra API key is required beyond the Firebase project the app already uses.
4. Android already applies the Google services plugin. iOS needs the `GoogleService-Info.plist` you download from the same project, and Push Notifications plus Background Modes → Remote notifications turned on in Xcode.
5. The app asks for notification permission and stores the device token on `profiles/{uid}.fcmTokens`.

## Deploy the security rules

The rules live in `firestore.rules` and `firebase.json` points at that file. They cover listings, profiles (including an immutable `mcId`), the MC ID counter, enrolments, attendance, fees, reviews, batches, announcements, and the community collections. Publishing them does not change the Flutter app.

From the repository root, after `firebase login` and `firebase use --add`:

```bash
firebase deploy --only firestore:rules
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

The first deploy asks you to enable the required Google APIs (Cloud Functions, Cloud Build, Artifact Registry, Cloud Scheduler). Confirm those prompts. After it finishes, fee reminders run on the schedule and announcements push as soon as a master posts one.

## Firestore your rules should allow

Do not change production rules until you have reviewed them. The app writes:

- `profiles/{uid}` fields `upiId`, `role`, `topicInterests`, `fcmTokens`
- `profiles/{uid}/notifications/{id}` for the inbox
- `profiles/{uid}/saved/{listingId}` for the wishlist
- `profiles/{uid}/receivedReviews/{id}` for reviews of a master
- `listings/{id}/reviews/{uid}`
- `listings/{id}/batches/{batchId}`
- `listings/{id}/announcements/{id}`
- fee fields `utr`, `utrStatus`, `claimedAmount` on `listings/{id}/fees/{id}`
- `batchId` on an attendee inside `listings/{id}/enrollments/{mcId}`

Learners should read announcements and their own inbox. Only the class master should create batches and announcements. Fee UTR submissions should be writable by the enrolled learner; marking the fee paid stays with the master.
