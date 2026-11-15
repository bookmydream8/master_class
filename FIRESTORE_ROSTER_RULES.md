# Firestore rules for MC IDs, enrolment, attendance, and fees

Publish these in the **Rules** tab of the Firestore database used by the app
(`ai-studio-4f9c3b89-deb9-417f-9fa3-d37237f1fe74`). Keep your existing rules.
These blocks go **inside** `match /databases/{database}/documents`.

The app does not change production rules by itself.

Member IDs look like `MC100245`. `counters/memberId.next` is the last number
issued. A profile's `mcId` is written once and must not change.

```firestore
match /counters/memberId {
  allow read: if isSignedIn();
  allow create, update: if isSignedIn()
    && request.resource.data.next is int
    && request.resource.data.next > 100000
    && request.resource.data.next < 10000000
    && (!exists(/databases/$(database)/documents/counters/memberId)
        || request.resource.data.next == resource.data.next + 1);
}

match /profiles/{uid} {
  allow read: if isSignedIn() && request.auth.uid == uid;
  allow create, update: if isSignedIn()
    && request.auth.uid == uid
    && (!('mcId' in request.resource.data)
        || !exists(/databases/$(database)/documents/profiles/$(uid))
        || !('mcId' in resource.data)
        || resource.data.mcId == request.resource.data.mcId);
}
```

Enrolment, attendance, and fees live under the existing `listings` documents.
Only online and physical classes use them. One enrolment document per MC ID
holds that member's attendees. Attendance is one document per session date.
Fees are one document per attendee. `feePeriod` is `month` or `course` (there is no per-session fee). `unitAmount` is the monthly or course rate. For a monthly fee, total due is `unitAmount` times the months since `enrolledAt`. `amountPaid` can be less than the total, which is a partial payment. Pending is total minus paid.

```firestore
match /listings/{listingId}/enrollments/{mcId} {
  function ownsListing() {
    return isSignedIn()
      && get(/databases/$(database)/documents/listings/$(listingId)).data.creatorId
          == request.auth.uid;
  }
  allow read: if isSignedIn()
    && (ownsListing() || resource.data.userId == request.auth.uid);
  allow create, update: if isSignedIn()
    && request.resource.data.userId == request.auth.uid
    && request.resource.data.mcId == mcId
    && request.resource.data.attendees is list
    && request.resource.data.attendees.size() <= 12;
  allow delete: if isSignedIn()
    && (ownsListing() || resource.data.userId == request.auth.uid);
}

match /listings/{listingId}/attendance/{sessionDate} {
  function ownsListing() {
    return isSignedIn()
      && get(/databases/$(database)/documents/listings/$(listingId)).data.creatorId
          == request.auth.uid;
  }
  function isEnrolled() {
    return isSignedIn()
      && exists(/databases/$(database)/documents/listings/$(listingId)/enrollments/$(get(/databases/$(database)/documents/profiles/$(request.auth.uid)).data.mcId));
  }
  allow read: if ownsListing() || isEnrolled();
  allow create, update: if ownsListing();
}

match /listings/{listingId}/fees/{feeId} {
  function ownsListing() {
    return isSignedIn()
      && get(/databases/$(database)/documents/listings/$(listingId)).data.creatorId
          == request.auth.uid;
  }
  allow read: if isSignedIn()
    && (ownsListing() || resource.data.userId == request.auth.uid
        || resource.data.mcId == get(/databases/$(database)/documents/profiles/$(request.auth.uid)).data.mcId);
  allow create: if isSignedIn()
    && request.resource.data.mcId is string
    && (ownsListing()
        || request.resource.data.mcId == get(/databases/$(database)/documents/profiles/$(request.auth.uid)).data.mcId);
  allow update: if ownsListing();
}
```

`isSignedIn()` is the helper already used by the other rule notes in this repo:
`request.auth != null && request.auth.uid != null`.
