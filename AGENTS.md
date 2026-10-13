# Master Class Flutter project

- The active app starts in `lib/main.dart`, uses `MasterClassApp` from `lib/master_class_app.dart`, and displays `MasterClassBoard` from `lib/madhura_board.dart`.
- Keep listing categories and category IDs together in `lib/madhura_board.dart`; the post form in `lib/madhura_post.dart` reads those lists. Add new categories to both maps so posting and browsing agree.
- Signed-in user's city preferences are stored in their Firestore `profiles/{uid}` document. Physical/competition and Events use separate fields; online browsing shows all cities.
- Class images are cropped and stored as compact base64 in listing documents. Respect Firestore's document-size limit and preserve existing images when editing.
- Preserve existing Firestore schema compatibility (`type`, `listing_type`, and category IDs) and do not change production security rules implicitly.
- Verify Dart changes with `flutter analyze` and Android integration changes with a debug APK build. The user runs the app on their device from Android Studio.
- Do not overwrite unrelated working-tree changes or commit/push unless explicitly requested.