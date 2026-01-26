import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class TripsRepo {
  TripsRepo({required FirebaseFirestore firestore, required FirebaseAuth auth})
    : _fs = firestore,
      _auth = auth;

  final FirebaseFirestore _fs;
  final FirebaseAuth _auth;

  Future<String> startTrip({
    required Map<String, dynamic> owner, // {ownerType, ownerId}
    required int startOdometerKm,
    required Map<String, String> origin, // {country,state,city,place}
    Map<String, String>? vehicle,
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('Usuário não autenticado');

    final tripRef = _fs.collection('trips').doc();

    await tripRef.set({
      'ownerType': owner['ownerType'],
      'ownerId': owner['ownerId'],
      'createdByUid': user.uid,
      'status': 'open',
      'startAt': FieldValue.serverTimestamp(),
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
    required Map<String, String> endLocation, // ✅ novo
  }) async {
    final tripRef = _fs.collection('trips').doc(tripId);
    await tripRef.update({
      'status': 'closed',
      'endAt': FieldValue.serverTimestamp(),
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
}
