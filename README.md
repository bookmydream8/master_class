# Master Class

Home has an Upcoming events link (next 10 days, plus the last few completed events). Online class posts expire within 31 days; the master sees the date and can renew, and the phone reminds them one day before. Physical posts can be an Academy with teachers, batches, student fees, and teacher salaries.

Cloud Functions for expiry reminders are in `functions/` and are ready to deploy later. They are not required while the project is off the Blaze plan, because the app schedules the reminder on the device. See `functions/README.md` before the first deploy:

```bash
firebase deploy --only functions,firestore:rules
```

# master_class_mc

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
# master_class
