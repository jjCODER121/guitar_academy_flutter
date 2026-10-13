import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/l10n/fallback_localizations.dart';
import 'core/l10n/gen/app_localizations.dart';
import 'core/l10n/locale_provider.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_mode_provider.dart';
import 'features/offline/offline_videos.dart';

class GuitarSchoolApp extends ConsumerWidget {
  const GuitarSchoolApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Скачивание досмотренных уроков работает всё время, пока открыто приложение.
    ref.listen(offlineProvider, (_, _) {});
    return MaterialApp.router(
      onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ref.watch(themeModeProvider),
      locale: ref.watch(localeProvider),
      localizationsDelegates: const [
        ...AppLocalizations.localizationsDelegates,
        ...fallbackLocalizationsDelegates,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      routerConfig: ref.watch(routerProvider),
    );
  }
}
