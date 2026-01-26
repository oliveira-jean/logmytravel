import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// ChangeNotifier que "acorda" o GoRouter quando:
/// - o usuário loga/desloga (FirebaseAuth)
/// - o perfil users/{uid} muda (Firestore)
///
/// Isso evita travamento na Splash por falta de refresh do router.
class RouterRefresh extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _fs = FirebaseFirestore.instance;

  StreamSubscription<User?>? _authSub;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _profileSub;

  User? _user;
  DocumentSnapshot<Map<String, dynamic>>? _profileSnap;
  Object? _profileError;
  bool _profileLoading = false;

  RouterRefresh() {
    _user = _auth.currentUser;
    _startAuthListener();
    _startProfileListener();
  }

  User? get user => _user;

  bool get profileLoading => _profileLoading;

  bool get profileExists => _profileSnap?.exists == true;

  Object? get profileError => _profileError;

  void _startAuthListener() {
    _authSub?.cancel();
    _authSub = _auth.authStateChanges().listen((u) {
      _user = u;
      _startProfileListener();
      notifyListeners();
    });
  }

  void _startProfileListener() {
    _profileSub?.cancel();
    _profileSnap = null;
    _profileError = null;
    _profileLoading = false;

    final u = _user;
    if (u == null) {
      // Sem usuário = sem perfil
      return;
    }

    _profileLoading = true;

    final docRef = _fs.collection('users').doc(u.uid);
    _profileSub = docRef.snapshots().listen(
      (snap) {
        _profileSnap = snap;
        _profileLoading = false;
        notifyListeners();
      },
      onError: (e) {
        _profileError = e;
        _profileLoading = false;
        notifyListeners();
      },
    );
  }

  @override
  void dispose() {
    _authSub?.cancel();
    _profileSub?.cancel();
    super.dispose();
  }
}
