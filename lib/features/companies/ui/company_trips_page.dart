import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/formatters.dart';
import '../../trips/ui/trip_detail_page.dart';
import '../data/company_trips_provider.dart';

class CompanyTripsPage extends ConsumerStatefulWidget {
  const CompanyTripsPage({super.key});

  @override
  ConsumerState<CompanyTripsPage> createState() => _CompanyTripsPageState();
}

class _CompanyTripsPageState extends ConsumerState<CompanyTripsPage> {
  String _status = 'all'; // all|open|closed
  String _vehicleQuery = ''; // filtra por placa/model (client-side)

  bool _matchVehicle(Map<String, dynamic> t) {
    final q = _vehicleQuery.trim().toLowerCase();
    if (q.isEmpty) return true;

    final v = (t['vehicle'] as Map?) ?? {};
    final model = (v['model'] ?? '').toString().toLowerCase();
    final plate = (v['plate'] ?? '').toString().toLowerCase();
    return model.contains(q) || plate.contains(q);
  }

  String _vehicleLabel(Map<String, dynamic> t) {
    final v = (t['vehicle'] as Map?) ?? {};
    final model = Fmt.cleanStr(v['model']);
    final plate = Fmt.cleanStr(v['plate']);
    final out = [model, plate].where((x) => x.isNotEmpty).join(' • ');
    return out.isEmpty ? '—' : out;
  }

  String _originLabel(Map<String, dynamic> t) {
    final o = (t['origin'] as Map?) ?? {};
    final state = Fmt.cleanStr(o['state']);
    final city = Fmt.cleanStr(o['city']);
    final place = Fmt.cleanStr(o['place']);
    final head = state.isEmpty ? '' : state;
    final tail = [city, place].where((x) => x.isNotEmpty).join(' • ');
    return [head, tail].where((x) => x.isNotEmpty).join(' • ');
  }

  int _toInt(dynamic v) => (v is int) ? v : int.tryParse('$v') ?? 0;

  int _totalKm(Map<String, dynamic> t) {
    final a = _toInt(t['startOdometerKm']);
    final b = t['endOdometerKm'];
    if (b == null) return 0;
    final end = _toInt(b);
    if (end < a) return 0;
    return end - a;
  }

  @override
  Widget build(BuildContext context) {
    final tripsAsync = ref.watch(companyTripsStreamProvider(_status));

    return Scaffold(
      appBar: AppBar(title: const Text('Viagens da empresa')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // filtros
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Filtros',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: _status,
                          decoration: const InputDecoration(
                            labelText: 'Status',
                            prefixIcon: Icon(Icons.filter_alt),
                          ),
                          items: const [
                            DropdownMenuItem(
                              value: 'all',
                              child: Text('Todos'),
                            ),
                            DropdownMenuItem(
                              value: 'open',
                              child: Text('Em andamento'),
                            ),
                            DropdownMenuItem(
                              value: 'closed',
                              child: Text('Finalizadas'),
                            ),
                          ],
                          onChanged: (v) =>
                              setState(() => _status = v ?? 'all'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          decoration: const InputDecoration(
                            labelText: 'Veículo (placa/modelo)',
                            prefixIcon: Icon(Icons.directions_car),
                          ),
                          onChanged: (v) => setState(() => _vehicleQuery = v),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 12),

          // lista
          tripsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Card(
              child: ListTile(
                leading: const Icon(Icons.error_outline),
                title: const Text('Erro ao carregar viagens'),
                subtitle: Text(e.toString()),
              ),
            ),
            data: (qs) {
              final docs = qs.docs;

              final filtered = docs
                  .map((d) => <String, dynamic>{'id': d.id, ...d.data()})
                  .where(_matchVehicle)
                  .toList();

              if (filtered.isEmpty) {
                return const Card(
                  child: ListTile(
                    leading: Icon(Icons.info_outline),
                    title: Text('Sem viagens'),
                    subtitle: Text(
                      'Nenhuma viagem encontrada com esse filtro.',
                    ),
                  ),
                );
              }

              return Column(
                children: [
                  for (final t in filtered)
                    Card(
                      child: ListTile(
                        leading: Icon(
                          (t['status'] ?? '') == 'open'
                              ? Icons.directions_car
                              : Icons.check_circle,
                        ),
                        title: Text(_vehicleLabel(t)),
                        subtitle: Text(
                          '${_originLabel(t)}\n'
                          'Saída: ${Fmt.dateTimeFromTimestamp(t['startAt'])}'
                          '${(t['status'] ?? '') == 'closed' ? '\nKm total: ${_totalKm(t)}' : ''}',
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => TripDetailPage(
                                tripId: (t['id'] ?? '').toString(),
                              ),
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
      ),
    );
  }
}
