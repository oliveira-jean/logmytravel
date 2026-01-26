import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/firebase/firestore_providers.dart';
import '../../auth/data/auth_providers.dart';

/// Stream do documento users/{uid}.
/// Retorna null se não existir.
final userProfileDocProvider =
    StreamProvider<DocumentSnapshot<Map<String, dynamic>>?>((ref) {
      final auth = ref.watch(firebaseAuthProvider);
      final fs = ref.watch(firestoreProvider);

      final user = auth.currentUser;
      if (user == null) {
        return Stream.value(null);
      }

      final docRef = fs.collection('users').doc(user.uid);
      return docRef.snapshots().map((snap) => snap);
    });
