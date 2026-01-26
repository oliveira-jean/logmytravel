import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
          final companyId = (data['companyId'] as String?);

          final ownerType = accountType == 'corporate' ? 'company' : 'user';
          final ownerId = accountType == 'corporate'
              ? (companyId ?? '')
              : (snap.id);

          if (ownerType == 'company' && ownerId.isEmpty) {
            return const Center(
              child: Text('Corporate sem companyId. Refaça onboarding.'),
            );
          }

          final tripsStream = ref
              .watch(tripsRepoProvider)
              .listTripsForOwner(ownerType: ownerType, ownerId: ownerId);

          return StreamBuilder(
            stream: tripsStream,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              final docs = snapshot.data?.docs ?? [];

              return ListView(
                padding: const EdgeInsets.all(12),
                children: [
                  Card(
                    child: ListTile(
                      title: Text('Modo: $accountType'),
                      subtitle: Text('Owner: $ownerType / $ownerId'),
                      trailing: ElevatedButton(
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => NewTripPage(
                                ownerType: ownerType,
                                ownerId: ownerId,
                              ),
                            ),
                          );
                        },
                        child: const Text('Nova viagem'),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Viagens',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
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
                    final startKm = m['startOdometerKm']?.toString() ?? '-';
                    final endKm = m['endOdometerKm']?.toString() ?? '-';
                    final origin = m['origin'] as Map<String, dynamic>?;
                    final originStr = origin == null
                        ? ''
                        : '${origin['country'] ?? ''}-${origin['state'] ?? ''} / ${origin['city'] ?? ''} • ${origin['place'] ?? ''}';

                    return Card(
                      child: ListTile(
                        title: Text('Trip ${d.id.substring(0, 6)} • $status'),
                        subtitle: Text('Km: $startKm → $endKm\n$originStr'),
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
                ],
              );
            },
          );
        },
      ),
    );
  }
}
