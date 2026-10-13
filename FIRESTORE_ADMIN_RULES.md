# Admin post deletion setup

The app uses the Firestore database `ai-studio-4f9c3b89-deb9-417f-9fa3-d37237f1fe74`.
Its admin Delete button appears on class, Demo, and Request detail pages only when
`admins/{signed-in-user-UID}` exists. The button asks for confirmation and then
deletes the listing and its private `listings_contact` document, when present.

## 1. Publish the security rules

In the Firebase Console, open **Firestore Database → Rules** for this database.
Keep the other existing rules. Within `match /databases/{database}/documents`,
add this helper and match block:

```firestore
function isAdmin() {
  return request.auth != null
    && exists(/databases/$(database)/documents/admins/$(request.auth.uid));
}

match /admins/{adminUid} {
  allow get: if request.auth != null && request.auth.uid == adminUid;
  allow list, create, update, delete: if false;
}
```

In the **existing** `match /listings/{listingId}` block, change its delete
permission to include `isAdmin()`. For example:

```firestore
allow delete: if isAdmin() ||
  (request.auth != null && resource.data.creatorId == request.auth.uid);
```

In the **existing** `match /listings_contact/{listingId}` block, make the
same change to its delete permission:

```firestore
allow delete: if isAdmin() ||
  (request.auth != null && resource.data.creatorId == request.auth.uid);
```

Do not add a broad admin write rule. This role only needs deletion rights;
admin users cannot edit someone else's listing or grant themselves admin.
Publish the rules before testing the button.

## 2. Grant the first admin

Find the intended user's UID in **Firebase Authentication → Users**. In the
Firestore database above, create a document in collection `admins` whose
**document ID is that exact UID**. The document can contain a `createdAt`
timestamp and a note, but its fields do not grant access; its existence does.
Create this document using the Firebase Console or a trusted Admin SDK, not
from the app. Signing out and back in will refresh the detail page.

To revoke access, delete that `admins/{UID}` document in the Console.

## Data cleanup

Deleting a Firestore listing does not recursively delete nested `interests`,
`community_responses`, or `registrations`. They will no longer be shown in
the app, but a backend cleanup job is needed if those records must also be
removed for retention or privacy reasons. Do not grant the client broad
collection delete access just to clean these up.