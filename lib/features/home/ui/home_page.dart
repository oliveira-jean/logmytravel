import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/data/auth_providers.dart';

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  Future<void> _logout(WidgetRef ref) async {
    final auth = ref.read(firebaseAuthProvider);
    await auth.signOut();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(authStateChangesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Log My Travel'),
        actions: [
          IconButton(
            onPressed: () => _logout(ref),
            icon: const Icon(Icons.logout),
            tooltip: 'Sair',
          )
        ],
      ),
      body: Center(
        child: userAsync.when(
          data: (user) => Text(
            'Logado ✅\n\nUID:\n${user?.uid}\n\nE-mail:\n${user?.email ?? "(sem e-mail)"}',
            textAlign: TextAlign.center,
          ),
          loading: () => const CircularProgressIndicator(),
          error: (e, _) => Text('Erro: $e'),
        ),
      ),
    );
  }
}
