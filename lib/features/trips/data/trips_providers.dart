import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/firebase/firestore_providers.dart';
import '../../auth/data/auth_providers.dart';
import 'trips_repo.dart';

final tripsRepoProvider = Provider<TripsRepo>((ref) {
  final fs = ref.watch(firestoreProvider);
  final auth = ref.watch(firebaseAuthProvider);
  return TripsRepo(firestore: fs, auth: auth);
});
