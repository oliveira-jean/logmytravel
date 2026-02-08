import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/firebase/firestore_providers.dart';
import '../../auth/data/auth_providers.dart';
import 'company_codes_repo.dart';

final companyCodesRepoProvider = Provider<CompanyCodesRepo>((ref) {
  final fs = ref.read(firestoreProvider);
  final auth = ref.read(firebaseAuthProvider);
  return CompanyCodesRepo(firestore: fs, auth: auth);
});
