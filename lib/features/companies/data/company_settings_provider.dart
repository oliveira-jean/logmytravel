import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../profile/data/profile_repo_provider.dart';

/// Pode editar Data/Hora?
/// - Individual: sempre true
/// - Corporate: depende de companies/{companyId}.allowEditTripDateTime
final canEditTripDateTimeProvider = FutureProvider<bool>((ref) async {
  // myProfileProvider é um StreamProvider no seu projeto.
  // Para pegar o valor atual, usamos .future
  final snap = await ref.watch(myProfileProvider.future);
  final data = snap.data() as Map<String, dynamic>?;

  if (data == null) return true; // fallback: não trava

  final accountType = (data['accountType'] ?? 'individual').toString();
  if (accountType == 'individual') return true;

  final companyId = (data['companyId'] ?? '').toString();
  if (companyId.isEmpty) return false;

  final cSnap = await FirebaseFirestore.instance
      .collection('companies')
      .doc(companyId)
      .get();

  final cData = cSnap.data();
  if (cData == null) return false;

  return (cData['allowEditTripDateTime'] == true);
});
