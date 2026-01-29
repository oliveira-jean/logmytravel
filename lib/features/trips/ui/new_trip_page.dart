import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../companies/data/company_settings_provider.dart';
import '../../profile/data/profile_repo_provider.dart';
import '../../vehicles/data/vehicles_providers.dart';
import '../../vehicles/ui/vehicles_page.dart';
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

  DateTime _startDateTime = DateTime.now();

  bool _loading = false;
  String? _err;

  // Veículo selecionado
  String? _selectedVehicleId;
  Map<String, dynamic>? _selectedVehicleData;

  @override
  void dispose() {
    _startKmCtrl.dispose();
    _countryCtrl.dispose();
    _stateCtrl.dispose();
    _cityCtrl.dispose();
    _placeCtrl.dispose();
    super.dispose();
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

  Future<void> _startTrip({
    required bool canEditDt,
    required String accountType,
    required String companyId,
  }) async {
    setState(() {
      _loading = true;
      _err = null;
    });

    try {
      final repo = ref.read(tripsRepoProvider);

      // Regra: apenas 1 viagem aberta
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

      // Veículo obrigatório
      if (_selectedVehicleId == null || _selectedVehicleData == null) {
        throw Exception('Selecione um veículo.');
      }
      final v = _selectedVehicleData!;
      final vModel = (v['model'] ?? '').toString().trim();
      final vPlate = (v['plate'] ?? '').toString().trim();

      if (vModel.isEmpty || vPlate.isEmpty) {
        throw Exception('Veículo inválido (modelo/placa). Cadastre novamente.');
      }

      final startAt = Timestamp.fromDate(
        canEditDt ? _startDateTime : DateTime.now(),
      );

      final tripId = await repo.startTrip(
        owner: {'ownerType': widget.ownerType, 'ownerId': widget.ownerId},
        startOdometerKm: startKm,
        startAt: startAt,
        origin: <String, dynamic>{
          'country': _countryCtrl.text.trim().toUpperCase(),
          'state': _stateCtrl.text.trim().toUpperCase(),
          'city': _cityCtrl.text.trim(),
          'place': _placeCtrl.text.trim(),
        },

        vehicle: <String, dynamic>{
          'id': _selectedVehicleId!, // ✅ garantido antes por validação
          'model': vModel,
          'plate': vPlate,
          'scope': accountType == 'corporate' ? 'company' : 'user',
          'companyId': accountType == 'corporate' ? companyId : null,
        },
        // vehicle: {
        //   'id': _selectedVehicleId,
        //   'model': vModel,
        //   'plate': vPlate,
        //   // útil p/ painel futuramente:
        //   'scope': accountType == 'corporate' ? 'company' : 'user',
        //   'companyId': accountType == 'corporate' ? companyId : null,
        // },
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

    // Perfil (pra saber individual/corporate e companyId)
    final profileAsync = ref.watch(myProfileProvider);
    final canEditAsync = ref.watch(canEditTripDateTimeProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Nova viagem'),
        actions: [
          IconButton(
            tooltip: 'Veículos',
            onPressed: () {
              Navigator.of(
                context,
              ).push(MaterialPageRoute(builder: (_) => const VehiclesPage()));
            },
            icon: const Icon(Icons.directions_car),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: profileAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Erro profile: $e')),
          data: (snap) {
            final p = snap.data() as Map<String, dynamic>? ?? {};
            final accountType = (p['accountType'] ?? 'individual').toString();
            final companyId = (p['companyId'] ?? '').toString();

            final vehiclesStream = ref
                .read(vehiclesRepoProvider)
                .listVehicles(accountType: accountType, companyId: companyId);

            return ListView(
              children: [
                const Text(
                  'Veículo (obrigatório)',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),

                StreamBuilder(
                  stream: vehiclesStream,
                  builder: (context, s) {
                    if (!s.hasData) return const LinearProgressIndicator();

                    final docs = s.data!.docs;

                    if (docs.isEmpty) {
                      return Card(
                        child: ListTile(
                          leading: const Icon(Icons.warning_amber),
                          title: const Text('Nenhum veículo cadastrado'),
                          subtitle: const Text(
                            'Cadastre um veículo para iniciar uma viagem.',
                          ),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const VehiclesPage(),
                              ),
                            );
                          },
                        ),
                      );
                    }

                    // Se ainda não tem selecionado, seleciona o primeiro (UX boa)
                    if (_selectedVehicleId == null) {
                      _selectedVehicleId = docs.first.id;
                      _selectedVehicleData = docs.first.data();
                    }

                    return DropdownButtonFormField<String>(
                      value: _selectedVehicleId,
                      items: [
                        for (final d in docs)
                          DropdownMenuItem(
                            value: d.id,
                            child: Text(
                              '${(d.data()['model'] ?? '')} • ${(d.data()['plate'] ?? '')}',
                            ),
                          ),
                      ],
                      onChanged: _loading
                          ? null
                          : (id) {
                              final doc = docs.firstWhere((x) => x.id == id);
                              setState(() {
                                _selectedVehicleId = id;
                                _selectedVehicleData = doc.data();
                              });
                            },
                      decoration: const InputDecoration(
                        labelText: 'Selecione o veículo',
                        border: OutlineInputBorder(),
                      ),
                    );
                  },
                ),

                const SizedBox(height: 16),
                const Text(
                  'Origem',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _countryCtrl,
                        decoration: const InputDecoration(
                          labelText: 'País (ISO)',
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _stateCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Estado/UF',
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
                    onPressed: _loading
                        ? null
                        : () => _startTrip(
                            canEditDt: true,
                            accountType: accountType,
                            companyId: companyId,
                          ),
                    child: Text(_loading ? 'Validando...' : 'Iniciar viagem'),
                  ),
                  data: (canEdit) => ElevatedButton(
                    onPressed: _loading
                        ? null
                        : () => _startTrip(
                            canEditDt: canEdit,
                            accountType: accountType,
                            companyId: companyId,
                          ),
                    child: Text(_loading ? 'Validando...' : 'Iniciar viagem'),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
