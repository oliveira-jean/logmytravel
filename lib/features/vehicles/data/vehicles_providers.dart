import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/firebase/firestore_providers.dart';
import '../../auth/data/auth_providers.dart';
import 'vehicles_repo.dart';

final vehiclesRepoProvider = Provider<VehiclesRepo>((ref) {
  return VehiclesRepo(
    firestore: ref.read(firestoreProvider),
    auth: ref.read(firebaseAuthProvider),
  );
});
