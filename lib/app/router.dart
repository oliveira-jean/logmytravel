import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/ui/login_page.dart';
import '../features/auth/ui/splash_page.dart';
import '../features/home/ui/home_page.dart';
import '../features/profile/ui/onboarding_mode_page.dart';
import 'router_refresh.dart';

final routerRefreshProvider = Provider<RouterRefresh>((ref) {
  final rr = RouterRefresh();
  ref.onDispose(rr.dispose);
  return rr;
});

final appRouterProvider = Provider<GoRouter>((ref) {
  final rr = ref.watch(routerRefreshProvider);

  return GoRouter(
    refreshListenable: rr,
    initialLocation: '/splash',
    routes: [
      GoRoute(path: '/splash', builder: (context, state) => const SplashPage()),
      GoRoute(path: '/login', builder: (context, state) => const LoginPage()),
      GoRoute(
        path: '/onboarding',
        builder: (context, state) => const OnboardingModePage(),
      ),
      GoRoute(path: '/home', builder: (context, state) => const HomePage()),
    ],
    redirect: (context, state) {
      final loc = state.matchedLocation;

      // 1) Se não logado -> sempre vai pro login (não deixa preso em splash)
      if (rr.user == null) {
        return (loc == '/login') ? null : '/login';
      }

      // 2) Logado, mas perfil ainda carregando -> fica na splash
      if (rr.profileLoading) {
        return (loc == '/splash') ? null : '/splash';
      }

      // 3) Se deu erro lendo perfil -> manda para onboarding (para não travar)
      if (rr.profileError != null) {
        return (loc == '/onboarding') ? null : '/onboarding';
      }

      // 4) Se perfil não existe -> onboarding
      if (!rr.profileExists) {
        return (loc == '/onboarding') ? null : '/onboarding';
      }

      // 5) Perfil existe -> manda home (e evita ficar em login/onboarding/splash)
      if (loc == '/login' || loc == '/onboarding' || loc == '/splash') {
        return '/home';
      }

      return null;
    },
  );
});
