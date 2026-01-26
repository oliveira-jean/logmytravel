import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ProfileRepo {
  ProfileRepo({
    required FirebaseFirestore firestore,
    required FirebaseAuth auth,
  }) : _fs = firestore,
       _auth = auth;

  final FirebaseFirestore _fs;
  final FirebaseAuth _auth;

  Stream<DocumentSnapshot<Map<String, dynamic>>> myProfile() {
    final u = _auth.currentUser;
    if (u == null) {
      // stream vazio
      return const Stream.empty();
    }
    return _fs.collection('users').doc(u.uid).snapshots();
  }
}
