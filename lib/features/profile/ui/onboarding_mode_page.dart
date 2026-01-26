import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/firebase/firestore_providers.dart';
import '../../auth/data/auth_providers.dart';

class OnboardingModePage extends ConsumerStatefulWidget {
  const OnboardingModePage({super.key});

  @override
  ConsumerState<OnboardingModePage> createState() => _OnboardingModePageState();
}

class _OnboardingModePageState extends ConsumerState<OnboardingModePage> {
  bool _loading = false;
  String? _err;

  final _nameCtrl = TextEditingController();
  final _companyCtrl = TextEditingController();

  @override
  void dispose() {
    _nameCtrl.dispose();
    _companyCtrl.dispose();
    super.dispose();
  }

  Future<void> _saveIndividual() async {
    await _saveProfile(accountType: 'individual');
  }

  Future<void> _saveCorporate() async {
    final companyName = _companyCtrl.text.trim();
    if (companyName.isEmpty) {
      setState(() => _err = 'Informe o nome da empresa.');
      return;
    }
    await _saveProfile(accountType: 'corporate', companyName: companyName);
  }

  Future<void> _saveProfile({
    required String accountType,
    String? companyName,
  }) async {
    setState(() {
      _loading = true;
      _err = null;
    });

    try {
      final auth = ref.read(firebaseAuthProvider);
      final fs = ref.read(firestoreProvider);
      final user = auth.currentUser;

      if (user == null) {
        throw Exception('Usuário não autenticado.');
      }

      final displayName = _nameCtrl.text.trim();
      final email = user.email ?? '';

      String? companyId;
      String role = 'owner';

      // Se corporate, cria empresa e vincula o usuário como owner
      if (accountType == 'corporate') {
        final companyRef = fs.collection('companies').doc(); // auto-id
        await companyRef.set({
          'name': companyName,
          'createdAt': FieldValue.serverTimestamp(),
          'ownerUid': user.uid,
        });
        companyId = companyRef.id;
      }

      final userRef = fs.collection('users').doc(user.uid);
      await userRef.set({
        'email': email,
        'displayName': displayName.isEmpty ? null : displayName,
        'accountType': accountType,
        'companyId': companyId,
        'role': role,
        'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // Redirect automático via router (porque o profile agora existe)
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
                    TextField(
                      controller: _companyCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Nome da empresa',
                      ),
                    ),
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
          ],
        ),
      ),
    );
  }
}
