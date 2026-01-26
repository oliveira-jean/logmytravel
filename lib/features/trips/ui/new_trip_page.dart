import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/trips_providers.dart';
import 'trip_detail_page.dart';

class NewTripPage extends ConsumerStatefulWidget {
  const NewTripPage({
    super.key,
    required this.ownerType,
    required this.ownerId,
  });

  final String ownerType;
  final String ownerId;

  @override
  ConsumerState<NewTripPage> createState() => _NewTripPageState();
}

class _NewTripPageState extends ConsumerState<NewTripPage> {
  final _startKmCtrl = TextEditingController();

  // MVP: origem simples (já preparado para lista por país/estado/cidade depois)
  final _countryCtrl = TextEditingController(text: 'BR');
  final _stateCtrl = TextEditingController(text: 'CE');
  final _cityCtrl = TextEditingController();
  final _placeCtrl = TextEditingController(text: 'Saída');

  bool _loading = false;
  String? _err;

  @override
  void dispose() {
    _startKmCtrl.dispose();
    _countryCtrl.dispose();
    _stateCtrl.dispose();
    _cityCtrl.dispose();
    _placeCtrl.dispose();
    super.dispose();
  }

  Future<void> _startTrip() async {
    setState(() {
      _loading = true;
      _err = null;
    });

    try {
      final startKm = int.tryParse(_startKmCtrl.text.trim());
      if (startKm == null) throw Exception('Informe km inicial (número).');
      if (_cityCtrl.text.trim().isEmpty)
        throw Exception('Informe a cidade de origem.');

      final repo = ref.read(tripsRepoProvider);

      final tripId = await repo.startTrip(
        owner: {'ownerType': widget.ownerType, 'ownerId': widget.ownerId},
        startOdometerKm: startKm,
        origin: {
          'country': _countryCtrl.text.trim().toUpperCase(),
          'state': _stateCtrl.text.trim().toUpperCase(),
          'city': _cityCtrl.text.trim(),
          'place': _placeCtrl.text.trim(),
        },
      );

      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => TripDetailPage(tripId: tripId)),
      );
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
      appBar: AppBar(title: const Text('Nova viagem')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            const Text('Origem', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _countryCtrl,
                    decoration: const InputDecoration(labelText: 'País (ISO)'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _stateCtrl,
                    decoration: const InputDecoration(labelText: 'Estado/UF'),
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
              decoration: const InputDecoration(labelText: 'Local (opcional)'),
            ),

            const SizedBox(height: 16),
            const Text(
              'Odômetro',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _startKmCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Km inicial'),
            ),

            const SizedBox(height: 16),
            if (err != null) ...[
              Text(err, style: const TextStyle(color: Colors.red)),
              const SizedBox(height: 12),
            ],
            ElevatedButton(
              onPressed: _loading ? null : _startTrip,
              child: Text(_loading ? 'Criando...' : 'Iniciar viagem'),
            ),
          ],
        ),
      ),
    );
  }
}
