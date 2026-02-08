import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/firebase/firestore_providers.dart';
import '../../auth/data/auth_providers.dart';
import '../../companies/data/company_codes_providers.dart';

class OnboardingModePage extends ConsumerStatefulWidget {
  const OnboardingModePage({super.key});

  @override
  ConsumerState<OnboardingModePage> createState() => _OnboardingModePageState();
}

class _OnboardingModePageState extends ConsumerState<OnboardingModePage> {
  bool _loading = false;
  String? _err;

  final _nameCtrl = TextEditingController();
  final _companyNameCtrl = TextEditingController();
  final _companyCodeCtrl = TextEditingController();
  final _codeCtrl = TextEditingController();

  // Corporate: owner cria empresa, member entra por código
  bool _corporateJoinByCode = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _codeCtrl.dispose();
    _companyNameCtrl.dispose();
    _companyCodeCtrl.dispose();
    super.dispose();
  }

  Future<void> _saveIndividual() async {
    await _saveProfileIndividual();
  }

  Future<void> _saveCorporate() async {
    if (_corporateJoinByCode) {
      final code = _companyCodeCtrl.text.trim().toUpperCase();
      if (code.isEmpty) {
        setState(() => _err = 'Informe o Company Code.');
        return;
      }
      await _saveProfileCorporateJoin(code: code);
      return;
    }

    final companyName = _companyNameCtrl.text.trim();
    if (companyName.isEmpty) {
      setState(() => _err = 'Informe o nome da empresa.');
      return;
    }
    await _saveProfileCorporateOwner(companyName: companyName);
  }

  Future<void> _joinByCode() async {
    final code = _codeCtrl.text.trim();
    if (code.isEmpty) {
      setState(() => _err = 'Informe o código da empresa.');
      return;
    }

    setState(() {
      _loading = true;
      _err = null;
    });

    try {
      final repo = ref.read(companyCodesRepoProvider);
      await repo.joinCompanyByCode(
        codeRaw: code,
        displayName: _nameCtrl.text.trim(),
      );

      // redirect automático pelo router (profile agora existe)
    } catch (e) {
      setState(() => _err = 'Falha ao entrar: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ===========================
  // Helpers: Company Code
  // ===========================
  String _makeCompanyCode() {
    // Code curto estilo SaaS: LMT-7Q2K
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'; // sem I/O/0/1
    final r = Random.secure();

    String part(int len) =>
        List.generate(len, (_) => chars[r.nextInt(chars.length)]).join();

    return 'LMT-${part(4)}';
  }

  Future<Map<String, String>> _createCompanyWithUniqueCode({
    required FirebaseFirestore fs,
    required String uid,
    required String companyName,
  }) async {
    // Tenta até 8 vezes gerar um código único
    for (int attempt = 0; attempt < 8; attempt++) {
      final code = _makeCompanyCode();

      // companyId separado do code (melhor para futuro). code aponta para companyId
      final companyRef = fs.collection('companies').doc(); // auto-id
      final codeRef = fs.collection('company_codes').doc(code);

      try {
        await fs.runTransaction((tx) async {
          final codeSnap = await tx.get(codeRef);
          if (codeSnap.exists) {
            throw Exception('CODE_EXISTS');
          }

          // Cria companies/{companyId}
          tx.set(companyRef, {
            'name': companyName,
            'ownerUid': uid,
            'companyCode': code,
            'allowEditTripDateTime': true, // ✅ default corporativo
            //'allowEditTripDateTime': false, // ✅ default corporativo
            'createdAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));

          // Cria company_codes/{code} -> companyId
          tx.set(codeRef, {
            'companyId': companyRef.id,
            'ownerUid': uid,
            'createdAt': FieldValue.serverTimestamp(),
          });
        });

        return {'companyId': companyRef.id, 'companyCode': code};
      } catch (e) {
        final msg = e.toString();
        if (msg.contains('CODE_EXISTS')) {
          continue; // tenta outro
        }
        rethrow;
      }
    }

    throw Exception(
      'Não foi possível gerar Company Code único (tente novamente).',
    );
  }

  // ===========================
  // Save: Individual
  // ===========================
  Future<void> _saveProfileIndividual() async {
    setState(() {
      _loading = true;
      _err = null;
    });

    try {
      final auth = ref.read(firebaseAuthProvider);
      final fs = ref.read(firestoreProvider);
      final user = auth.currentUser;

      if (user == null) throw Exception('Usuário não autenticado.');

      final displayName = _nameCtrl.text.trim();
      final email = user.email ?? '';

      final userRef = fs.collection('users').doc(user.uid);

      final payload = <String, dynamic>{
        'email': email,
        'accountType': 'individual',
        'companyId': null,
        'role': 'owner',
        'createdAt': FieldValue.serverTimestamp(),
      };
      if (displayName.isNotEmpty) payload['displayName'] = displayName;

      await userRef.set(payload, SetOptions(merge: true));
    } catch (e) {
      setState(() => _err = 'Falha ao salvar perfil: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ===========================
  // Save: Corporate Owner
  // ===========================
  Future<void> _saveProfileCorporateOwner({required String companyName}) async {
    setState(() {
      _loading = true;
      _err = null;
    });

    try {
      final auth = ref.read(firebaseAuthProvider);
      final fs = ref.read(firestoreProvider);
      final user = auth.currentUser;

      if (user == null) throw Exception('Usuário não autenticado.');

      final displayName = _nameCtrl.text.trim();
      final email = user.email ?? '';

      // cria empresa + code único
      final created = await _createCompanyWithUniqueCode(
        fs: fs,
        uid: user.uid,
        companyName: companyName,
      );

      final companyId = created['companyId']!;
      final companyCode = created['companyCode']!;

      final userRef = fs.collection('users').doc(user.uid);

      final payload = <String, dynamic>{
        'email': email,
        'accountType': 'corporate',
        'companyId': companyId,
        'role': 'owner',
        'createdAt': FieldValue.serverTimestamp(),
      };
      if (displayName.isNotEmpty) payload['displayName'] = displayName;

      await userRef.set(payload, SetOptions(merge: true));

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Empresa criada ✅ Company Code: $companyCode')),
      );
    } catch (e) {
      setState(() => _err = 'Falha ao salvar perfil: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ===========================
  // Save: Corporate Join (Member)
  // ===========================
  Future<void> _saveProfileCorporateJoin({required String code}) async {
    setState(() {
      _loading = true;
      _err = null;
    });

    try {
      final auth = ref.read(firebaseAuthProvider);
      final fs = ref.read(firestoreProvider);
      final user = auth.currentUser;

      if (user == null) throw Exception('Usuário não autenticado.');

      final displayName = _nameCtrl.text.trim();
      final email = user.email ?? '';

      final codeRef = fs.collection('company_codes').doc(code);
      final codeSnap = await codeRef.get();

      if (!codeSnap.exists) {
        throw Exception('Company Code inválido.');
      }

      final data = codeSnap.data() as Map<String, dynamic>;
      final companyId = (data['companyId'] ?? '').toString();
      if (companyId.isEmpty) {
        throw Exception('Company Code inválido (sem companyId).');
      }

      final userRef = fs.collection('users').doc(user.uid);

      final payload = <String, dynamic>{
        'email': email,
        'accountType': 'corporate',
        'companyId': companyId,
        'role': 'member',
        'createdAt': FieldValue.serverTimestamp(),
      };
      if (displayName.isNotEmpty) payload['displayName'] = displayName;

      await userRef.set(payload, SetOptions(merge: true));

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Entrou na empresa ✅')));
    } catch (e) {
      setState(() => _err = 'Falha ao salvar perfil: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final err = _err;

    return Scaffold(
      appBar: AppBar(title: const Text('Configurar conta')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            const Text(
              'Como você quer usar o Log My Travel?',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 16),

            TextField(
              controller: _nameCtrl,
              decoration: const InputDecoration(
                labelText: 'Seu nome (opcional)',
              ),
            ),
            const SizedBox(height: 16),

            if (err != null) ...[
              Text(err, style: const TextStyle(color: Colors.red)),
              const SizedBox(height: 12),
            ],

            // INDIVIDUAL
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '👤 Uso pessoal',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Para registrar viagens do seu próprio veículo (com anúncios no plano grátis).',
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: _loading ? null : _saveIndividual,
                      child: Text(
                        _loading ? 'Salvando...' : 'Continuar como Individual',
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 12),

            // CORPORATE
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '🏢 Uso empresarial',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Para empresa com frota, usuários e painel administrativo.',
                    ),
                    const SizedBox(height: 12),

                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text(
                        'Entrar com Company Code (funcionário)',
                      ),
                      value: _corporateJoinByCode,
                      onChanged: _loading
                          ? null
                          : (v) => setState(() {
                              _corporateJoinByCode = v;
                              _err = null;
                            }),
                    ),

                    if (_corporateJoinByCode) ...[
                      TextField(
                        controller: _companyCodeCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Company Code (ex: LMT-7Q2K)',
                        ),
                      ),
                    ] else ...[
                      TextField(
                        controller: _companyNameCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Nome da empresa',
                        ),
                      ),
                    ],

                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: _loading ? null : _saveCorporate,
                      child: Text(
                        _loading ? 'Salvando...' : 'Continuar como Corporate',
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),

            // JOIN BY CODE
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '🔑 Entrar em empresa existente',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Digite o código fornecido pelo gestor (owner).',
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _codeCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Código da empresa (ex: LMT-ABC123)',
                      ),
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: _loading ? null : _joinByCode,
                      child: Text(
                        _loading ? 'Entrando...' : 'Entrar com código',
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
