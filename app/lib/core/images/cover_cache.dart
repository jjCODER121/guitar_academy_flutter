import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

/// Обложки и баннеры продуктов на телефоне — видны и без интернета.
///
/// Каждая картинка скачивается один раз и хранится в папке приложения.
/// Адрес обложки меняется, когда в админке загружают новое фото, поэтому
/// копия по адресу не устаревает. После загрузки каталога [sync] заранее
/// скачивает все обложки и удаляет те, что больше не нужны.
class CoverCache {
  CoverCache({Future<Directory> Function()? root, HttpClient? http})
    : _root = root ?? _defaultRoot,
      _http = http ?? HttpClient();

  static final instance = CoverCache();

  static Future<Directory> _defaultRoot() async {
    final base = await getApplicationSupportDirectory();
    return Directory('${base.path}/covers');
  }

  final Future<Directory> Function() _root;
  final HttpClient _http;
  Future<Directory>? _dir;
  final _loading = <String, Future<Uint8List>>{};

  Future<Directory> get _directory =>
      _dir ??= _root().then((d) => d.create(recursive: true));

  static String _name(String url) => sha1.convert(utf8.encode(url)).toString();

  /// Картинка: с телефона, а если её там нет — из интернета (и сохраняется).
  Future<Uint8List> load(String url) =>
      _loading[url] ??= _load(url).whenComplete(() {
        // Не `=> _loading.remove(url)`: remove вернул бы эту же загрузку,
        // и whenComplete ждал бы сам себя.
        _loading.remove(url);
      });

  Future<Uint8List> _load(String url) async {
    final file = File('${(await _directory).path}/${_name(url)}');
    if (await file.exists()) return file.readAsBytes();
    final bytes = await _download(url);
    // Сначала во временный файл: оборванная запись не оставит битую картинку.
    final tmp = File('${file.path}.tmp');
    await tmp.writeAsBytes(bytes, flush: true);
    await tmp.rename(file.path);
    return bytes;
  }

  Future<Uint8List> _download(String url) async {
    final request = await _http
        .getUrl(Uri.parse(url))
        .timeout(const Duration(seconds: 20));
    final response = await request.close().timeout(const Duration(seconds: 20));
    if (response.statusCode != HttpStatus.ok) {
      await response.drain<void>();
      throw HttpException('HTTP ${response.statusCode}', uri: Uri.parse(url));
    }
    final bytes = await consolidateHttpClientResponseBytes(response)
        .timeout(const Duration(seconds: 60));
    if (bytes.isEmpty) throw HttpException('empty', uri: Uri.parse(url));
    return bytes;
  }

  /// Скачать заранее обложки каталога и удалить ненужные.
  /// Без сети просто останется то, что уже есть.
  Future<void> sync(Iterable<String> urls) async {
    try {
      final keep = {for (final url in urls) _name(url)};
      await for (final entry in (await _directory).list()) {
        final name = entry.uri.pathSegments.last;
        if (entry is File && !keep.contains(name)) await entry.delete();
      }
      for (final url in urls) {
        try {
          await load(url);
        } catch (_) {
          // Нет сети — докачаем при следующем обновлении каталога.
        }
      }
    } catch (_) {
      // Папка недоступна (например, в тестах) — картинки просто идут из сети.
    }
  }
}

final coverCacheProvider = Provider<CoverCache>((ref) => CoverCache.instance);

/// Картинка обложки через [CoverCache]: из сохранённой копии или из сети.
@immutable
class CachedCoverImage extends ImageProvider<CachedCoverImage> {
  CachedCoverImage(this.url, {CoverCache? cache})
    : cache = cache ?? CoverCache.instance;

  final String url;
  final CoverCache cache;

  @override
  Future<CachedCoverImage> obtainKey(ImageConfiguration configuration) =>
      SynchronousFuture(this);

  @override
  ImageStreamCompleter loadImage(
    CachedCoverImage key,
    ImageDecoderCallback decode,
  ) => MultiFrameImageStreamCompleter(
    codec: _codec(decode),
    scale: 1,
    debugLabel: url,
  );

  Future<ui.Codec> _codec(ImageDecoderCallback decode) async {
    final bytes = await cache.load(url);
    return decode(await ui.ImmutableBuffer.fromUint8List(bytes));
  }

  @override
  bool operator ==(Object other) =>
      other is CachedCoverImage && other.url == url;

  @override
  int get hashCode => url.hashCode;
}
