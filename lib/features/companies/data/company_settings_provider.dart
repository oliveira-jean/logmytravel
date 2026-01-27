import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/data/auth_providers.dart';
import '../../profile/data/profile_repo_provider.dart';

/// Retorna true se o usuário pode editar data/hora da trip.
/// - Individual: sempre true
/// - Corporate: depende de companies/{companyId}.allowEditTripDateTime
final allowEditTripDateTimeProvider = StreamProvider<bool>((ref) {
  final profileStream = ref.watch(myProfileProvider.stream);

  return profileStream.asyncMap((snap) async {
    final data = snap.data() as Map<String, dynamic>?;
    if (data == null) return true; // fallback permissivo no MVP

    final accountType = (data['accountType'] ?? 'individual').toString();
    if (accountType != 'corporate') return true;

    final companyId = data['companyId']?.toString();
    if (companyId == null || companyId.isEmpty) return false;

    final fs = ref.read(firebaseFirestoreProvider);
    final doc = await fs.collection('companies').doc(companyId).get();
    final m = doc.data() as Map<String, dynamic>?;

    if (m == null) return false;
    return (m['allowEditTripDateTime'] == true);
  }).asStream();
});
