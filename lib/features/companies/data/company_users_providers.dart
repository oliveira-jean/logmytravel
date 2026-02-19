import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/firebase/firestore_providers.dart';
import '../../auth/data/auth_providers.dart';
import 'company_users_repo.dart';

final companyUsersRepoProvider = Provider<CompanyUsersRepo>((ref) {
  final fs = ref.read(firestoreProvider);
  final auth = ref.read(firebaseAuthProvider);
  return CompanyUsersRepo(firestore: fs, auth: auth);
});
