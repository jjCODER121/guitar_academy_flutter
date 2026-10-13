import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/config/school.dart';
import '../../core/l10n/gen/app_localizations.dart';
import '../../core/router/app_router.dart';
import '../../core/storage/preferences.dart';
import '../../core/theme/app_icons.dart';
import '../../core/theme/app_theme.dart';

/// Показан ли онбординг. Хранится на устройстве: экран виден один раз.
final onboardingSeenProvider = NotifierProvider<OnboardingSeen, bool>(
  OnboardingSeen.new,
);

class OnboardingSeen extends Notifier<bool> {
  static const _key = 'onboarding_seen';

  @override
  bool build() => ref.watch(sharedPreferencesProvider).getBool(_key) ?? false;

  void markSeen() {
    state = true;
    ref.read(sharedPreferencesProvider).setBool(_key, true);
  }
}

/// Фото музыканта на весь экран, затемнение снизу, одна фраза, «Начать».
class OnboardingScreen extends ConsumerWidget {
  const OnboardingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Место для фото музыканта с гитарой.
          ColoredBox(
            color: Color.alphaBlend(
              c.accent.withValues(alpha: 0.12),
              c.background,
            ),
            child: Align(
              alignment: const Alignment(0, -0.45),
              child: Icon(
                AppIcons.guitar,
                size: 220,
                color: c.accent.withValues(alpha: 0.35),
              ),
            ),
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: const [0.4, 0.75],
                colors: [c.background.withValues(alpha: 0), c.background],
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpace.md,
                0,
                AppSpace.md,
                AppSpace.lg,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    School.name.toUpperCase(),
                    style: AppText.caption.copyWith(
                      color: c.accent,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    l10n.onboardingTitle,
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: AppSpace.lg),
                  FilledButton(
                    onPressed: () {
                      ref.read(onboardingSeenProvider.notifier).markSeen();
                      context.go(Routes.home);
                    },
                    child: Text(l10n.start),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
