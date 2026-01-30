import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../companies/ui/company_settings_card.dart';
import '../../profile/data/profile_repo_provider.dart';
import '../../trips/data/trips_providers.dart';
import '../../trips/ui/new_trip_page.dart';
import '../../trips/ui/trip_detail_page.dart';
import '../../vehicles/ui/vehicles_page.dart';

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(myProfileProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Log My Travel')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: profileAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Erro profile: $e')),
          data: (snap) {
            final p = snap.data() as Map<String, dynamic>? ?? {};
            final accountType = (p['accountType'] ?? 'individual').toString();
            final role = (p['role'] ?? 'member').toString();
            final companyId = (p['companyId'] ?? '').toString();

            // ✅ ownerType/ownerId (multi-tenant)
            final uid = snap.id; // docId == uid
            final ownerType = accountType; // 'individual'|'corporate'
            final ownerId = (accountType == 'corporate') ? companyId : uid;

            final tripsRepo = ref.read(tripsRepoProvider);

            Future<void> _goNewTripSafely() async {
              // ✅ trava antes de navegar
              final openTripId = await tripsRepo.getOpenTripId(
                ownerType: ownerType,
                ownerId: ownerId,
              );

              if (!context.mounted) return;

              if (openTripId != null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Já existe uma viagem em andamento. Continue ou finalize.',
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
            }

            return ListView(
              children: [
                // Modo
                Card(
                  child: ListTile(
                    leading: Icon(
                      accountType == 'corporate'
                          ? Icons.business
                          : Icons.person,
                    ),
                    title: Text(
                      accountType == 'corporate'
                          ? 'Modo corporate ($role)'
                          : 'Modo individual',
                    ),
                    subtitle: accountType == 'corporate'
                        ? Text(
                            'companyId: ${companyId.isEmpty ? "-" : companyId}',
                          )
                        : const Text('Suas viagens no seu veículo'),
                  ),
                ),

                if (accountType == 'corporate' && role == 'owner') ...[
                  const SizedBox(height: 12),
                  const CompanySettingsCard(),
                ],

                const SizedBox(height: 12),

                // ✅ Card inteligente: Nova OU Continuar
                FutureBuilder(
                  future: tripsRepo.getOpenTrip(
                    ownerType: ownerType,
                    ownerId: ownerId,
                  ),
                  builder: (context, snapTrip) {
                    if (snapTrip.connectionState == ConnectionState.waiting) {
                      return const Card(
                        child: ListTile(
                          leading: SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                          title: Text('Verificando viagem em andamento...'),
                        ),
                      );
                    }

                    if (snapTrip.hasError) {
                      return Card(
                        child: ListTile(
                          leading: const Icon(Icons.error_outline),
                          title: const Text('Erro ao verificar viagem aberta'),
                          subtitle: Text(snapTrip.error.toString()),
                        ),
                      );
                    }

                    final openTrip = snapTrip.data;

                    // Sem viagem aberta: mostra Nova viagem (com trava extra no onTap)
                    if (openTrip == null) {
                      return Card(
                        child: ListTile(
                          leading: const Icon(Icons.add_road),
                          title: const Text('Nova viagem'),
                          subtitle: const Text('Iniciar uma nova viagem'),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: _goNewTripSafely,
                        ),
                      );
                    }

                    // Tem viagem aberta: continuar + mostra veículo
                    final vehicle = (openTrip['vehicle'] as Map?) ?? {};
                    final model = (vehicle['model'] ?? '').toString();
                    final plate = (vehicle['plate'] ?? '').toString();
                    final tripId = (openTrip['id'] ?? '').toString();

                    final vehicleLabel = [
                      model.trim(),
                      plate.trim(),
                    ].where((x) => x.isNotEmpty).join(' • ');

                    return Card(
                      child: ListTile(
                        leading: const Icon(Icons.play_circle),
                        title: Text(
                          vehicleLabel.isEmpty
                              ? 'Continuar viagem'
                              : 'Continuar viagem • $vehicleLabel',
                        ),
                        subtitle: const Text('Existe uma viagem em andamento'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => TripDetailPage(tripId: tripId),
                            ),
                          );
                        },
                      ),
                    );
                  },
                ),

                const SizedBox(height: 12),

                // Veículos
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.directions_car),
                    title: const Text('Veículos'),
                    subtitle: Text(
                      accountType == 'corporate'
                          ? 'Cadastrar (owner) e selecionar veículos'
                          : 'Seus veículos pessoais',
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const VehiclesPage()),
                      );
                    },
                  ),
                ),

                const SizedBox(height: 16),
                const Text(
                  'Viagens recentes',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),

                // ✅ Lista de viagens (abertas e fechadas)
                StreamBuilder(
                  stream: tripsRepo.listTripsForOwner(
                    ownerType: ownerType,
                    ownerId: ownerId,
                  ),
                  builder: (context, snapTrips) {
                    if (snapTrips.hasError) {
                      return Text(
                        'Erro ao carregar viagens: ${snapTrips.error}',
                        style: const TextStyle(color: Colors.red),
                      );
                    }
                    if (!snapTrips.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final docs = snapTrips.data!.docs;
                    if (docs.isEmpty) {
                      return const Card(
                        child: ListTile(
                          leading: Icon(Icons.route),
                          title: Text('Nenhuma viagem ainda'),
                          subtitle: Text(
                            'Crie sua primeira viagem pelo botão acima.',
                          ),
                        ),
                      );
                    }

                    return Column(
                      children: [
                        for (final d in docs)
                          Card(
                            child: ListTile(
                              leading: Icon(
                                (d.data()['status'] == 'open')
                                    ? Icons.directions_car
                                    : Icons.check_circle,
                              ),
                              title: Text(_tripTitle(d.data())),
                              subtitle: Text(_tripSubtitle(d.data())),
                              trailing: const Icon(Icons.chevron_right),
                              onTap: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        TripDetailPage(tripId: d.id),
                                  ),
                                );
                              },
                            ),
                          ),
                      ],
                    );
                  },
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  static String _tripTitle(Map<String, dynamic> t) {
    final status = (t['status'] ?? '').toString();
    final vehicle = (t['vehicle'] as Map?) ?? {};
    final model = (vehicle['model'] ?? '').toString().trim();
    final plate = (vehicle['plate'] ?? '').toString().trim();
    final v = [model, plate].where((x) => x.isNotEmpty).join(' • ');
    final s = status == 'open' ? 'EM ANDAMENTO' : 'FINALIZADA';
    return v.isEmpty ? s : '$s • $v';
  }

  static String _tripSubtitle(Map<String, dynamic> t) {
    // origem
    final origin = (t['origin'] as Map?) ?? {};
    final country = (origin['country'] ?? '').toString().trim();
    final state = (origin['state'] ?? '').toString().trim();
    final city = (origin['city'] ?? '').toString().trim();
    final place = (origin['place'] ?? '').toString().trim();

    final head = [country, state].where((x) => x.isNotEmpty).join('-');
    final tail = [city, place].where((x) => x.isNotEmpty).join(' • ');
    final originStr = [head, tail].where((x) => x.isNotEmpty).join(' • ');

    // km
    final startKm = t['startOdometerKm'];
    final endKm = t['endOdometerKm'];
    final startStr = (startKm == null) ? '' : 'Km ini: $startKm';
    final endStr = (endKm == null) ? '' : 'Km fim: $endKm';
    final kmStr = [startStr, endStr].where((x) => x.isNotEmpty).join(' • ');

    if (originStr.isEmpty) return kmStr.isEmpty ? '—' : kmStr;
    if (kmStr.isEmpty) return originStr;
    return '$originStr\n$kmStr';
  }
}
