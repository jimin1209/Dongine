import 'package:go_router/go_router.dart';
import 'package:dongine/features/auth/presentation/login_screen.dart';
import 'package:dongine/features/family/presentation/family_setup_screen.dart';
import 'package:dongine/shared/widgets/main_shell.dart';
import 'package:dongine/features/chat/presentation/chat_screen.dart';
import 'package:dongine/features/location/presentation/location_screen.dart';
import 'package:dongine/features/files/presentation/files_screen.dart';
import 'package:dongine/features/calendar/presentation/calendar_screen.dart';
import 'package:dongine/features/cart/presentation/cart_screen.dart';
import 'package:dongine/features/expense/presentation/expense_screen.dart';
import 'package:dongine/features/auth/presentation/onboarding_screen.dart';
import 'package:dongine/features/album/presentation/album_screen.dart';
import 'package:dongine/features/album/presentation/album_detail_screen.dart';
import 'package:dongine/features/iot/presentation/iot_screen.dart';

final router = GoRouter(
  initialLocation: '/onboarding',
  routes: [
    GoRoute(
      path: '/onboarding',
      builder: (context, state) => const OnboardingScreen(),
    ),
    GoRoute(
      path: '/login',
      builder: (context, state) => const LoginScreen(),
    ),
    GoRoute(
      path: '/family-setup',
      builder: (context, state) => const FamilySetupScreen(),
    ),
    GoRoute(
      path: '/cart',
      builder: (context, state) => const CartScreen(),
    ),
    GoRoute(
      path: '/expense',
      builder: (context, state) => const ExpenseScreen(),
    ),
    GoRoute(
      path: '/album',
      builder: (context, state) => const AlbumScreen(),
    ),
    GoRoute(
      path: '/iot',
      builder: (context, state) => const IoTScreen(),
    ),
    GoRoute(
      path: '/album/:albumId',
      builder: (context, state) {
        final albumId = state.pathParameters['albumId']!;
        final familyId = state.extra as String;
        return AlbumDetailScreen(albumId: albumId, familyId: familyId);
      },
    ),
    StatefulShellRoute.indexedStack(
      builder: (context, state, navigationShell) {
        return MainShell(navigationShell: navigationShell);
      },
      branches: [
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/home',
              builder: (context, state) => const HomeTab(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/chat',
              builder: (context, state) => const ChatScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/map',
              builder: (context, state) => const LocationScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/files',
              builder: (context, state) => const FilesScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/calendar',
              builder: (context, state) => const CalendarScreen(),
            ),
          ],
        ),
      ],
    ),
  ],
);
