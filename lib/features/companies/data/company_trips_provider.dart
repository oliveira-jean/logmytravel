import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/firebase/firestore_providers.dart';
import '../../profile/data/profile_repo_provider.dart';

/// Stream realtime das viagens da empresa (corporate).
/// Permite filtrar por status.
final companyTripsStreamProvider =
    StreamProvider.family<QuerySnapshot<Map<String, dynamic>>, String>((
      ref,
      status,
    ) {
      // status: 'all'|'open'|'closed'
      final fs = ref.read(firestoreProvider);

      // Pega perfil do usuário (para obter companyId)
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

          Query<Map<String, dynamic>> q = fs
              .collection('trips')
              .where('ownerType', isEqualTo: 'corporate')
              .where('ownerId', isEqualTo: companyId)
              .orderBy('startAt', descending: true);

          if (status != 'all') {
            q = q.where('status', isEqualTo: status);
          }

          return q.snapshots();
        },
      );
    });
