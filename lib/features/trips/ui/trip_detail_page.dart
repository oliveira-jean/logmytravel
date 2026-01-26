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

  // ✅ Timeline fica melhor em ordem cronológica (mais antigo -> mais novo)
  Stream<QuerySnapshot<Map<String, dynamic>>> _stopsStreamAsc() {
    return FirebaseFirestore.instance
        .collection('trips')
        .doc(widget.tripId)
        .collection('stops')
        .orderBy('at', descending: false)
        .snapshots();
  }

  // ======================
  // ADD STOP (BOTTOM SHEET)
  // ======================
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

  // ======================
  // CLOSE TRIP (DIALOG)
  // ======================
  Future<void> _closeTripDialog({required Map<String, dynamic> origin}) async {
    final endKmCtrl = TextEditingController();

    // pré-preenchido com a ORIGEM
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

                // fecha o dialog de forma segura
                Navigator.of(context, rootNavigator: true).pop();

                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Viagem finalizada ✅')),
                );

                Navigator.of(context).pop(); // volta pra Home
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

  // ======================
  // UI HELPERS (Timeline)
  // ======================
  Widget _timelineNode({
    required IconData icon,
    required String title,
    required String subtitle,
    String? rightTop,
    String? rightBottom,
    bool highlight = false,
  }) {
    return Card(
      elevation: highlight ? 2 : 1,
      child: ListTile(
        leading: CircleAvatar(child: Icon(icon)),
        title: Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: highlight ? Colors.black : null,
          ),
        ),
        subtitle: Text(subtitle),
        trailing: (rightTop == null && rightBottom == null)
            ? null
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (rightTop != null)
                    Text(
                      rightTop,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  if (rightBottom != null) Text(rightBottom),
                ],
              ),
      ),
    );
  }

  String _fmtLoc(Map<String, dynamic> loc) {
    final c = Fmt.cleanStr(loc['country']);
    final s = Fmt.cleanStr(loc['state']);
    final city = Fmt.cleanStr(loc['city']);
    final place = Fmt.cleanStr(loc['place']);
    final head = '${c.isEmpty ? '' : '$c-'}$s'.trim();
    final tail = [city, place].where((x) => x.trim().isNotEmpty).join(' • ');
    if (head.isEmpty) return tail.isEmpty ? '—' : tail;
    if (tail.isEmpty) return head;
    return '$head • $tail';
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
        final totalKm = Fmt.totalKm(startKm, endKm);

        final startAt = trip['startAt'];
        final endAt = trip['endAt'];

        final origin = (trip['origin'] as Map<String, dynamic>?) ?? {};
        final endLoc = (trip['endLocation'] as Map<String, dynamic>?) ?? {};

        final vehicle = (trip['vehicle'] as Map<String, dynamic>?) ?? {};
        final vehicleModel = Fmt.cleanStr(vehicle['model']);
        final vehiclePlate = Fmt.cleanStr(vehicle['plate']);
        final vehicleStr = [
          vehicleModel,
          vehiclePlate,
        ].where((x) => x.isNotEmpty).join(' • ');

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
              // ======= Header/status =======
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Chip(
                        label: Text(isOpen ? 'EM ANDAMENTO' : 'FINALIZADA'),
                        avatar: Icon(
                          isOpen ? Icons.directions_car : Icons.check_circle,
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
                ),
              ),
              const SizedBox(height: 12),

              // ======= Timeline: Start =======
              _timelineNode(
                icon: Icons.play_circle,
                title: 'Saída',
                subtitle: _fmtLoc(origin),
                rightTop: 'Km ${Fmt.km(startKm)}',
                rightBottom: Fmt.dateTimeFromTimestamp(startAt),
                highlight: true,
              ),

              const SizedBox(height: 8),
              const Text(
                'Paradas',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),

              // ======= Timeline: Stops =======
              StreamBuilder(
                stream: _stopsStreamAsc(),
                builder: (context, stopsSnap) {
                  if (!stopsSnap.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final stops = stopsSnap.data!.docs;
                  if (stops.isEmpty) {
                    return const Text('Nenhuma parada ainda.');
                  }

                  return Column(
                    children: [
                      for (final d in stops)
                        Builder(
                          builder: (_) {
                            final s = d.data();
                            final loc =
                                (s['location'] as Map<String, dynamic>?) ?? {};
                            final note = Fmt.cleanStr(s['note']);
                            final at = s['at'];

                            final subtitle = [
                              _fmtLoc(loc),
                              if (note.isNotEmpty) 'Obs: $note',
                            ].join('\n');

                            return _timelineNode(
                              icon: Icons.flag,
                              title: 'Parada',
                              subtitle: subtitle,
                              rightBottom: Fmt.dateTimeFromTimestamp(at),
                            );
                          },
                        ),
                    ],
                  );
                },
              ),

              const SizedBox(height: 12),

              // ======= Timeline: End =======
              if (!isOpen) ...[
                _timelineNode(
                  icon: Icons.stop_circle,
                  title: 'Entrega (fim da viagem)',
                  subtitle: _fmtLoc(endLoc),
                  rightTop: 'Km ${Fmt.km(endKm)}',
                  rightBottom: Fmt.dateTimeFromTimestamp(endAt),
                  highlight: true,
                ),
                const SizedBox(height: 12),

                // ======= Resumo final =======
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.summarize),
                    title: const Text(
                      'Resumo',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      'Total rodado: $totalKm km\n'
                      'Veículo: $vehicleStr',
                    ),
                  ),
                ),
              ] else ...[
                // Aberta: CTA de finalizar
                const Divider(),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => _closeTripDialog(origin: origin),
                    icon: const Icon(Icons.flag_circle),
                    label: const Text('Finalizar viagem (entrega do veículo)'),
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Regra: só finalize quando o veículo for entregue no destino final.',
                  style: TextStyle(fontSize: 12),
                ),
              ],

              const SizedBox(height: 90),
            ],
          ),
        );
      },
    );
  }
}
