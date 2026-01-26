import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/formatters.dart';
import '../data/trips_providers.dart';

class TripDetailPage extends ConsumerStatefulWidget {
  const TripDetailPage({super.key, required this.tripId});
  final String tripId;

  @override
  ConsumerState<TripDetailPage> createState() => _TripDetailPageState();
}

class _TripDetailPageState extends ConsumerState<TripDetailPage> {
  Stream<DocumentSnapshot<Map<String, dynamic>>> _tripStream() {
    return FirebaseFirestore.instance
        .collection('trips')
        .doc(widget.tripId)
        .snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> _stopsStream() {
    return FirebaseFirestore.instance
        .collection('trips')
        .doc(widget.tripId)
        .collection('stops')
        .orderBy('at', descending: true)
        .snapshots();
  }

  Future<void> _openAddStopSheet() async {
    final countryCtrl = TextEditingController(text: 'BR');
    final stateCtrl = TextEditingController(text: 'CE');
    final cityCtrl = TextEditingController();
    final placeCtrl = TextEditingController();
    final noteCtrl = TextEditingController();

    bool loading = false;
    String? err;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setStateSheet) {
            Future<void> save() async {
              if (cityCtrl.text.trim().isEmpty) {
                setStateSheet(() => err = 'Informe a cidade.');
                return;
              }

              setStateSheet(() {
                loading = true;
                err = null;
              });

              try {
                await ref
                    .read(tripsRepoProvider)
                    .addStop(
                      tripId: widget.tripId,
                      location: {
                        'country': countryCtrl.text.trim().toUpperCase(),
                        'state': stateCtrl.text.trim().toUpperCase(),
                        'city': cityCtrl.text.trim(),
                        'place': placeCtrl.text.trim(),
                      },
                      note: noteCtrl.text.trim().isEmpty
                          ? null
                          : noteCtrl.text.trim(),
                    );

                if (!mounted) return;
                Navigator.of(ctx).pop();

                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Parada adicionada ✅')),
                );
              } catch (e) {
                setStateSheet(() {
                  loading = false;
                  err = 'Erro ao salvar: $e';
                });
              }
            }

            return Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
                top: 8,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Adicionar parada',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),

                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: countryCtrl,
                          decoration: const InputDecoration(
                            labelText: 'País (ISO)',
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: stateCtrl,
                          decoration: const InputDecoration(
                            labelText: 'UF/Estado',
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: cityCtrl,
                    decoration: const InputDecoration(labelText: 'Cidade'),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: placeCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Local (ex: Hospital X)',
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: noteCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Observação (opcional)',
                    ),
                  ),

                  if (err != null) ...[
                    const SizedBox(height: 8),
                    Text(err!, style: const TextStyle(color: Colors.red)),
                  ],

                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: loading ? null : save,
                      icon: const Icon(Icons.add_location_alt),
                      label: Text(loading ? 'Salvando...' : 'Salvar parada'),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );

    countryCtrl.dispose();
    stateCtrl.dispose();
    cityCtrl.dispose();
    placeCtrl.dispose();
    noteCtrl.dispose();
  }

  // ✅ Agora recebe origin para pré-preencher destino final
  Future<void> _closeTripDialog({required Map<String, dynamic> origin}) async {
    final endKmCtrl = TextEditingController();

    // Pré-preenchido com a ORIGEM
    final endCountryCtrl = TextEditingController(
      text: (origin['country'] ?? 'BR').toString(),
    );
    final endStateCtrl = TextEditingController(
      text: (origin['state'] ?? 'CE').toString(),
    );
    final endCityCtrl = TextEditingController(
      text: (origin['city'] ?? '').toString(),
    );
    final endPlaceCtrl = TextEditingController(
      text: (origin['place'] ?? '').toString(),
    );

    bool loading = false;
    String? err;

    await showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            Future<void> finish() async {
              final endKm = int.tryParse(endKmCtrl.text.trim());
              if (endKm == null) {
                setDialogState(() => err = 'Informe o km final (número).');
                return;
              }

              if (endCityCtrl.text.trim().isEmpty) {
                setDialogState(() => err = 'Informe a cidade final.');
                return;
              }

              setDialogState(() {
                loading = true;
                err = null;
              });

              final endLocation = <String, String>{
                'country': endCountryCtrl.text.trim().toUpperCase(),
                'state': endStateCtrl.text.trim().toUpperCase(),
                'city': endCityCtrl.text.trim(),
                'place': endPlaceCtrl.text.trim(),
              };

              try {
                await ref
                    .read(tripsRepoProvider)
                    .closeTrip(
                      tripId: widget.tripId,
                      endOdometerKm: endKm,
                      endLocation: endLocation,
                    );

                if (!mounted) return;

                // Fecha o dialog sem usar ctx pós-await (linter safe)
                Navigator.of(context, rootNavigator: true).pop();

                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Viagem finalizada ✅')),
                );

                Navigator.of(context).pop(); // volta para Home
              } catch (e) {
                setDialogState(() {
                  loading = false;
                  err = 'Erro: $e';
                });
              }
            }

            return AlertDialog(
              title: const Text('Finalizar viagem'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: endKmCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Km final'),
                    ),
                    const SizedBox(height: 12),

                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Destino final',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(height: 8),

                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: endCountryCtrl,
                            decoration: const InputDecoration(
                              labelText: 'País (ISO)',
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: endStateCtrl,
                            decoration: const InputDecoration(
                              labelText: 'UF/Estado',
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: endCityCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Cidade final',
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: endPlaceCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Local de entrega (opcional)',
                      ),
                    ),

                    if (err != null) ...[
                      const SizedBox(height: 10),
                      Text(err!, style: const TextStyle(color: Colors.red)),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: loading ? null : () => Navigator.of(ctx).pop(),
                  child: const Text('Cancelar'),
                ),
                ElevatedButton(
                  onPressed: loading ? null : finish,
                  child: Text(loading ? 'Finalizando...' : 'Finalizar'),
                ),
              ],
            );
          },
        );
      },
    );

    endKmCtrl.dispose();
    endCountryCtrl.dispose();
    endStateCtrl.dispose();
    endCityCtrl.dispose();
    endPlaceCtrl.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: _tripStream(),
      builder: (context, tripSnap) {
        if (!tripSnap.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final trip = tripSnap.data!.data();
        if (trip == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Viagem')),
            body: const Center(child: Text('Trip não encontrada.')),
          );
        }

        final status = Fmt.cleanStr(trip['status']);
        final isOpen = status == 'open';

        final startKm = trip['startOdometerKm'];
        final endKm = trip['endOdometerKm'];

        final startAt = trip['startAt'];
        final endAt = trip['endAt'];

        final origin = (trip['origin'] as Map<String, dynamic>?) ?? {};
        final originStr =
            '${Fmt.cleanStr(origin['country'])}-${Fmt.cleanStr(origin['state'])} • '
            '${Fmt.cleanStr(origin['city'])} • ${Fmt.cleanStr(origin['place'])}';

        final endLoc = (trip['endLocation'] as Map<String, dynamic>?) ?? {};
        final endLocStr = endLoc.isEmpty
            ? '—'
            : '${Fmt.cleanStr(endLoc['country'])}-${Fmt.cleanStr(endLoc['state'])} • '
                  '${Fmt.cleanStr(endLoc['city'])} • ${Fmt.cleanStr(endLoc['place'])}';

        final vehicle = (trip['vehicle'] as Map<String, dynamic>?) ?? {};
        final vehicleStr =
            '${Fmt.cleanStr(vehicle['model'])} • ${Fmt.cleanStr(vehicle['plate'])}'
                .trim();

        final totalKm = Fmt.totalKm(startKm, endKm);

        return Scaffold(
          appBar: AppBar(title: Text('Trip ${widget.tripId.substring(0, 6)}')),
          floatingActionButton: isOpen
              ? FloatingActionButton.extended(
                  onPressed: _openAddStopSheet,
                  icon: const Icon(Icons.add_location_alt),
                  label: const Text('Adicionar parada'),
                )
              : null,
          body: ListView(
            padding: const EdgeInsets.all(12),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Chip(
                            label: Text(isOpen ? 'EM ANDAMENTO' : 'FINALIZADA'),
                            avatar: Icon(
                              isOpen
                                  ? Icons.directions_car
                                  : Icons.check_circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '🚗 $vehicleStr',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text('Origem: $originStr'),
                      Text('Destino final: $endLocStr'),
                      const SizedBox(height: 8),
                      Text('Início: ${Fmt.dateTimeFromTimestamp(startAt)}'),
                      Text('Fim: ${Fmt.dateTimeFromTimestamp(endAt)}'),
                      const SizedBox(height: 8),
                      Text(
                        'Km: ${Fmt.km(startKm)} → ${Fmt.km(endKm)}  (Total: $totalKm)',
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 12),
              const Text(
                'Paradas',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),

              StreamBuilder(
                stream: _stopsStream(),
                builder: (context, stopsSnap) {
                  if (!stopsSnap.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final stops = stopsSnap.data!.docs;
                  if (stops.isEmpty) return const Text('Nenhuma parada ainda.');

                  return Column(
                    children: stops.map((d) {
                      final s = d.data();
                      final loc =
                          (s['location'] as Map<String, dynamic>?) ?? {};
                      final city = Fmt.cleanStr(loc['city']);
                      final place = Fmt.cleanStr(loc['place']);
                      final at = s['at'];

                      return Card(
                        child: ListTile(
                          leading: const Icon(Icons.flag),
                          title: Text('$city • $place'.trim()),
                          subtitle: Text(Fmt.dateTimeFromTimestamp(at)),
                        ),
                      );
                    }).toList(),
                  );
                },
              ),

              const SizedBox(height: 18),
              const Divider(),
              const SizedBox(height: 8),

              if (isOpen) ...[
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => _closeTripDialog(origin: origin),
                    icon: const Icon(Icons.flag_circle),
                    label: const Text('Finalizar viagem'),
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Finalize quando o veículo for entregue no destino final.',
                  style: TextStyle(fontSize: 12),
                ),
              ] else ...[
                const Center(child: Text('Viagem encerrada.')),
              ],

              const SizedBox(height: 90),
            ],
          ),
        );
      },
    );
  }
}
