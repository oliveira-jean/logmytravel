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
                          decoration: const InputDecoration(labelText: 'País'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: stateCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Estado',
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
                    decoration: const InputDecoration(labelText: 'Local'),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: noteCtrl,
                    decoration: const InputDecoration(labelText: 'Observação'),
                  ),

                  if (err != null) ...[
                    const SizedBox(height: 8),
                    Text(err!, style: const TextStyle(color: Colors.red)),
                  ],

                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: loading ? null : save,
                      child: Text(loading ? 'Salvando...' : 'Salvar parada'),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // ======================
  // CLOSE TRIP (DIALOG)
  // ======================
  Future<void> _closeTripDialog() async {
    final endKmCtrl = TextEditingController();
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
                setDialogState(() => err = 'Informe o km final.');
                return;
              }

              setDialogState(() {
                loading = true;
                err = null;
              });

              // try {
              //   await ref
              //       .read(tripsRepoProvider)
              //       .closeTrip(tripId: widget.tripId, endOdometerKm: endKm);

              //   if (!mounted) return;

              //   // 1) Fecha o dialog SEM usar ctx (evita warning do linter)
              //   Navigator.of(context, rootNavigator: true).pop();

              //   // 2) Feedback ainda nesta tela (context válido)
              //   ScaffoldMessenger.of(context).showSnackBar(
              //     const SnackBar(content: Text('Viagem finalizada ✅')),
              //   );

              //   // 3) Volta para Home
              //   Navigator.of(context).pop();
              // } catch (e) {
              //   setDialogState(() {
              //     loading = false;
              //     err = 'Erro: $e';
              //   });
              // }

              try {
                await ref
                    .read(tripsRepoProvider)
                    .closeTrip(tripId: widget.tripId, endOdometerKm: endKm);

                if (!mounted) return;
                Navigator.of(ctx).pop();
                Navigator.of(context).pop();

                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Viagem finalizada ✅')),
                );
              } catch (e) {
                setDialogState(() {
                  loading = false;
                  err = 'Erro: $e';
                });
              }
            }

            return AlertDialog(
              title: const Text('Finalizar viagem'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: endKmCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Km final'),
                  ),
                  if (err != null) ...[
                    const SizedBox(height: 8),
                    Text(err!, style: const TextStyle(color: Colors.red)),
                  ],
                ],
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
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: _tripStream(),
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final trip = snap.data!.data()!;
        final isOpen = trip['status'] == 'open';

        return Scaffold(
          appBar: AppBar(title: const Text('Detalhes da viagem')),
          floatingActionButton: isOpen
              ? FloatingActionButton(
                  onPressed: _openAddStopSheet,
                  child: const Icon(Icons.add_location_alt),
                )
              : null,
          body: ListView(
            padding: const EdgeInsets.all(12),
            children: [
              Text('Status: ${trip['status']}'),
              const SizedBox(height: 8),
              Text('Km inicial: ${Fmt.km(trip['startOdometerKm'])}'),
              Text('Km final: ${Fmt.km(trip['endOdometerKm'])}'),
              const Divider(),

              const Text(
                'Paradas',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              StreamBuilder(
                stream: _stopsStream(),
                builder: (context, stopsSnap) {
                  if (!stopsSnap.hasData) {
                    return const CircularProgressIndicator();
                  }
                  return Column(
                    children: stopsSnap.data!.docs.map((d) {
                      final s = d.data();
                      final loc = s['location'];
                      return ListTile(
                        leading: const Icon(Icons.flag),
                        title: Text('${loc['city']} • ${loc['place']}'),
                        subtitle: Text(Fmt.dateTimeFromTimestamp(s['at'])),
                      );
                    }).toList(),
                  );
                },
              ),

              if (isOpen) ...[
                const Divider(),
                ElevatedButton(
                  onPressed: _closeTripDialog,
                  child: const Text('Finalizar viagem'),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}
