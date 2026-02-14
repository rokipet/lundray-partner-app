import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'config/supabase.dart';
import 'providers/auth_provider.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';
import 'screens/receive_screen.dart';
import 'screens/ready_screen.dart';
import 'screens/earnings_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/order_detail_screen.dart';
import 'screens/process_wizard_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: supabaseUrl,
    anonKey: supabaseAnonKey,
  );

  runApp(const ProviderScope(child: LundrayPartnerApp()));
}

final _shellNavigatorKey = GlobalKey<NavigatorState>();

final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authProvider);

  return GoRouter(
    initialLocation: '/login',
    redirect: (context, state) {
      final isAuth = authState.isAuthenticated && authState.isPartner;
      final isLoginRoute = state.matchedLocation == '/login';

      if (!isAuth && !isLoginRoute) return '/login';
      if (isAuth && isLoginRoute) return '/home';
      return null;
    },
    routes: [
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      ShellRoute(
        navigatorKey: _shellNavigatorKey,
        builder: (context, state, child) => MainShell(child: child),
        routes: [
          GoRoute(
            path: '/home',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: HomeScreen(),
            ),
          ),
          GoRoute(
            path: '/receive',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: ReceiveScreen(),
            ),
          ),
          GoRoute(
            path: '/ready',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: ReadyScreen(),
            ),
          ),
          GoRoute(
            path: '/earnings',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: EarningsScreen(),
            ),
          ),
          GoRoute(
            path: '/profile',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: ProfileScreen(),
            ),
          ),
        ],
      ),
      GoRoute(
        path: '/order/:id',
        builder: (context, state) {
          final orderId = state.pathParameters['id']!;
          return OrderDetailScreen(orderId: orderId);
        },
      ),
      GoRoute(
        path: '/process/:id',
        builder: (context, state) {
          final orderId = state.pathParameters['id']!;
          return ProcessWizardScreen(orderId: orderId);
        },
      ),
    ],
  );
});

class LundrayPartnerApp extends ConsumerWidget {
  const LundrayPartnerApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: 'Lundray Partner',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF10B981),
          primary: const Color(0xFF10B981),
          secondary: const Color(0xFF7C3AED),
          surface: Colors.white,
        ),
        scaffoldBackgroundColor: Colors.white,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          foregroundColor: Color(0xFF1F2937),
          elevation: 0,
          surfaceTintColor: Colors.transparent,
        ),
        cardTheme: CardThemeData(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF10B981),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            elevation: 0,
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFF10B981), width: 2),
          ),
        ),
        useMaterial3: true,
      ),
      routerConfig: router,
    );
  }
}

class MainShell extends StatelessWidget {
  final Widget child;

  const MainShell({super.key, required this.child});

  int _currentIndex(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;
    switch (location) {
      case '/home':
        return 0;
      case '/receive':
        return 1;
      case '/ready':
        return 2;
      case '/earnings':
        return 3;
      case '/profile':
        return 4;
      default:
        return 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex(context),
        onDestinationSelected: (index) {
          switch (index) {
            case 0:
              context.go('/home');
            case 1:
              context.go('/receive');
            case 2:
              context.go('/ready');
            case 3:
              context.go('/earnings');
            case 4:
              context.go('/profile');
          }
        },
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        indicatorColor: const Color(0xFF10B981).withValues(alpha: 0.15),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home, color: Color(0xFF10B981)),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.inbox_outlined),
            selectedIcon: Icon(Icons.inbox, color: Color(0xFF10B981)),
            label: 'Receive',
          ),
          NavigationDestination(
            icon: Icon(Icons.check_circle_outline),
            selectedIcon:
                Icon(Icons.check_circle, color: Color(0xFF10B981)),
            label: 'Ready',
          ),
          NavigationDestination(
            icon: Icon(Icons.payments_outlined),
            selectedIcon: Icon(Icons.payments, color: Color(0xFF10B981)),
            label: 'Earnings',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person, color: Color(0xFF10B981)),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}
