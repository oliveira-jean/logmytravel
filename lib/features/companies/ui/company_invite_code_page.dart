import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/firebase/firestore_providers.dart';
import '../../profile/data/profile_repo_provider.dart';
import '../data/company_codes_providers.dart';

class CompanyInviteCodePage extends ConsumerStatefulWidget {
  const CompanyInviteCodePage({super.key});

  @override
  ConsumerState<CompanyInviteCodePage> createState() =>
      _CompanyInviteCodePageState();
}

class _CompanyInviteCodePageState extends ConsumerState<CompanyInviteCodePage> {
  bool _loading = false;
  String? _err;

  Future<Map<String, dynamic>> _loadCompany() async {
    final profileSnap = await ref.read(myProfileProvider.future);
    final p = profileSnap.data() as Map<String, dynamic>? ?? {};
    final accountType = (p['accountType'] ?? 'individual').toString();
    final role = (p['role'] ?? 'member').toString();
    final companyId = (p['companyId'] ?? '').toString();

    if (accountType != 'corporate' || role != 'owner' || companyId.isEmpty) {
      throw Exception('Acesso restrito ao owner corporate.');
    }

    final fs = ref.read(firestoreProvider);
    final cSnap = await fs.collection('companies').doc(companyId).get();
    final c = cSnap.data() ?? {};

    return {
      'companyId': companyId,
      'companyName': (c['name'] ?? 'Empresa').toString(),
      'inviteCode': (c['inviteCode'] ?? '').toString(),
    };
  }

  Stream<DocumentSnapshot<Map<String, dynamic>>> _codeDocStream(String code) {
    final fs = ref.read(firestoreProvider);
    return fs.collection('company_codes').doc(code).snapshots();
  }

  Future<void> _generateNew(String companyId, String companyName) async {
    setState(() {
      _loading = true;
      _err = null;
    });

    try {
      final repo = ref.read(companyCodesRepoProvider);
      await repo.generateNewInviteCode(
        companyId: companyId,
        companyName: companyName,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Novo código gerado ✅')));
    } catch (e) {
      setState(() => _err = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _toggleActive(String code, bool active) async {
    setState(() {
      _loading = true;
      _err = null;
    });

    try {
      final repo = ref.read(companyCodesRepoProvider);
      await repo.setInviteCodeActive(code: code, active: active);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(active ? 'Código ativado ✅' : 'Código desativado 🔒'),
        ),
      );
    } catch (e) {
      setState(() => _err = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Código da empresa')),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _loadCompany(),
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(child: Text('Erro: ${snap.error}'));
          }

          final data = snap.data!;
          final companyId = data['companyId'] as String;
          final companyName = data['companyName'] as String;
          final inviteCode = data['inviteCode'] as String;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        companyName,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'CompanyId: $companyId',
                        style: const TextStyle(fontSize: 12),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Use este código para motoristas entrarem na empresa.',
                      ),
                      const SizedBox(height: 12),

                      if (_err != null) ...[
                        Text(_err!, style: const TextStyle(color: Colors.red)),
                        const SizedBox(height: 10),
                      ],

                      if (inviteCode.isEmpty) ...[
                        ElevatedButton.icon(
                          onPressed: _loading
                              ? null
                              : () => _generateNew(companyId, companyName),
                          icon: const Icon(Icons.qr_code),
                          label: Text(_loading ? 'Gerando...' : 'Gerar código'),
                        ),
                      ] else ...[
                        Text(
                          inviteCode,
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 10),

                        StreamBuilder(
                          stream: _codeDocStream(inviteCode),
                          builder: (context, s) {
                            if (!s.hasData) {
                              return const LinearProgressIndicator();
                            }
                            final cd = s.data!.data() ?? {};
                            final active = cd['active'] == true;

                            return SwitchListTile(
                              contentPadding: EdgeInsets.zero,
                              value: active,
                              title: const Text('Ativo'),
                              subtitle: Text(
                                active
                                    ? 'Motoristas podem entrar com este código'
                                    : 'Código bloqueado (ninguém entra)',
                              ),
                              onChanged: _loading
                                  ? null
                                  : (v) => _toggleActive(inviteCode, v),
                            );
                          },
                        ),

                        const SizedBox(height: 8),
                        OutlinedButton.icon(
                          onPressed: _loading
                              ? null
                              : () => _generateNew(companyId, companyName),
                          icon: const Icon(Icons.refresh),
                          label: Text(
                            _loading ? 'Gerando...' : 'Gerar novo código',
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
