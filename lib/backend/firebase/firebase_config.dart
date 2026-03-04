import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

Future initFirebase() async {
  if (kIsWeb) {
    await Firebase.initializeApp(
        options: const FirebaseOptions(
            apiKey: "AIzaSyB7hpucMa-mSk6Bp9_OOt_1BFaO7E7HPTw",
            authDomain: "linkedup-c3e29.firebaseapp.com",
            projectId: "linkedup-c3e29",
            storageBucket: "linkedup-c3e29.firebasestorage.app",
            messagingSenderId: "548534727055",
            appId: "1:548534727055:web:d770e39d4c066094bb5bfa",
            measurementId: "G-LRGXVB1ZKH"));
  } else {
    await Firebase.initializeApp();
  }
}
