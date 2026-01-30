import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// ===============================
/// A2.5 — Settings da empresa (Corporate)
/// companies/{companyId}.allowEditTripDateTime
/// ===============================

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

/// Escuta o documento inteiro da empresa (para mostrar nome + settings)
final companySettingsDocProvider =
    StreamProvider<DocumentSnapshot<Map<String, dynamic>>>((ref) async* {
      final auth = FirebaseAuth.instance;

      await for (final user in auth.authStateChanges()) {
        if (user == null) {
          yield* const Stream.empty();
          continue;
        }

        // lê perfil para obter companyId
        final userDoc = FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid);

        await for (final userSnap in userDoc.snapshots()) {
          final data = userSnap.data();
          if (data == null) {
            yield* const Stream.empty();
            continue;
          }

          final accountType = (data['accountType'] ?? 'individual').toString();
          if (accountType != 'corporate') {
            yield* const Stream.empty();
            continue;
          }

          final companyId = (data['companyId'] ?? '').toString();
          if (companyId.isEmpty) {
            yield* const Stream.empty();
            continue;
          }

          final companyDoc = FirebaseFirestore.instance
              .collection('companies')
              .doc(companyId);

          yield* companyDoc.snapshots();
        }
      }
    });

class CompanySettingsRepo {
  CompanySettingsRepo({required FirebaseFirestore firestore}) : _fs = firestore;

  final FirebaseFirestore _fs;

  Future<void> setAllowEditTripDateTime({
    required String companyId,
    required bool allow,
  }) async {
    await _fs.collection('companies').doc(companyId).set({
      'allowEditTripDateTime': allow,
    }, SetOptions(merge: true));
  }
}

final companySettingsRepoProvider = Provider<CompanySettingsRepo>((ref) {
  return CompanySettingsRepo(firestore: FirebaseFirestore.instance);
});
