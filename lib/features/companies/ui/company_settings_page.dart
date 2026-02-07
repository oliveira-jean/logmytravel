import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/company_settings_provider.dart';

class CompanySettingsPage extends ConsumerWidget {
  const CompanySettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final companyDocAsync = ref.watch(companySettingsDocProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Configurações da empresa')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          companyDocAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Card(
              child: ListTile(
                leading: const Icon(Icons.error_outline),
                title: const Text('Erro ao carregar empresa'),
                subtitle: Text(e.toString()),
              ),
            ),
            data: (snap) {
              final data = snap.data() ?? {};
              final name = (data['name'] ?? 'Empresa').toString();
              final allow = data['allowEditTripDateTime'] == true;

              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'CompanyId: ${snap.id}',
                        style: const TextStyle(fontSize: 12),
                      ),
                      const SizedBox(height: 16),

                      const Text(
                        'Operacional',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),

                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Permitir edição de data/hora'),
                        subtitle: Text(
                          allow
                              ? 'Motoristas podem ajustar data/hora (start/end)'
                              : 'Data/hora travada (automático)',
                        ),
                        value: allow,
                        onChanged: (v) async {
                          try {
                            await ref
                                .read(companySettingsRepoProvider)
                                .setAllowEditTripDateTime(
                                  companyId: snap.id,
                                  allow: v,
                                );

                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  v
                                      ? 'Edição habilitada ✅'
                                      : 'Edição desabilitada 🔒',
                                ),
                              ),
                            );
                          } catch (e) {
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Erro ao salvar: $e')),
                            );
                          }
                        },
                      ),

                      const Divider(height: 24),

                      const Text(
                        'Nota',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        '• Individual: sempre pode editar.\n'
                        '• Corporate: depende dessa configuração.\n'
                        '• Auditoria (serverTimestamp) continua sendo registrada.',
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
