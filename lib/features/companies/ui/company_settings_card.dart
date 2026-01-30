import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/company_settings_provider.dart';

class CompanySettingsCard extends ConsumerWidget {
  const CompanySettingsCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final companyDocAsync = ref.watch(companySettingsDocProvider);

    return companyDocAsync.when(
      loading: () => const Card(
        child: ListTile(
          leading: SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          title: Text('Carregando configurações da empresa...'),
        ),
      ),
      error: (e, _) => Card(
        child: ListTile(
          leading: const Icon(Icons.error_outline),
          title: const Text('Erro ao carregar settings da empresa'),
          subtitle: Text(e.toString()),
        ),
      ),
      data: (snap) {
        final data = snap.data() ?? {};
        final name = (data['name'] ?? 'Empresa').toString();
        final allow = data['allowEditTripDateTime'] == true;

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Configurações (Corporate)',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                Text('Empresa: $name'),
                const SizedBox(height: 10),

                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Permitir edição de data/hora'),
                  subtitle: Text(
                    allow
                        ? 'Funcionários podem ajustar data/hora (operacional)'
                        : 'Data/hora travada (automático)',
                  ),
                  value: allow,
                  onChanged: (v) async {
                    final companyId = snap.id;
                    try {
                      await ref
                          .read(companySettingsRepoProvider)
                          .setAllowEditTripDateTime(
                            companyId: companyId,
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
              ],
            ),
          ),
        );
      },
    );
  }
}
