# Firestore rules for public Demo and Class Request counts

Publish this change in the **Rules** tab of the Firestore database used by the app
(`ai-studio-4f9c3b89-deb9-417f-9fa3-d37237f1fe74`). Keep the rest of your
existing rules. These snippets go **inside** `match /databases/{database}/documents`.

Add this new match block. Public documents contain only a display name, response
status, and IDs. The email and phone remain in private `registrations`.

```firestore
match /community_responses/{listingId}/members/{userId} {
  allow read: if true;

  function validMember() {
    let d = request.resource.data;
    let r = getAfter(
      /databases/$(database)/documents/registrations/$(d.responseId)
    );
    return isValidId(listingId)
      && isValidId(userId)
      && d.keys().hasOnly([
        'listingId', 'responseId', 'userId', 'userName', 'status'
      ])
      && d.keys().hasAll([
        'listingId', 'responseId', 'userId', 'userName', 'status'
      ])
      && d.listingId == listingId
      && d.userId == userId
      && d.responseId is string
      && d.responseId == 'response_' + listingId + '_' + userId
      && isValidId(d.responseId)
      && d.userName is string
      && d.userName.size() >= 1
      && d.userName.size() <= 100
      && !d.userName.matches('.*@.*')
      && d.status in ['interested', 'master_ready', 'vote_0']
      && r.data.listingId == listingId
      && r.data.userId == userId
      && r.data.status == d.status;
  }

  allow create, update: if isSignedIn()
    && (
      request.auth.uid == userId ||
      get(/databases/$(database)/documents/listings/$(listingId))
        .data.creatorId == request.auth.uid
    )
    && validMember();
  allow delete: if isSignedIn()
    && (
      request.auth.uid == userId ||
      get(/databases/$(database)/documents/listings/$(listingId))
        .data.creatorId == request.auth.uid
    );
}
```

In your **existing** `match /registrations/{registrationId}` block, add this
single `allow get` statement; do not remove your existing `allow read` or write
rules. It gives a participant access to contact details for the same post.
A guest or unrelated signed-in user can only read the public names.

```firestore
allow get: if isSignedIn()
  && exists(
    /databases/$(database)/documents/community_responses/$(resource.data.listingId)/members/$(request.auth.uid)
  );
```

The creator can already read the private registrations under your existing
owner rule. Older response names are copied to the public roster when the
creator opens that Demo or Request after these rules are published.
