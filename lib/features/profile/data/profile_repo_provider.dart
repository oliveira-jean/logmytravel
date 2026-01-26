import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/firebase/firestore_providers.dart';
import '../../auth/data/auth_providers.dart';
import 'profile_repo.dart';

final profileRepoProvider = Provider<ProfileRepo>((ref) {
  final fs = ref.watch(firestoreProvider);
  final auth = ref.watch(firebaseAuthProvider);
  return ProfileRepo(firestore: fs, auth: auth);
});

final myProfileProvider = StreamProvider((ref) {
  final repo = ref.watch(profileRepoProvider);
  return repo.myProfile();
});
