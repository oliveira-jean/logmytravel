import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../companies/data/company_settings_provider.dart';
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

  // Origem
  final _countryCtrl = TextEditingController(text: 'BR');
  final _stateCtrl = TextEditingController(text: 'CE');
  final _cityCtrl = TextEditingController();
  final _placeCtrl = TextEditingController(text: 'Saída');

  // Veículo obrigatório
  final _vehicleModelCtrl = TextEditingController();
  final _vehiclePlateCtrl = TextEditingController();

  DateTime _startDateTime = DateTime.now();

  bool _loading = false;
  String? _err;

  @override
  void dispose() {
    _startKmCtrl.dispose();
    _countryCtrl.dispose();
    _stateCtrl.dispose();
    _cityCtrl.dispose();
    _placeCtrl.dispose();
    _vehicleModelCtrl.dispose();
    _vehiclePlateCtrl.dispose();
    super.dispose();
  }

  String _normalizePlate(String v) {
    return v.trim().toUpperCase().replaceAll(' ', '').replaceAll('-', '');
  }

  Future<void> _pickStartDateTime() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _startDateTime,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (date == null) return;

    if (!mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_startDateTime),
    );
    if (time == null) return;

    setState(() {
      _startDateTime = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
    });
  }

  String _fmtDt(DateTime dt) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(dt.day)}/${two(dt.month)}/${dt.year} ${two(dt.hour)}:${two(dt.minute)}';
  }

  Future<void> _startTrip(bool canEditDt) async {
    setState(() {
      _loading = true;
      _err = null;
    });

    try {
      final repo = ref.read(tripsRepoProvider);

      // Regra A2: não cria se já tem trip open
      final openTripId = await repo.getOpenTripId(
        ownerType: widget.ownerType,
        ownerId: widget.ownerId,
      );

      if (!mounted) return;

      if (openTripId != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Já existe uma viagem em andamento. Continue ou finalize.',
            ),
          ),
        );
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => TripDetailPage(tripId: openTripId)),
        );
        return;
      }

      final startKm = int.tryParse(_startKmCtrl.text.trim());
      if (startKm == null) throw Exception('Informe km inicial (número).');
      if (_cityCtrl.text.trim().isEmpty)
        throw Exception('Informe a cidade de origem.');

      final model = _vehicleModelCtrl.text.trim();
      final plate = _normalizePlate(_vehiclePlateCtrl.text);

      if (model.isEmpty) throw Exception('Informe o modelo do veículo.');
      if (plate.isEmpty) throw Exception('Informe a placa do veículo.');

      // ✅ Individual: editável. Corporate: depende. Mas mesmo se não puder editar,
      // a gente grava o valor auto (DateTime.now()).
      final startAt = Timestamp.fromDate(
        canEditDt ? _startDateTime : DateTime.now(),
      );

      final tripId = await repo.startTrip(
        owner: {'ownerType': widget.ownerType, 'ownerId': widget.ownerId},
        startOdometerKm: startKm,
        startAt: startAt,
        origin: {
          'country': _countryCtrl.text.trim().toUpperCase(),
          'state': _stateCtrl.text.trim().toUpperCase(),
          'city': _cityCtrl.text.trim(),
          'place': _placeCtrl.text.trim(),
        },
        vehicle: {'model': model, 'plate': plate},
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
    final canEditAsync = ref.watch(canEditTripDateTimeProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Nova viagem')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            const Text(
              'Veículo (obrigatório)',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _vehicleModelCtrl,
              decoration: const InputDecoration(
                labelText: 'Modelo (ex: Voyage)',
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _vehiclePlateCtrl,
              decoration: const InputDecoration(
                labelText: 'Placa (ex: ABC1D23)',
              ),
            ),

            const SizedBox(height: 16),
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
              decoration: const InputDecoration(
                labelText: 'Local (ex: Empresa/Casa)',
              ),
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
            const Text(
              'Data/Hora de saída',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),

            canEditAsync.when(
              loading: () => const Text('Carregando permissões...'),
              error: (e, _) => Text('Erro permissões: $e'),
              data: (canEdit) {
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(_fmtDt(_startDateTime)),
                  subtitle: Text(
                    canEdit
                        ? 'Editável (conforme plano)'
                        : 'Travado pela empresa (será usado horário automático)',
                  ),
                  trailing: IconButton(
                    onPressed: (canEdit && !_loading)
                        ? _pickStartDateTime
                        : null,
                    icon: const Icon(Icons.edit_calendar),
                  ),
                );
              },
            ),

            const SizedBox(height: 16),
            if (err != null) ...[
              Text(err, style: const TextStyle(color: Colors.red)),
              const SizedBox(height: 12),
            ],

            canEditAsync.when(
              loading: () => ElevatedButton(
                onPressed: null,
                child: const Text('Aguarde...'),
              ),
              error: (_, __) => ElevatedButton(
                onPressed: _loading ? null : () => _startTrip(true), // fallback
                child: Text(_loading ? 'Validando...' : 'Iniciar viagem'),
              ),
              data: (canEdit) => ElevatedButton(
                onPressed: _loading ? null : () => _startTrip(canEdit),
                child: Text(_loading ? 'Validando...' : 'Iniciar viagem'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// import 'package:flutter/material.dart';
// import 'package:flutter_riverpod/flutter_riverpod.dart';

// import '../data/trips_providers.dart';
// import 'trip_detail_page.dart';

// class NewTripPage extends ConsumerStatefulWidget {
//   const NewTripPage({
//     super.key,
//     required this.ownerType,
//     required this.ownerId,
//   });

//   final String ownerType;
//   final String ownerId;

//   @override
//   ConsumerState<NewTripPage> createState() => _NewTripPageState();
// }

// class _NewTripPageState extends ConsumerState<NewTripPage> {
//   final _startKmCtrl = TextEditingController();

//   // Origem
//   final _countryCtrl = TextEditingController(text: 'BR');
//   final _stateCtrl = TextEditingController(text: 'CE');
//   final _cityCtrl = TextEditingController();
//   final _placeCtrl = TextEditingController(text: 'Saída');

//   // Veículo obrigatório
//   final _vehicleModelCtrl = TextEditingController();
//   final _vehiclePlateCtrl = TextEditingController();

//   bool _loading = false;
//   String? _err;

//   @override
//   void dispose() {
//     _startKmCtrl.dispose();
//     _countryCtrl.dispose();
//     _stateCtrl.dispose();
//     _cityCtrl.dispose();
//     _placeCtrl.dispose();
//     _vehicleModelCtrl.dispose();
//     _vehiclePlateCtrl.dispose();
//     super.dispose();
//   }

//   String _normalizePlate(String v) {
//     return v.trim().toUpperCase().replaceAll(' ', '').replaceAll('-', '');
//   }

//   Future<void> _startTrip() async {
//     setState(() {
//       _loading = true;
//       _err = null;
//     });

//     try {
//       final repo = ref.read(tripsRepoProvider);

//       // ✅ Regra A2: não deixa criar se já tem trip open
//       final openTripId = await repo.getOpenTripId(
//         ownerType: widget.ownerType,
//         ownerId: widget.ownerId,
//       );

//       if (!mounted) return;

//       if (openTripId != null) {
//         ScaffoldMessenger.of(context).showSnackBar(
//           const SnackBar(
//             content: Text(
//               'Já existe uma viagem em andamento. Continue ou finalize.',
//             ),
//           ),
//         );
//         Navigator.of(context).pushReplacement(
//           MaterialPageRoute(builder: (_) => TripDetailPage(tripId: openTripId)),
//         );
//         return;
//       }

//       final startKm = int.tryParse(_startKmCtrl.text.trim());
//       if (startKm == null) throw Exception('Informe km inicial (número).');
//       if (_cityCtrl.text.trim().isEmpty)
//         throw Exception('Informe a cidade de origem.');

//       final model = _vehicleModelCtrl.text.trim();
//       final plate = _normalizePlate(_vehiclePlateCtrl.text);

//       if (model.isEmpty) throw Exception('Informe o modelo do veículo.');
//       if (plate.isEmpty) throw Exception('Informe a placa do veículo.');

//       final tripId = await repo.startTrip(
//         owner: {'ownerType': widget.ownerType, 'ownerId': widget.ownerId},
//         startOdometerKm: startKm,
//         origin: {
//           'country': _countryCtrl.text.trim().toUpperCase(),
//           'state': _stateCtrl.text.trim().toUpperCase(),
//           'city': _cityCtrl.text.trim(),
//           'place': _placeCtrl.text.trim(),
//         },
//         vehicle: {'model': model, 'plate': plate},
//       );

//       if (!mounted) return;
//       Navigator.of(context).pushReplacement(
//         MaterialPageRoute(builder: (_) => TripDetailPage(tripId: tripId)),
//       );
//     } catch (e) {
//       setState(() => _err = 'Erro: $e');
//     } finally {
//       if (mounted) setState(() => _loading = false);
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     final err = _err;

//     return Scaffold(
//       appBar: AppBar(title: const Text('Nova viagem')),
//       body: Padding(
//         padding: const EdgeInsets.all(16),
//         child: ListView(
//           children: [
//             const Text(
//               'Veículo (obrigatório)',
//               style: TextStyle(fontWeight: FontWeight.bold),
//             ),
//             const SizedBox(height: 8),
//             TextField(
//               controller: _vehicleModelCtrl,
//               decoration: const InputDecoration(
//                 labelText: 'Modelo (ex: Voyage)',
//               ),
//             ),
//             const SizedBox(height: 8),
//             TextField(
//               controller: _vehiclePlateCtrl,
//               decoration: const InputDecoration(
//                 labelText: 'Placa (ex: ABC1D23)',
//               ),
//             ),

//             const SizedBox(height: 16),
//             const Text('Origem', style: TextStyle(fontWeight: FontWeight.bold)),
//             const SizedBox(height: 8),
//             Row(
//               children: [
//                 Expanded(
//                   child: TextField(
//                     controller: _countryCtrl,
//                     decoration: const InputDecoration(labelText: 'País (ISO)'),
//                   ),
//                 ),
//                 const SizedBox(width: 8),
//                 Expanded(
//                   child: TextField(
//                     controller: _stateCtrl,
//                     decoration: const InputDecoration(labelText: 'Estado/UF'),
//                   ),
//                 ),
//               ],
//             ),
//             const SizedBox(height: 8),
//             TextField(
//               controller: _cityCtrl,
//               decoration: const InputDecoration(labelText: 'Cidade'),
//             ),
//             const SizedBox(height: 8),
//             TextField(
//               controller: _placeCtrl,
//               decoration: const InputDecoration(
//                 labelText: 'Local (ex: Empresa/Casa)',
//               ),
//             ),

//             const SizedBox(height: 16),
//             const Text(
//               'Odômetro',
//               style: TextStyle(fontWeight: FontWeight.bold),
//             ),
//             const SizedBox(height: 8),
//             TextField(
//               controller: _startKmCtrl,
//               keyboardType: TextInputType.number,
//               decoration: const InputDecoration(labelText: 'Km inicial'),
//             ),

//             const SizedBox(height: 16),
//             if (err != null) ...[
//               Text(err, style: const TextStyle(color: Colors.red)),
//               const SizedBox(height: 12),
//             ],
//             ElevatedButton(
//               onPressed: _loading ? null : _startTrip,
//               child: Text(_loading ? 'Validando...' : 'Iniciar viagem'),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }
