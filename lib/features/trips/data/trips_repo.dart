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
    required Timestamp startAt, // ✅ operacional (editável quando permitido)
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

      // ✅ Auditoria servidor
      'startAtServer': FieldValue.serverTimestamp(),
      'endAtServer': null,

      // ✅ Operacional (pode ser editável)
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
    required Timestamp endAt, // ✅ operacional (editável quando permitido)
  }) async {
    final tripRef = _fs.collection('trips').doc(tripId);
    await tripRef.update({
      'status': 'closed',

      // ✅ Auditoria servidor
      'endAtServer': FieldValue.serverTimestamp(),

      // ✅ Operacional
      'endAt': endAt,

      'endOdometerKm': endOdometerKm,
      'endLocation': endLocation,
    });
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> listTripsForOwner({
    required String ownerType,
    required String ownerId,
  }) {
    // ordena pela data operacional
    return _fs
        .collection('trips')
        .where('ownerType', isEqualTo: ownerType)
        .where('ownerId', isEqualTo: ownerId)
        .orderBy('startAt', descending: true)
        .snapshots();
  }

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
}

// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:firebase_auth/firebase_auth.dart';

// class TripsRepo {
//   TripsRepo({required FirebaseFirestore firestore, required FirebaseAuth auth})
//     : _fs = firestore,
//       _auth = auth;

//   final FirebaseFirestore _fs;
//   final FirebaseAuth _auth;

//   Future<String> startTrip({
//     required Map<String, dynamic> owner, // {ownerType, ownerId}
//     required int startOdometerKm,
//     required Map<String, String> origin, // {country,state,city,place}
//     required Timestamp startAt, // ✅ operacional (editável quando permitido)
//     Map<String, String>? vehicle,
//   }) async {
//     final user = _auth.currentUser;
//     if (user == null) throw Exception('Usuário não autenticado');

//     final tripRef = _fs.collection('trips').doc();

//     await tripRef.set({
//       'ownerType': owner['ownerType'],
//       'ownerId': owner['ownerId'],
//       'createdByUid': user.uid,
//       'status': 'open',

//       // ✅ Auditoria (sempre servidor)
//       'startAtServer': FieldValue.serverTimestamp(),
//       'endAtServer': null,

//       // ✅ Operacional (pode ser editável)
//       'startAt': startAt,
//       'endAt': null,

//       'startOdometerKm': startOdometerKm,
//       'endOdometerKm': null,

//       'origin': origin,
//       'endLocation': null,
//       'vehicle': vehicle,
//     });

//     return tripRef.id;
//   }

//   Future<void> addStop({
//     required String tripId,
//     required Map<String, String> location,
//     String? note,
//   }) async {
//     final stopRef = _fs
//         .collection('trips')
//         .doc(tripId)
//         .collection('stops')
//         .doc();
//     await stopRef.set({
//       'at': FieldValue.serverTimestamp(),
//       'location': location,
//       'note': note,
//     });
//   }

//   Future<void> closeTrip({
//     required String tripId,
//     required int endOdometerKm,
//     required Map<String, String> endLocation,
//     required Timestamp endAt, // ✅ operacional (editável quando permitido)
//   }) async {
//     final tripRef = _fs.collection('trips').doc(tripId);
//     await tripRef.update({
//       'status': 'closed',

//       // ✅ Auditoria servidor
//       'endAtServer': FieldValue.serverTimestamp(),

//       // ✅ Operacional editável
//       'endAt': endAt,

//       'endOdometerKm': endOdometerKm,
//       'endLocation': endLocation,
//     });
//   }

//   Stream<QuerySnapshot<Map<String, dynamic>>> listTripsForOwner({
//     required String ownerType,
//     required String ownerId,
//   }) {
//     return _fs
//         .collection('trips')
//         .where('ownerType', isEqualTo: ownerType)
//         .where('ownerId', isEqualTo: ownerId)
//         .orderBy('startAt', descending: true)
//         .snapshots();
//   }

//   Future<String?> getOpenTripId({
//     required String ownerType,
//     required String ownerId,
//   }) async {
//     final q = await _fs
//         .collection('trips')
//         .where('ownerType', isEqualTo: ownerType)
//         .where('ownerId', isEqualTo: ownerId)
//         .where('status', isEqualTo: 'open')
//         .limit(1)
//         .get();

//     if (q.docs.isEmpty) return null;
//     return q.docs.first.id;
//   }
// }

// // import 'package:cloud_firestore/cloud_firestore.dart';
// // import 'package:firebase_auth/firebase_auth.dart';

// // class TripsRepo {
// //   TripsRepo({required FirebaseFirestore firestore, required FirebaseAuth auth})
// //     : _fs = firestore,
// //       _auth = auth;

// //   final FirebaseFirestore _fs;
// //   final FirebaseAuth _auth;

// //   Future<String> startTrip({
// //     required Map<String, dynamic> owner, // {ownerType, ownerId}
// //     required int startOdometerKm,
// //     required Map<String, String> origin, // {country,state,city,place}
// //     Map<String, String>? vehicle,
// //   }) async {
// //     final user = _auth.currentUser;
// //     if (user == null) throw Exception('Usuário não autenticado');

// //     final tripRef = _fs.collection('trips').doc();

// //     await tripRef.set({
// //       'ownerType': owner['ownerType'],
// //       'ownerId': owner['ownerId'],
// //       'createdByUid': user.uid,
// //       'status': 'open',
// //       'startAt': FieldValue.serverTimestamp(),
// //       'endAt': null,
// //       'startOdometerKm': startOdometerKm,
// //       'endOdometerKm': null,
// //       'origin': origin,
// //       'endLocation': null,
// //       'vehicle': vehicle,
// //     });

// //     return tripRef.id;
// //   }

// //   Future<void> addStop({
// //     required String tripId,
// //     required Map<String, String> location,
// //     String? note,
// //   }) async {
// //     final stopRef = _fs
// //         .collection('trips')
// //         .doc(tripId)
// //         .collection('stops')
// //         .doc();
// //     await stopRef.set({
// //       'at': FieldValue.serverTimestamp(),
// //       'location': location,
// //       'note': note,
// //     });
// //   }

// //   Future<void> closeTrip({
// //     required String tripId,
// //     required int endOdometerKm,
// //     required Map<String, String> endLocation,
// //   }) async {
// //     final tripRef = _fs.collection('trips').doc(tripId);
// //     await tripRef.update({
// //       'status': 'closed',
// //       'endAt': FieldValue.serverTimestamp(),
// //       'endOdometerKm': endOdometerKm,
// //       'endLocation': endLocation,
// //     });
// //   }

// //   Stream<QuerySnapshot<Map<String, dynamic>>> listTripsForOwner({
// //     required String ownerType,
// //     required String ownerId,
// //   }) {
// //     return _fs
// //         .collection('trips')
// //         .where('ownerType', isEqualTo: ownerType)
// //         .where('ownerId', isEqualTo: ownerId)
// //         .orderBy('startAt', descending: true)
// //         .snapshots();
// //   }

// //   /// ✅ Retorna o ID da viagem aberta (se existir), senão null
// //   Future<String?> getOpenTripId({
// //     required String ownerType,
// //     required String ownerId,
// //   }) async {
// //     final q = await _fs
// //         .collection('trips')
// //         .where('ownerType', isEqualTo: ownerType)
// //         .where('ownerId', isEqualTo: ownerId)
// //         .where('status', isEqualTo: 'open')
// //         .limit(1)
// //         .get();

// //     if (q.docs.isEmpty) return null;
// //     return q.docs.first.id;
// //   }
// // }
