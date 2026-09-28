import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';

/// The Firestore database provisioned for this Firebase project.
const firestoreDatabaseId = 'ai-studio-4f9c3b89-deb9-417f-9fa3-d37237f1fe74';

FirebaseFirestore get firestore => FirebaseFirestore.instanceFor(
  app: Firebase.app(),
  databaseId: firestoreDatabaseId,
);