import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class CompanyUsersRepo {
  CompanyUsersRepo({
    required FirebaseFirestore firestore,
    required FirebaseAuth auth,
  }) : _fs = firestore,
       _auth = auth;

  final FirebaseFirestore _fs;
  final FirebaseAuth _auth;

  Future<Map<String, dynamic>> _myProfile() async {
    final u = _auth.currentUser;
    if (u == null) throw Exception('Usuário não autenticado');

    final snap = await _fs.collection('users').doc(u.uid).get();
    final data = snap.data();
    if (data == null) throw Exception('Perfil não encontrado.');

    return <String, dynamic>{'uid': u.uid, ...data};
  }

  Future<void> _ensureOwner() async {
    final me = await _myProfile();
    final accountType = (me['accountType'] ?? '').toString();
    final role = (me['role'] ?? '').toString();
    final companyId = (me['companyId'] ?? '').toString();

    if (accountType != 'corporate' || role != 'owner' || companyId.isEmpty) {
      throw Exception('Acesso restrito ao owner corporate.');
    }
  }

  /// Owner altera role do usuário (por enquanto só member/owner).
  /// Regra: não permite alterar o próprio role aqui (evita travas).
  Future<void> setUserRole({
    required String targetUid,
    required String role,
  }) async {
    await _ensureOwner();
    final me = _auth.currentUser!;
    if (targetUid == me.uid) {
      throw Exception('Você não pode alterar seu próprio role aqui.');
    }

    if (role != 'member' && role != 'owner') {
      throw Exception('Role inválida.');
    }

    await _fs.collection('users').doc(targetUid).set({
      'role': role,
      'roleUpdatedAt': FieldValue.serverTimestamp(),
      'roleUpdatedBy': me.uid,
    }, SetOptions(merge: true));
  }

  /// Owner remove usuário da empresa (vira individual).
  /// Não permite remover o próprio owner.
  Future<void> removeUserFromCompany({required String targetUid}) async {
    await _ensureOwner();
    final me = _auth.currentUser!;
    if (targetUid == me.uid) {
      throw Exception('Você não pode remover a si mesmo.');
    }

    await _fs.collection('users').doc(targetUid).set({
      'accountType': 'individual',
      'companyId': null,
      'companyName': null,
      'role': 'member',
      'removedAt': FieldValue.serverTimestamp(),
      'removedBy': me.uid,
    }, SetOptions(merge: true));
  }
}
