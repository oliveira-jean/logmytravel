import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class CompanyCodesRepo {
  CompanyCodesRepo({
    required FirebaseFirestore firestore,
    required FirebaseAuth auth,
  }) : _fs = firestore,
       _auth = auth;

  final FirebaseFirestore _fs;
  final FirebaseAuth _auth;

  static const _alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'; // sem 0,O,1,I
  final _rng = Random();

  String _newCode() {
    // Ex: LMT-7F3K9Q
    String part(int n) => List.generate(
      n,
      (_) => _alphabet[_rng.nextInt(_alphabet.length)],
    ).join();
    return 'LMT-${part(6)}';
  }

  /// Owner gera um novo código e salva:
  /// - company_codes/{code}
  /// - companies/{companyId}.inviteCode = code
  Future<String> generateNewInviteCode({
    required String companyId,
    required String companyName,
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('Usuário não autenticado');

    // tenta algumas vezes para evitar colisão (quase impossível)
    for (int attempt = 0; attempt < 10; attempt++) {
      final code = _newCode();
      final codeRef = _fs.collection('company_codes').doc(code);

      final exists = await codeRef.get();
      if (exists.exists) continue;

      // cria o código
      await codeRef.set({
        'companyId': companyId,
        'companyName': companyName,
        'ownerUid': user.uid,
        'active': true,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // grava no doc da empresa (facilita leitura)
      await _fs.collection('companies').doc(companyId).set({
        'inviteCode': code,
      }, SetOptions(merge: true));

      return code;
    }

    throw Exception('Falha ao gerar código (tente novamente).');
  }

  Future<void> setInviteCodeActive({
    required String code,
    required bool active,
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('Usuário não autenticado');

    final ref = _fs.collection('company_codes').doc(code);
    await ref.set({'active': active}, SetOptions(merge: true));
  }

  /// Entra na empresa via código:
  /// - lê company_codes/{code}
  /// - valida active
  /// - atualiza users/{uid} com corporate/member + companyId
  Future<void> joinCompanyByCode({
    required String codeRaw,
    String? displayName,
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('Usuário não autenticado');

    final code = codeRaw.trim().toUpperCase();
    if (code.isEmpty) throw Exception('Informe o código.');

    final codeSnap = await _fs.collection('company_codes').doc(code).get();
    if (!codeSnap.exists) throw Exception('Código inválido.');

    final data = codeSnap.data() as Map<String, dynamic>;
    final active = data['active'] == true;
    if (!active) throw Exception('Código desativado.');

    final companyId = (data['companyId'] ?? '').toString();
    final companyName = (data['companyName'] ?? '').toString();

    if (companyId.isEmpty)
      throw Exception('Código malformado (sem companyId).');

    final email = user.email ?? '';

    await _fs.collection('users').doc(user.uid).set({
      'email': email,
      'displayName': (displayName ?? '').trim().isEmpty
          ? null
          : displayName!.trim(),
      'accountType': 'corporate',
      'companyId': companyId,
      'companyName': companyName.isEmpty ? null : companyName,
      'role': 'member',
      'joinedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}
