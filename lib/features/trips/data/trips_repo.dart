import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class TripsRepo {
  TripsRepo({required FirebaseFirestore firestore, required FirebaseAuth auth})
    : _fs = firestore,
      _auth = auth;

  final FirebaseFirestore _fs;
  final FirebaseAuth _auth;

  /// Retorna o ID da viagem aberta (status == 'open') para o owner.
  /// Usado para bloquear múltiplas viagens.
  Future<String?> getOpenTripId({
    required String ownerType,
    required String ownerId,
  }) async {
    final q = await _fs
        .collection('trips')
        .where('ownerType', isEqualTo: ownerType)
        .where('ownerId', isEqualTo: ownerId)
        .where('status', isEqualTo: 'open')
        .limit(1)
        .get();

    if (q.docs.isEmpty) return null;
    return q.docs.first.id;
  }

  /// ✅ C2: traz dados da viagem aberta (para mostrar veículo na Home)
  Future<Map<String, dynamic>?> getOpenTrip({
    required String ownerType,
    required String ownerId,
  }) async {
    final q = await _fs
        .collection('trips')
        .where('ownerType', isEqualTo: ownerType)
        .where('ownerId', isEqualTo: ownerId)
        .where('status', isEqualTo: 'open')
        .limit(1)
        .get();

    if (q.docs.isEmpty) return null;

    final doc = q.docs.first;
    final data = doc.data();
    return <String, dynamic>{'id': doc.id, ...data};
  }

  Future<String> startTrip({
    required Map<String, dynamic> owner, // {ownerType, ownerId}
    required int startOdometerKm,
    required Timestamp startAt, // operacional (editável quando permitido)
    required Map<String, dynamic> origin,
    required Map<String, dynamic> vehicle,
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('Usuário não autenticado');

    final tripRef = _fs.collection('trips').doc();

    await tripRef.set({
      'ownerType': owner['ownerType'],
      'ownerId': owner['ownerId'],
      'createdByUid': user.uid,
      'status': 'open',

      // Auditoria servidor
      'startAtServer': FieldValue.serverTimestamp(),
      'endAtServer': null,

      // Operacional
      'startAt': startAt,
      'endAt': null,

      'startOdometerKm': startOdometerKm,
      'endOdometerKm': null,

      'origin': origin,
      'endLocation': null,
      'vehicle': vehicle,
    });

    return tripRef.id;
  }

  Future<void> addStop({
    required String tripId,
    required Map<String, String> location,
    String? note,
  }) async {
    final stopRef = _fs
        .collection('trips')
        .doc(tripId)
        .collection('stops')
        .doc();

    await stopRef.set({
      'at': FieldValue.serverTimestamp(),
      'location': location,
      'note': note,
    });
  }

  Future<void> closeTrip({
    required String tripId,
    required int endOdometerKm,
    required Map<String, String> endLocation,
    required Timestamp endAt, // operacional (editável quando permitido)
  }) async {
    final tripRef = _fs.collection('trips').doc(tripId);
    await tripRef.update({
      'status': 'closed',
      'endAtServer': FieldValue.serverTimestamp(),
      'endAt': endAt,
      'endOdometerKm': endOdometerKm,
      'endLocation': endLocation,
    });
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> listTripsForOwner({
    required String ownerType,
    required String ownerId,
  }) {
    return _fs
        .collection('trips')
        .where('ownerType', isEqualTo: ownerType)
        .where('ownerId', isEqualTo: ownerId)
        .orderBy('startAt', descending: true)
        .snapshots();
  }

  /// ✅ C3: consulta por período (e opcional status) para relatórios
  ///
  /// Dica: para Firestore, isso pode exigir índice composto:
  /// ownerType + ownerId + startAt (orderBy) + status (se usado)
  Future<List<Map<String, dynamic>>> queryTripsForOwner({
    required String ownerType,
    required String ownerId,
    required DateTime startDate,
    required DateTime endDate,
    String status = 'all', // 'all'|'open'|'closed'
  }) async {
    final start = DateTime(
      startDate.year,
      startDate.month,
      startDate.day,
      0,
      0,
    );
    final end = DateTime(
      endDate.year,
      endDate.month,
      endDate.day,
      23,
      59,
      59,
      999,
    );

    Query<Map<String, dynamic>> q = _fs
        .collection('trips')
        .where('ownerType', isEqualTo: ownerType)
        .where('ownerId', isEqualTo: ownerId)
        .where('startAt', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('startAt', isLessThanOrEqualTo: Timestamp.fromDate(end))
        .orderBy('startAt', descending: true);

    if (status != 'all') {
      q = q.where('status', isEqualTo: status);
    }

    final snap = await q.get();

    return snap.docs
        .map((d) => <String, dynamic>{'id': d.id, ...d.data()})
        .toList();
  }
}
