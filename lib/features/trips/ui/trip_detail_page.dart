import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/formatters.dart';
import '../../companies/data/company_settings_provider.dart';
import '../data/trips_providers.dart';

class TripDetailPage extends ConsumerStatefulWidget {
  const TripDetailPage({super.key, required this.tripId});
  final String tripId;

  @override
  ConsumerState<TripDetailPage> createState() => _TripDetailPageState();
}

class _TripDetailPageState extends ConsumerState<TripDetailPage> {
  bool _closingTrip = false; // evita clique duplo no finalizar

  Stream<DocumentSnapshot<Map<String, dynamic>>> _tripStream() {
    return FirebaseFirestore.instance
        .collection('trips')
        .doc(widget.tripId)
        .snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> _stopsStreamAsc() {
    return FirebaseFirestore.instance
        .collection('trips')
        .doc(widget.tripId)
        .collection('stops')
        .orderBy('at', descending: false)
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

  String _fmtDt(DateTime dt) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(dt.day)}/${two(dt.month)}/${dt.year} ${two(dt.hour)}:${two(dt.minute)}';
  }

  Future<DateTime?> _pickDateTime(DateTime initial) async {
    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (date == null) return null;

    if (!mounted) return null;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
    );
    if (time == null) return null;

    return DateTime(date.year, date.month, date.day, time.hour, time.minute);
  }

  Future<void> _closeTripDialog({
    required Map<String, dynamic> origin,
    required bool canEditDt,
    required int startOdometerKm,
  }) async {
    if (_closingTrip) return;

    final endKmCtrl = TextEditingController();

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

    DateTime endDateTime = DateTime.now();
    bool loading = false;
    String? err;

    await showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            Future<void> finish() async {
              if (_closingTrip) return;

              final endKm = int.tryParse(endKmCtrl.text.trim());
              if (endKm == null) {
                setDialogState(() => err = 'Informe o km final (número).');
                return;
              }
              if (endKm < startOdometerKm) {
                setDialogState(
                  () => err =
                      'Km final não pode ser menor que Km inicial ($startOdometerKm).',
                );
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

              final endAt = Timestamp.fromDate(
                canEditDt ? endDateTime : DateTime.now(),
              );

              try {
                _closingTrip = true;

                await ref
                    .read(tripsRepoProvider)
                    .closeTrip(
                      tripId: widget.tripId,
                      endOdometerKm: endKm,
                      endLocation: endLocation,
                      endAt: endAt,
                    );

                if (!mounted) return;

                // Fecha apenas o dialog
                Navigator.of(ctx).pop();

                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Viagem finalizada ✅')),
                );

                // Volta para Home (ou tela anterior) de forma segura
                Navigator.of(context).maybePop();
              } catch (e) {
                _closingTrip = false;
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
                        'Data/Hora de entrega',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(height: 8),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(_fmtDt(endDateTime)),
                      subtitle: Text(
                        canEditDt
                            ? 'Editável (conforme plano)'
                            : 'Travado pela empresa (horário automático)',
                      ),
                      trailing: IconButton(
                        onPressed: (canEditDt && !loading)
                            ? () async {
                                final picked = await _pickDateTime(endDateTime);
                                if (picked == null) return;
                                setDialogState(() => endDateTime = picked);
                              }
                            : null,
                        icon: const Icon(Icons.edit_calendar),
                      ),
                    ),

                    const SizedBox(height: 8),
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
    final canEditAsync = ref.watch(canEditTripDateTimeProvider);

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: _tripStream(),
      builder: (context, tripSnap) {
        // ✅ trata erro do stream
        if (tripSnap.hasError) {
          return Scaffold(
            appBar: AppBar(title: const Text('Viagem')),
            body: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Erro ao carregar trip: ${tripSnap.error}',
                style: const TextStyle(color: Colors.red),
              ),
            ),
          );
        }

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

        // ✅ Operacional
        final startAt = trip['startAt'];
        final endAt = trip['endAt'];

        final origin = (trip['origin'] as Map<String, dynamic>?) ?? {};
        final endLoc = (trip['endLocation'] as Map<String, dynamic>?) ?? {};

        final vehicle = (trip['vehicle'] as Map<String, dynamic>?) ?? {};
        final vModel = Fmt.cleanStr(vehicle['model']);
        final vPlate = Fmt.cleanStr(vehicle['plate']);
        final vehicleStr = [
          vModel,
          vPlate,
        ].where((x) => x.isNotEmpty).join(' • ');
        final vehicleLabel = vehicleStr.isEmpty
            ? 'Veículo não informado'
            : vehicleStr;

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
              // ✅ Topo claro com status + veículo
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
                          '🚗 $vehicleLabel',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // ✅ Mini resumo quando em andamento
              if (isOpen) ...[
                const SizedBox(height: 8),
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.info_outline),
                    title: const Text('Resumo rápido'),
                    subtitle: Text(
                      'Saída: ${Fmt.dateTimeFromTimestamp(startAt)}\n'
                      'Km inicial: ${Fmt.km(startKm)}',
                    ),
                  ),
                ),
              ],

              const SizedBox(height: 12),

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

              StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: _stopsStreamAsc(),
                builder: (context, stopsSnap) {
                  if (stopsSnap.hasError) {
                    return Text(
                      'Erro ao carregar paradas: ${stopsSnap.error}',
                      style: const TextStyle(color: Colors.red),
                    );
                  }
                  if (!stopsSnap.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final stops = stopsSnap.data!.docs;
                  if (stops.isEmpty) return const Text('Nenhuma parada ainda.');

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
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.summarize),
                    title: const Text(
                      'Resumo',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      'Total rodado: $totalKm km\nVeículo: $vehicleLabel',
                    ),
                  ),
                ),
              ] else ...[
                const Divider(),
                const SizedBox(height: 8),
                canEditAsync.when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Text('Erro permissões: $e'),
                  data: (canEdit) => SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _closingTrip
                          ? null
                          : () => _closeTripDialog(
                              origin: origin,
                              canEditDt: canEdit,
                              startOdometerKm: (startKm is int)
                                  ? startKm
                                  : int.tryParse('$startKm') ?? 0,
                            ),
                      icon: const Icon(Icons.flag_circle),
                      label: const Text(
                        'Finalizar viagem (entrega do veículo)',
                      ),
                    ),
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
