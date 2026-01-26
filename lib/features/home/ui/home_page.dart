import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/formatters.dart';
import '../../auth/data/auth_providers.dart';
import '../../profile/data/profile_repo_provider.dart';
import '../../trips/data/trips_providers.dart';
import '../../trips/ui/new_trip_page.dart';
import '../../trips/ui/trip_detail_page.dart';

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  Future<void> _logout(WidgetRef ref) async {
    final auth = ref.read(firebaseAuthProvider);
    await auth.signOut();
  }

  Widget _statusChip(String status) {
    final isOpen = status == 'open';
    return Chip(
      label: Text(isOpen ? 'EM ANDAMENTO' : 'FINALIZADA'),
      avatar: Icon(isOpen ? Icons.directions_car : Icons.check_circle),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(myProfileProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Log My Travel'),
        actions: [
          IconButton(
            onPressed: () => _logout(ref),
            icon: const Icon(Icons.logout),
            tooltip: 'Sair',
          ),
        ],
      ),
      body: profileAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Erro perfil: $e')),
        data: (snap) {
          final data = (snap.data() as Map<String, dynamic>?);
          if (data == null) {
            return const Center(
              child: Text('Perfil vazio. Volte e refaça onboarding.'),
            );
          }

          final accountType = (data['accountType'] ?? 'individual').toString();
          final companyId = data['companyId'] as String?;

          final ownerType = accountType == 'corporate' ? 'company' : 'user';
          final ownerId = accountType == 'corporate'
              ? (companyId ?? '')
              : snap.id;

          if (ownerType == 'company' && ownerId.isEmpty) {
            return const Center(
              child: Text('Corporate sem companyId. Refaça onboarding.'),
            );
          }

          final repo = ref.watch(tripsRepoProvider);
          final tripsStream = repo.listTripsForOwner(
            ownerType: ownerType,
            ownerId: ownerId,
          );

          return StreamBuilder(
            stream: tripsStream,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(
                  child: Text('Erro ao ler trips: ${snapshot.error}'),
                );
              }
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              final docs = snapshot.data?.docs ?? [];
              final openDoc = docs.isEmpty
                  ? null
                  : docs.cast().firstWhere(
                      (d) => (d.data()['status'] ?? '') == 'open',
                      orElse: () => null,
                    );

              return ListView(
                padding: const EdgeInsets.all(12),
                children: [
                  Card(
                    child: ListTile(
                      title: Text(
                        accountType == 'corporate'
                            ? 'Modo: Corporate'
                            : 'Modo: Individual',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(
                        ownerType == 'company'
                            ? 'Empresa (companyId): $ownerId'
                            : 'Usuário (uid): $ownerId',
                      ),
                      trailing: const Icon(Icons.manage_accounts),
                    ),
                  ),
                  const SizedBox(height: 12),

                  if (openDoc != null) ...[
                    Builder(
                      builder: (_) {
                        final m = openDoc.data();
                        final startAt = m['startAt'];
                        final startKm = m['startOdometerKm'];

                        final origin = m['origin'] as Map<String, dynamic>?;
                        final originStr = origin == null
                            ? ''
                            : '${Fmt.cleanStr(origin['country'])}-${Fmt.cleanStr(origin['state'])} • '
                                  '${Fmt.cleanStr(origin['city'])} • ${Fmt.cleanStr(origin['place'])}';

                        final vehicle = m['vehicle'] as Map<String, dynamic>?;
                        final plate = vehicle == null
                            ? ''
                            : Fmt.cleanStr(vehicle['plate']);
                        final model = vehicle == null
                            ? ''
                            : Fmt.cleanStr(vehicle['model']);
                        final vehicleStr = (plate.isEmpty && model.isEmpty)
                            ? ''
                            : '🚗 $model • $plate';

                        return Card(
                          elevation: 2,
                          child: ListTile(
                            leading: const Icon(Icons.play_circle_fill),
                            title: const Text(
                              'Viagem em andamento',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            subtitle: Text(
                              'Início: ${Fmt.dateTimeFromTimestamp(startAt)}\n'
                              'Km inicial: ${Fmt.km(startKm)}\n'
                              '${vehicleStr.isEmpty ? '' : '$vehicleStr\n'}'
                              '$originStr',
                            ),
                            trailing: ElevatedButton(
                              onPressed: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        TripDetailPage(tripId: openDoc.id),
                                  ),
                                );
                              },
                              child: const Text('Continuar'),
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 12),
                  ],

                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Viagens',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      Text('Total: ${docs.length}'),
                    ],
                  ),
                  const SizedBox(height: 8),

                  if (docs.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: Center(child: Text('Nenhuma viagem ainda.')),
                    ),

                  ...docs.map((d) {
                    final m = d.data();
                    final status = (m['status'] ?? '').toString();

                    final startKm = m['startOdometerKm'];
                    final endKm = m['endOdometerKm'];
                    final kmTotal = Fmt.totalKm(startKm, endKm);

                    final startAt = m['startAt'];

                    final origin = m['origin'] as Map<String, dynamic>?;
                    final originStr = origin == null
                        ? ''
                        : '${Fmt.cleanStr(origin['country'])}-${Fmt.cleanStr(origin['state'])} • '
                              '${Fmt.cleanStr(origin['city'])} • ${Fmt.cleanStr(origin['place'])}';

                    final vehicle = m['vehicle'] as Map<String, dynamic>?;
                    final plate = vehicle == null
                        ? ''
                        : Fmt.cleanStr(vehicle['plate']);
                    final model = vehicle == null
                        ? ''
                        : Fmt.cleanStr(vehicle['model']);
                    final vehicleStr = (plate.isEmpty && model.isEmpty)
                        ? ''
                        : '🚗 $model • $plate';

                    return Card(
                      child: ListTile(
                        isThreeLine: true,
                        leading: _statusChip(status),
                        title: Text('Trip ${d.id.substring(0, 6)}'),
                        subtitle: Text(
                          'Início: ${Fmt.dateTimeFromTimestamp(startAt)}\n'
                          '${vehicleStr.isEmpty ? '' : '$vehicleStr\n'}'
                          'Km: ${Fmt.km(startKm)} → ${Fmt.km(endKm)} (Total: $kmTotal)\n'
                          '$originStr',
                        ),
                        trailing: Icon(
                          status == 'open'
                              ? Icons.play_arrow
                              : Icons.visibility,
                        ),
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => TripDetailPage(tripId: d.id),
                            ),
                          );
                        },
                      ),
                    );
                  }),

                  const SizedBox(height: 90),
                ],
              );
            },
          );
        },
      ),

      // ✅ FAB inteligente: se tem trip aberta, vai pra ela; senão, cria nova.
      floatingActionButton: profileAsync.maybeWhen(
        data: (snap) {
          final data = (snap.data() as Map<String, dynamic>?);
          if (data == null) return null;

          final accountType = (data['accountType'] ?? 'individual').toString();
          final companyId = data['companyId'] as String?;

          final ownerType = accountType == 'corporate' ? 'company' : 'user';
          final ownerId = accountType == 'corporate'
              ? (companyId ?? '')
              : snap.id;
          if (ownerType == 'company' && ownerId.isEmpty) return null;

          final repo = ref.watch(tripsRepoProvider);

          return FloatingActionButton(
            onPressed: () async {
              // Regra A2 (definitiva no app):
              final openTripId = await repo.getOpenTripId(
                ownerType: ownerType,
                ownerId: ownerId,
              );

              if (!context.mounted) return;

              if (openTripId != null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Você já tem uma viagem em andamento. Finalize ou continue.',
                    ),
                  ),
                );
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => TripDetailPage(tripId: openTripId),
                  ),
                );
                return;
              }

              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) =>
                      NewTripPage(ownerType: ownerType, ownerId: ownerId),
                ),
              );
            },
            child: const Icon(Icons.add),
            tooltip: 'Nova viagem',
          );
        },
        orElse: () => null,
      ),
    );
  }
}
