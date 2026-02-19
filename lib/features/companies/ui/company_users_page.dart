import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../profile/data/profile_repo_provider.dart';
import '../data/company_users_provider.dart';
import '../data/company_users_providers.dart';

class CompanyUsersPage extends ConsumerWidget {
  const CompanyUsersPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(myProfileProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Usuários da empresa')),
      body: profileAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Erro profile: $e')),
        data: (snap) {
          final p = snap.data() as Map<String, dynamic>? ?? {};
          final accountType = (p['accountType'] ?? 'individual').toString();
          final role = (p['role'] ?? 'member').toString();

          if (accountType != 'corporate' || role != 'owner') {
            return const Center(
              child: Text('Acesso restrito ao owner corporate.'),
            );
          }

          final usersAsync = ref.watch(companyUsersStreamProvider);

          return usersAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Erro ao listar usuários: $e')),
            data: (qs) {
              final docs = qs.docs;
              if (docs.isEmpty) {
                return const Center(child: Text('Nenhum usuário encontrado.'));
              }

              return ListView.separated(
                padding: const EdgeInsets.all(12),
                itemCount: docs.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, i) {
                  final d = docs[i];
                  final u = d.data();
                  final uid = d.id;

                  final email = (u['email'] ?? '').toString();
                  final name = (u['displayName'] ?? '').toString();
                  final r = (u['role'] ?? 'member').toString();
                  final acc = (u['accountType'] ?? '').toString();

                  return Card(
                    child: ListTile(
                      leading: Icon(
                        r == 'owner' ? Icons.verified : Icons.person,
                      ),
                      title: Text(
                        name.isEmpty ? (email.isEmpty ? uid : email) : name,
                      ),
                      subtitle: Text('role: $r • $acc\nuid: $uid'),
                      trailing: PopupMenuButton<String>(
                        onSelected: (v) async {
                          try {
                            final repo = ref.read(companyUsersRepoProvider);

                            if (v == 'make_member') {
                              await repo.setUserRole(
                                targetUid: uid,
                                role: 'member',
                              );
                            } else if (v == 'make_owner') {
                              await repo.setUserRole(
                                targetUid: uid,
                                role: 'owner',
                              );
                            } else if (v == 'remove') {
                              final ok = await showDialog<bool>(
                                context: context,
                                builder: (_) => AlertDialog(
                                  title: const Text('Remover usuário'),
                                  content: const Text(
                                    'Este usuário deixará de pertencer à empresa e voltará para Individual.',
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.pop(context, false),
                                      child: const Text('Cancelar'),
                                    ),
                                    ElevatedButton(
                                      onPressed: () =>
                                          Navigator.pop(context, true),
                                      child: const Text('Remover'),
                                    ),
                                  ],
                                ),
                              );
                              if (ok == true) {
                                await repo.removeUserFromCompany(
                                  targetUid: uid,
                                );
                              }
                            }

                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Ação aplicada ✅')),
                            );
                          } catch (e) {
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(
                              context,
                            ).showSnackBar(SnackBar(content: Text('Erro: $e')));
                          }
                        },
                        itemBuilder: (_) => [
                          const PopupMenuItem(
                            value: 'make_member',
                            child: Text('Definir como member'),
                          ),
                          const PopupMenuItem(
                            value: 'make_owner',
                            child: Text('Definir como owner'),
                          ),
                          const PopupMenuDivider(),
                          const PopupMenuItem(
                            value: 'remove',
                            child: Text('Remover da empresa'),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
