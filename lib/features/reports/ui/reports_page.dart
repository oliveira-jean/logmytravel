import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../profile/data/profile_repo_provider.dart';
import '../../trips/data/trips_providers.dart';
import '../../trips/ui/trip_detail_page.dart';

class ReportsPage extends ConsumerStatefulWidget {
  const ReportsPage({super.key});

  @override
  ConsumerState<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends ConsumerState<ReportsPage> {
  DateTimeRange? _range;
  String _status = 'all'; // all|open|closed
  String _vehicleFilter = ''; // simples (placa/model) - MVP
  bool _loading = false;
  String? _err;
  List<Map<String, dynamic>> _rows = const [];

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    // padrão: últimos 7 dias
    _range = DateTimeRange(
      start: now.subtract(const Duration(days: 7)),
      end: now,
    );
  }

  String _fmtDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  String _fmtDateTime(dynamic ts) {
    if (ts == null) return '—';
    try {
      final dt = ts.toDate();
      return '${_fmtDate(dt)} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return '—';
    }
  }

  int _toInt(dynamic v) {
    if (v is int) return v;
    return int.tryParse('$v') ?? 0;
  }

  int _calcKm(Map<String, dynamic> t) {
    final a = _toInt(t['startOdometerKm']);
    final b = t['endOdometerKm'];
    if (b == null) return 0;
    final end = _toInt(b);
    if (end < a) return 0;
    return end - a;
  }

  String _vehicleLabel(Map<String, dynamic> t) {
    final v = (t['vehicle'] as Map?) ?? {};
    final model = (v['model'] ?? '').toString().trim();
    final plate = (v['plate'] ?? '').toString().trim();
    final out = [model, plate].where((x) => x.isNotEmpty).join(' • ');
    return out.isEmpty ? '—' : out;
  }

  String _originLabel(Map<String, dynamic> t) {
    final o = (t['origin'] as Map?) ?? {};
    final state = (o['state'] ?? '').toString().trim();
    final city = (o['city'] ?? '').toString().trim();
    final place = (o['place'] ?? '').toString().trim();
    final head = state.isEmpty ? '' : state;
    final tail = [city, place].where((x) => x.isNotEmpty).join(' • ');
    return [head, tail].where((x) => x.isNotEmpty).join(' • ');
  }

  bool _passesVehicleFilter(Map<String, dynamic> t) {
    final q = _vehicleFilter.trim().toLowerCase();
    if (q.isEmpty) return true;
    final v = (t['vehicle'] as Map?) ?? {};
    final model = (v['model'] ?? '').toString().toLowerCase();
    final plate = (v['plate'] ?? '').toString().toLowerCase();
    return model.contains(q) || plate.contains(q);
  }

  Future<void> _pickRange() async {
    final initial = _range;
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      initialDateRange: initial,
    );
    if (picked == null) return;
    setState(() => _range = picked);
  }

  Future<void> _run() async {
    final range = _range;
    if (range == null) return;

    setState(() {
      _loading = true;
      _err = null;
    });

    try {
      final profileSnap = await ref.read(myProfileProvider.future);
      final p = profileSnap.data() as Map<String, dynamic>? ?? {};
      final accountType = (p['accountType'] ?? 'individual').toString();
      final companyId = (p['companyId'] ?? '').toString();
      final uid = profileSnap.id;

      final ownerType = accountType;
      final ownerId = (accountType == 'corporate') ? companyId : uid;

      final repo = ref.read(tripsRepoProvider);

      final rows = await repo.queryTripsForOwner(
        ownerType: ownerType,
        ownerId: ownerId,
        startDate: range.start,
        endDate: range.end,
        status: _status,
      );

      // filtro por veículo (MVP client-side)
      final filtered = rows.where(_passesVehicleFilter).toList();

      setState(() => _rows = filtered);
    } catch (e) {
      setState(() => _err = 'Erro ao gerar relatório: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _buildCsv(List<Map<String, dynamic>> rows) {
    final header = [
      'tripId',
      'status',
      'startAt',
      'endAt',
      'vehicleModel',
      'vehiclePlate',
      'origin',
      'startKm',
      'endKm',
      'totalKm',
    ];

    String esc(String s) {
      // CSV básico: aspas duplas e quebra de linha
      final x = s.replaceAll('"', '""');
      return '"$x"';
    }

    final lines = <String>[];
    lines.add(header.map(esc).join(','));

    for (final t in rows) {
      final id = (t['id'] ?? '').toString();
      final status = (t['status'] ?? '').toString();
      final startAt = _fmtDateTime(t['startAt']);
      final endAt = _fmtDateTime(t['endAt']);

      final v = (t['vehicle'] as Map?) ?? {};
      final model = (v['model'] ?? '').toString();
      final plate = (v['plate'] ?? '').toString();

      final origin = _originLabel(t);
      final startKm = (t['startOdometerKm'] ?? '').toString();
      final endKm = (t['endOdometerKm'] ?? '').toString();
      final totalKm = _calcKm(t).toString();

      final row = [
        id,
        status,
        startAt,
        endAt,
        model,
        plate,
        origin,
        startKm,
        endKm,
        totalKm,
      ];

      lines.add(row.map((x) => esc(x.toString())).join(','));
    }

    return lines.join('\n');
  }

  Future<void> _exportCsv() async {
    if (_rows.isEmpty) return;

    final csv = _buildCsv(_rows);

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Exportar CSV'),
        content: SizedBox(
          width: 520,
          child: SingleChildScrollView(child: SelectableText(csv)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Fechar'),
          ),
          ElevatedButton.icon(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: csv));
              if (!mounted) return;
              Navigator.of(ctx).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('CSV copiado ✅ (cole no Excel/Sheets)'),
                ),
              );
            },
            icon: const Icon(Icons.copy),
            label: const Text('Copiar CSV'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final range = _range;

    int totalTrips = _rows.length;
    int totalKm = 0;
    for (final t in _rows) {
      totalKm += _calcKm(t);
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Relatórios')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Filtros',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 10),

                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.date_range),
                    title: Text(
                      range == null
                          ? 'Selecione um período'
                          : '${_fmtDate(range.start)} → ${_fmtDate(range.end)}',
                    ),
                    trailing: TextButton(
                      onPressed: _pickRange,
                      child: const Text('Alterar'),
                    ),
                  ),

                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: _status,
                          items: const [
                            DropdownMenuItem(
                              value: 'all',
                              child: Text('Status: Todos'),
                            ),
                            DropdownMenuItem(
                              value: 'open',
                              child: Text('Status: Abertas'),
                            ),
                            DropdownMenuItem(
                              value: 'closed',
                              child: Text('Status: Fechadas'),
                            ),
                          ],
                          onChanged: (v) =>
                              setState(() => _status = v ?? 'all'),
                          decoration: const InputDecoration(
                            labelText: 'Status',
                            prefixIcon: Icon(Icons.filter_alt),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          decoration: const InputDecoration(
                            labelText: 'Veículo (placa/modelo)',
                            prefixIcon: Icon(Icons.directions_car),
                          ),
                          onChanged: (v) => setState(() => _vehicleFilter = v),
                        ),
                      ),
                    ],
                  ),

                  if (_err != null) ...[
                    const SizedBox(height: 10),
                    Text(_err!, style: const TextStyle(color: Colors.red)),
                  ],

                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _loading ? null : _run,
                          icon: const Icon(Icons.analytics),
                          label: Text(
                            _loading ? 'Gerando...' : 'Gerar relatório',
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: (_rows.isEmpty || _loading)
                              ? null
                              : _exportCsv,
                          icon: const Icon(Icons.download),
                          label: const Text('Exportar CSV'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 12),

          Card(
            child: ListTile(
              leading: const Icon(Icons.summarize),
              title: const Text('Totais'),
              subtitle: Text(
                'Viagens: $totalTrips\nKm total (fechadas): $totalKm',
              ),
            ),
          ),

          const SizedBox(height: 12),
          const Text(
            'Resultados',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),

          if (_rows.isEmpty)
            const Card(
              child: ListTile(
                leading: Icon(Icons.info_outline),
                title: Text('Sem resultados'),
                subtitle: Text(
                  'Ajuste os filtros e toque em “Gerar relatório”.',
                ),
              ),
            )
          else
            ..._rows.map((t) {
              final id = (t['id'] ?? '').toString();
              final status = (t['status'] ?? '').toString();
              final km = _calcKm(t);
              final title =
                  '${status == 'open' ? 'ABERTA' : 'FECHADA'} • ${_vehicleLabel(t)}';
              final subtitle =
                  '${_originLabel(t)}\nSaída: ${_fmtDateTime(t['startAt'])}'
                  '${status == 'closed' ? '\nKm: $km' : ''}';

              return Card(
                child: ListTile(
                  leading: Icon(
                    status == 'open'
                        ? Icons.directions_car
                        : Icons.check_circle,
                  ),
                  title: Text(title),
                  subtitle: Text(subtitle),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => TripDetailPage(tripId: id),
                      ),
                    );
                  },
                ),
              );
            }),
        ],
      ),
    );
  }
}
