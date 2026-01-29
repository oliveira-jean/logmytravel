import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class VehiclesRepo {
  VehiclesRepo({
    required FirebaseFirestore firestore,
    required FirebaseAuth auth,
  }) : _fs = firestore,
       _auth = auth;

  final FirebaseFirestore _fs;
  final FirebaseAuth _auth;

  String _normalizePlate(String v) {
    return v.trim().toUpperCase().replaceAll(' ', '').replaceAll('-', '');
  }

  CollectionReference<Map<String, dynamic>> _collectionFor({
    required String accountType,
    required String? companyId,
  }) {
    final u = _auth.currentUser;
    if (u == null) throw Exception('Usuário não autenticado.');

    if (accountType == 'corporate') {
      if (companyId == null || companyId.isEmpty) {
        throw Exception('companyId ausente.');
      }
      return _fs.collection('companies').doc(companyId).collection('vehicles');
    }

    return _fs.collection('users').doc(u.uid).collection('vehicles');
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> listVehicles({
    required String accountType,
    required String? companyId,
  }) {
    // ✅ Query simples: evita index/ordenação no Firestore no começo do projeto
    // A ordenação a gente faz no client (UI).
    return _collectionFor(
      accountType: accountType,
      companyId: companyId,
    ).where('active', isEqualTo: true).snapshots();
  }

  Future<void> addVehicle({
    required String accountType,
    required String? companyId,
    required String model,
    required String plate,
  }) async {
    final col = _collectionFor(accountType: accountType, companyId: companyId);

    final m = model.trim();
    final p = _normalizePlate(plate);

    if (m.isEmpty) throw Exception('Informe o modelo.');
    if (p.isEmpty) throw Exception('Informe a placa.');

    // Evita duplicar placa (por conta/empresa)
    final dup = await col.where('plate', isEqualTo: p).limit(1).get();
    if (dup.docs.isNotEmpty) {
      throw Exception('Já existe um veículo com essa placa.');
    }

    await col.add({
      'model': m,
      'plate': p,
      'active': true,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }
}
