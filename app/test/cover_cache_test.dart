import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:guitar_school/core/images/cover_cache.dart';

/// Маленький «сервер обложек» на этом компьютере.
Future<HttpServer> _server(Map<String, List<int>> files) async {
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  server.listen((request) {
    final body = files[request.uri.path];
    request.response.statusCode = body == null ? 404 : 200;
    if (body != null) request.response.add(body);
    request.response.close();
  });
  return server;
}

void main() {
  late Directory dir;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('covers_test');
  });
  tearDown(() => dir.delete(recursive: true));

  CoverCache cache() => CoverCache(root: () async => dir);

  test('обложка скачивается один раз и потом видна без интернета', () async {
    final server = await _server({
      '/a.jpg': [1, 2, 3],
    });
    final url = 'http://127.0.0.1:${server.port}/a.jpg';

    expect(await cache().load(url), Uint8List.fromList([1, 2, 3]));
    await server.close(force: true); // интернета больше нет

    // Новый запуск приложения — картинка берётся с телефона.
    expect(await cache().load(url), Uint8List.fromList([1, 2, 3]));
  });

  test(
    'каталог обновился: новые обложки скачаны заранее, старые удалены',
    () async {
      final server = await _server({
        '/old.jpg': [9],
        '/new.jpg': [7, 7],
      });
      final base = 'http://127.0.0.1:${server.port}';
      final c = cache();
      await c.load('$base/old.jpg');

      await c.sync(['$base/new.jpg']);
      await server.close(force: true);

      expect(await cache().load('$base/new.jpg'), Uint8List.fromList([7, 7]));
      await expectLater(cache().load('$base/old.jpg'), throwsA(anything));
    },
  );

  test('ошибка сервера не оставляет битый файл', () async {
    final server = await _server({});
    final url = 'http://127.0.0.1:${server.port}/missing.jpg';
    await expectLater(cache().load(url), throwsA(isA<HttpException>()));
    await server.close(force: true);
    expect(dir.listSync(), isEmpty);
  });

  test('без папки (тесты, сбой) sync не падает', () async {
    final broken = CoverCache(
      root: () async => throw const FileSystemException(),
    );
    await broken.sync(['http://127.0.0.1:1/x.jpg']);
  });
}
