import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdfrx/pdfrx.dart';

import '../../core/l10n/gen/app_localizations.dart';
import '../../core/platform/secure_screen.dart';
import '../../core/theme/app_icons.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/common.dart';
import '../auth/auth.dart';
import '../catalog/data/catalog_repository.dart';
import '../catalog/domain/catalog_models.dart';
import '../player/media.dart';
import '../purchases/activation_flow.dart';
import '../purchases/purchases.dart';

/// Ноты на весь экран: сверху «назад» и масштаб. Файл приходит по временной
/// ссылке с сервера, только если курс активирован на этом телефоне.
class PdfScreen extends ConsumerWidget {
  const PdfScreen({super.key, required this.albumId, required this.materialId});

  final String albumId;
  final String materialId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final album = ref.watch(albumProvider(albumId));
    return Scaffold(
      body: SafeArea(
        child: AsyncView(
          value: album,
          onRetry: () => ref.invalidate(albumProvider(albumId)),
          builder: (album) {
            final material = album.material(materialId);
            final owned = ref.watch(ownedProvider).value ?? const <String>{};
            if (material == null) {
              return const Align(
                alignment: Alignment.topLeft,
                child: BackButtonRound(),
              );
            }
            if (!owned.owns(album)) return _Locked(album: album);
            return _Viewer(album: album, material: material);
          },
        ),
      ),
    );
  }
}

class _Locked extends ConsumerWidget {
  const _Locked({required this.album});

  final Album album;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(padding: EdgeInsets.all(4), child: BackButtonRound()),
        Expanded(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(AppSpace.screen),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(AppIcons.lock, size: 40, color: c.locked),
                  const SizedBox(height: AppSpace.md),
                  FilledButton(
                    onPressed: () =>
                        startActivation(context, ref, album: album),
                    child: Text(l10n.unlockWithCode),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Ссылка на PDF для этого материала (на 2 часа).
final _pdfUrlProvider = FutureProvider.autoDispose
    .family<String, ({String albumId, String materialId})>((ref, arg) async {
      final pass = await mediaPass(ref, arg.albumId);
      return ref
          .read(mediaRepositoryProvider)
          .materialUrl(arg.materialId, pass);
    });

class _Viewer extends ConsumerStatefulWidget {
  const _Viewer({required this.album, required this.material});

  final Album album;
  final StudyMaterial material;

  @override
  ConsumerState<_Viewer> createState() => _ViewerState();
}

class _ViewerState extends ConsumerState<_Viewer> {
  final _controller = PdfViewerController();
  int _page = 1;
  int _pages = 0;

  ({String albumId, String materialId}) get _arg =>
      (albumId: widget.album.id, materialId: widget.material.id);

  @override
  void initState() {
    super.initState();
    SecureScreen.acquire();
  }

  @override
  void dispose() {
    SecureScreen.release();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final l10n = AppLocalizations.of(context);
    final email = ref.watch(authProvider)?.email ?? '';
    final url = ref.watch(_pdfUrlProvider(_arg));

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(4),
          child: Row(
            children: [
              const BackButtonRound(),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  widget.material.title,
                  style: AppText.lessonTitle.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              RoundIconButton(
                icon: AppIcons.zoomOut,
                tooltip: l10n.zoomOut,
                onPressed: _pages > 0 ? () => _controller.zoomDown() : null,
              ),
              RoundIconButton(
                icon: AppIcons.zoomIn,
                tooltip: l10n.zoomIn,
                onPressed: _pages > 0 ? () => _controller.zoomUp() : null,
              ),
            ],
          ),
        ),
        Expanded(
          child: switch (url) {
            AsyncData(:final value) => Stack(
              children: [
                PdfViewer.uri(
                  Uri.parse(value),
                  controller: _controller,
                  params: PdfViewerParams(
                    backgroundColor: c.background,
                    onViewerReady: (document, _) =>
                        setState(() => _pages = document.pages.length),
                    onPageChanged: (page) {
                      if (page != null) setState(() => _page = page);
                    },
                    errorBannerBuilder:
                        (context, error, stackTrace, documentRef) => Center(
                          child: Text(
                            l10n.pdfUnavailable,
                            style: AppText.body.copyWith(
                              color: c.textSecondary,
                            ),
                          ),
                        ),
                  ),
                ),
                // Водяной знак: кому выдан доступ.
                if (email.isNotEmpty)
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 8,
                    child: IgnorePointer(
                      child: Text(
                        l10n.purchasedBy(email),
                        textAlign: TextAlign.center,
                        style: AppText.navLabel.copyWith(
                          color: c.textSecondary.withValues(alpha: 0.7),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            AsyncError() => Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    l10n.pdfUnavailable,
                    style: AppText.body.copyWith(color: c.textSecondary),
                  ),
                  const SizedBox(height: AppSpace.sm),
                  OutlinedButton(
                    onPressed: () => ref.invalidate(_pdfUrlProvider(_arg)),
                    child: Text(l10n.retry),
                  ),
                ],
              ),
            ),
            _ => const Center(child: CircularProgressIndicator()),
          },
        ),
        SizedBox(
          height: 48,
          child: Center(
            child: Text(
              _pages > 0 ? l10n.pageOf(_page, _pages) : '',
              style: AppText.caption.copyWith(
                color: c.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
