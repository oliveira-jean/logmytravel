import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../profile/data/profile_repo_provider.dart';
import '../data/vehicles_providers.dart';

class VehiclesPage extends ConsumerStatefulWidget {
  const VehiclesPage({super.key});

  @override
  ConsumerState<VehiclesPage> createState() => _VehiclesPageState();
}

class _VehiclesPageState extends ConsumerState<VehiclesPage> {
  Future<void> _openAddDialog({
    required String accountType,
    required String? companyId,
  }) async {
    final modelCtrl = TextEditingController();
    final plateCtrl = TextEditingController();

    String? err;
    bool loading = false;

    await showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialog) {
            Future<void> save() async {
              setDialog(() {
                err = null;
                loading = true;
              });

              try {
                await ref
                    .read(vehiclesRepoProvider)
                    .addVehicle(
                      accountType: accountType,
                      companyId: companyId,
                      model: modelCtrl.text,
                      plate: plateCtrl.text,
                    );
                if (!mounted) return;
                Navigator.of(ctx).pop();
              } catch (e) {
                setDialog(() {
                  err = e.toString();
                  loading = false;
                });
              }
            }

            return AlertDialog(
              title: const Text('Adicionar veículo'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: modelCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Modelo (ex: Voyage)',
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: plateCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Placa (ex: ABC1D23)',
                    ),
                  ),
                  if (err != null) ...[
                    const SizedBox(height: 10),
                    Text(err!, style: const TextStyle(color: Colors.red)),
                  ],
                ],
              ),
              actions: [
                TextButton(
                  onPressed: loading ? null : () => Navigator.of(ctx).pop(),
                  child: const Text('Cancelar'),
                ),
                ElevatedButton(
                  onPressed: loading ? null : save,
                  child: Text(loading ? 'Salvando...' : 'Salvar'),
                ),
              ],
            );
          },
        );
      },
    );

    modelCtrl.dispose();
    plateCtrl.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(myProfileProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Veículos')),
      body: profileAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Erro profile: $e')),
        data: (snap) {
          final data = snap.data() as Map<String, dynamic>? ?? {};
          final accountType = (data['accountType'] ?? 'individual').toString();
          final companyId = (data['companyId'] ?? '').toString();
          final role = (data['role'] ?? 'member').toString();

          final canManage = accountType == 'individual' || role == 'owner';

          final vehiclesStream = ref
              .read(vehiclesRepoProvider)
              .listVehicles(accountType: accountType, companyId: companyId);

          return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: vehiclesStream,
            builder: (context, s) {
              // ✅ Agora mostramos erro de permissão/index em vez de spinner infinito
              if (s.hasError) {
                return Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Erro ao carregar veículos',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        s.error.toString(),
                        style: const TextStyle(color: Colors.red),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Dica: isso normalmente é Firestore Rules (permission-denied) '
                        'ou índice do Firestore. Cole esse erro aqui que eu ajusto em 1 minuto.',
                      ),
                    ],
                  ),
                );
              }

              if (s.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              final docs = (s.data?.docs ?? []).toList();

              // ✅ Ordenação no client (evita index)
              docs.sort((a, b) {
                final am = (a.data()['model'] ?? '').toString();
                final bm = (b.data()['model'] ?? '').toString();
                return am.compareTo(bm);
              });

              return ListView(
                padding: const EdgeInsets.all(12),
                children: [
                  if (accountType == 'corporate')
                    Card(
                      child: ListTile(
                        leading: const Icon(Icons.business),
                        title: Text(
                          'Empresa: ${companyId.isEmpty ? '-' : companyId}',
                        ),
                        subtitle: Text('Perfil: $role'),
                      ),
                    ),
                  const SizedBox(height: 8),
                  if (!canManage)
                    const Card(
                      child: ListTile(
                        leading: Icon(Icons.lock),
                        title: Text(
                          'Apenas o gestor (owner) pode cadastrar veículos no corporate.',
                        ),
                      ),
                    ),
                  const SizedBox(height: 8),

                  if (docs.isEmpty)
                    const Card(
                      child: ListTile(
                        leading: Icon(Icons.info_outline),
                        title: Text('Nenhum veículo cadastrado ainda'),
                        subtitle: Text(
                          'Use o botão “Adicionar” para cadastrar.',
                        ),
                      ),
                    ),

                  for (final d in docs)
                    Card(
                      child: ListTile(
                        leading: const Icon(Icons.directions_car),
                        title: Text((d.data()['model'] ?? '').toString()),
                        subtitle: Text(
                          'Placa: ${(d.data()['plate'] ?? '').toString()}',
                        ),
                      ),
                    ),
                ],
              );
            },
          );
        },
      ),
      floatingActionButton: profileAsync.when(
        loading: () => null,
        error: (_, __) => null,
        data: (snap) {
          final data = snap.data() as Map<String, dynamic>? ?? {};
          final accountType = (data['accountType'] ?? 'individual').toString();
          final companyId = (data['companyId'] ?? '').toString();
          final role = (data['role'] ?? 'member').toString();

          final canManage = accountType == 'individual' || role == 'owner';
          if (!canManage) return null;

          return FloatingActionButton.extended(
            onPressed: () =>
                _openAddDialog(accountType: accountType, companyId: companyId),
            icon: const Icon(Icons.add),
            label: const Text('Adicionar'),
          );
        },
      ),
    );
  }
}
