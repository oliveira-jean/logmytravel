import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/firebase/firestore_providers.dart';
import '../../profile/data/profile_repo_provider.dart';

/// Lista em realtime todos usuários da mesma empresa.
/// Apenas para corporate (owner vai usar na UI).
final companyUsersStreamProvider =
    StreamProvider<QuerySnapshot<Map<String, dynamic>>>((ref) {
      final fs = ref.read(firestoreProvider);
      final profileAsync = ref.watch(myProfileProvider);

      return profileAsync.when(
        loading: () => const Stream.empty(),
        error: (_, __) => const Stream.empty(),
        data: (snap) {
          final p = snap.data() as Map<String, dynamic>? ?? {};
          final accountType = (p['accountType'] ?? 'individual').toString();
          final companyId = (p['companyId'] ?? '').toString();

          if (accountType != 'corporate' || companyId.isEmpty) {
            return const Stream.empty();
          }

          return fs
              .collection('users')
              .where('companyId', isEqualTo: companyId)
              .orderBy('createdAt', descending: false)
              .snapshots();
        },
      );
    });
