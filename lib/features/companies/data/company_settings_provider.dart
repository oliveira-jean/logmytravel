import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Stream realtime: muda instantaneamente quando o gestor alterar
/// companies/{companyId}.allowEditTripDateTime
///
/// Regras:
/// - Individual: true
/// - Corporate: companies/{companyId}.allowEditTripDateTime
final canEditTripDateTimeProvider = StreamProvider<bool>((ref) async* {
  final auth = FirebaseAuth.instance;

  // 1) Escuta login/logout
  await for (final user in auth.authStateChanges()) {
    if (user == null) {
      // Sem login: por segurança, bloqueia edição (ou true, se preferir)
      yield false;
      continue;
    }

    final userDoc = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid);

    // 2) Escuta perfil do usuário (users/{uid})
    await for (final userSnap in userDoc.snapshots()) {
      final data = userSnap.data();
      if (data == null) {
        yield true; // fallback: não trava
        continue;
      }

      final accountType = (data['accountType'] ?? 'individual').toString();

      // Individual: sempre editável
      if (accountType == 'individual') {
        yield true;
        continue;
      }

      // Corporate: precisa companyId
      final companyId = (data['companyId'] ?? '').toString();
      if (companyId.isEmpty) {
        yield false;
        continue;
      }

      final companyDoc = FirebaseFirestore.instance
          .collection('companies')
          .doc(companyId);

      // 3) Escuta empresa (companies/{companyId})
      await for (final cSnap in companyDoc.snapshots()) {
        final cData = cSnap.data();
        final allow = (cData != null && cData['allowEditTripDateTime'] == true);
        yield allow;
      }
    }
  }
});
