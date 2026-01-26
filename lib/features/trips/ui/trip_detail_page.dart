import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/trips_providers.dart';

class TripDetailPage extends ConsumerStatefulWidget {
  const TripDetailPage({super.key, required this.tripId});

  final String tripId;

  @override
  ConsumerState<TripDetailPage> createState() => _TripDetailPageState();
}

class _TripDetailPageState extends ConsumerState<TripDetailPage> {
  final _countryCtrl = TextEditingController(text: 'BR');
  final _stateCtrl = TextEditingController(text: 'CE');
  final _cityCtrl = TextEditingController();
  final _placeCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();

  final _endKmCtrl = TextEditingController();

  bool _loading = false;
  String? _err;

  @override
  void dispose() {
    _countryCtrl.dispose();
    _stateCtrl.dispose();
    _cityCtrl.dispose();
    _placeCtrl.dispose();
    _noteCtrl.dispose();
    _endKmCtrl.dispose();
    super.dispose();
  }

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

  Future<void> _addStop() async {
    setState(() {
      _loading = true;
      _err = null;
    });

    try {
      if (_cityCtrl.text.trim().isEmpty)
        throw Exception('Informe a cidade da parada.');

      await ref
          .read(tripsRepoProvider)
          .addStop(
            tripId: widget.tripId,
            location: {
              'country': _countryCtrl.text.trim().toUpperCase(),
              'state': _stateCtrl.text.trim().toUpperCase(),
              'city': _cityCtrl.text.trim(),
              'place': _placeCtrl.text.trim(),
            },
            note: _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim(),
          );

      _placeCtrl.clear();
      _noteCtrl.clear();
      _cityCtrl.clear();
    } catch (e) {
      setState(() => _err = 'Erro: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _closeTrip() async {
    setState(() {
      _loading = true;
      _err = null;
    });

    try {
      final endKm = int.tryParse(_endKmCtrl.text.trim());
      if (endKm == null) throw Exception('Informe km final (número).');

      await ref
          .read(tripsRepoProvider)
          .closeTrip(tripId: widget.tripId, endOdometerKm: endKm);

      if (!mounted) return;
      Navigator.of(context).pop(); // volta para home
    } catch (e) {
      setState(() => _err = 'Erro: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final err = _err;

    return Scaffold(
      appBar: AppBar(title: Text('Viagem ${widget.tripId.substring(0, 6)}')),
      body: StreamBuilder(
        stream: _tripStream(),
        builder: (context, tripSnap) {
          final trip = tripSnap.data?.data();
          final status = trip?['status']?.toString() ?? '...';

          return Padding(
            padding: const EdgeInsets.all(12),
            child: ListView(
              children: [
                Card(
                  child: ListTile(
                    title: Text('Status: $status'),
                    subtitle: Text('TripId: ${widget.tripId}'),
                  ),
                ),

                const SizedBox(height: 8),
                const Text(
                  'Adicionar parada',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),

                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _countryCtrl,
                        decoration: const InputDecoration(labelText: 'País'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _stateCtrl,
                        decoration: const InputDecoration(
                          labelText: 'UF/Estado',
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _cityCtrl,
                  decoration: const InputDecoration(labelText: 'Cidade'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _placeCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Local (ex: Hospital X)',
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _noteCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Observação (opcional)',
                  ),
                ),

                const SizedBox(height: 8),
                if (err != null) ...[
                  Text(err, style: const TextStyle(color: Colors.red)),
                  const SizedBox(height: 8),
                ],
                ElevatedButton(
                  onPressed: _loading ? null : _addStop,
                  child: Text(_loading ? 'Salvando...' : 'Adicionar parada'),
                ),

                const SizedBox(height: 16),
                const Text(
                  'Paradas',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),

                StreamBuilder(
                  stream: _stopsStream(),
                  builder: (context, stopsSnap) {
                    final stops = stopsSnap.data?.docs ?? [];
                    if (stopsSnap.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (stops.isEmpty)
                      return const Text('Nenhuma parada ainda.');

                    return Column(
                      children: stops.map((d) {
                        final s = d.data();
                        final loc = s['location'] as Map<String, dynamic>?;
                        final city = loc?['city'] ?? '';
                        final place = loc?['place'] ?? '';
                        final note = (s['note'] ?? '').toString();

                        return Card(
                          child: ListTile(
                            title: Text('$city • $place'),
                            subtitle: note.isEmpty ? null : Text(note),
                          ),
                        );
                      }).toList(),
                    );
                  },
                ),

                const SizedBox(height: 16),
                const Divider(),
                const Text(
                  'Finalizar viagem',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _endKmCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Km final'),
                ),
                const SizedBox(height: 8),
                ElevatedButton(
                  onPressed: _loading ? null : _closeTrip,
                  child: Text(_loading ? 'Finalizando...' : 'Finalizar'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
