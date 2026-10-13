import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../l10n/gen/app_localizations.dart';
import '../theme/app_icons.dart';

/// Каркас с нижней панелью: Главная, Библиотека, Профиль.
/// Каждая вкладка хранит свою историю переходов.
class HomeShell extends StatelessWidget {
  const HomeShell({super.key, required this.shell});

  final StatefulNavigationShell shell;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      body: shell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: shell.currentIndex,
        onDestinationSelected: (i) =>
            shell.goBranch(i, initialLocation: i == shell.currentIndex),
        destinations: [
          NavigationDestination(
            icon: const Icon(AppIcons.house),
            label: l10n.navHome,
          ),
          NavigationDestination(
            icon: const Icon(AppIcons.libraryBig),
            label: l10n.navLibrary,
          ),
          NavigationDestination(
            icon: const Icon(AppIcons.user),
            label: l10n.navProfile,
          ),
        ],
      ),
    );
  }
}
