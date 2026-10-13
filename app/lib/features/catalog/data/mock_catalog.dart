import 'dart:ui';

import '../domain/catalog_models.dart';
import 'catalog_repository.dart';

/// Тестовый каталог до появления API (этап 2): по продукту каждого типа,
/// как на макетах. Названия в квадратных скобках — места для настоящих данных.
class MockCatalogRepository implements CatalogRepository {
  MockCatalogRepository({this.latency = const Duration(milliseconds: 250)});

  final Duration latency;

  @override
  Future<List<Album>> albums() async {
    await Future<void>.delayed(latency);
    return mockAlbums;
  }

  @override
  List<Album>? cached() => null;
}

int _sec(String mmss) {
  final [m, s] = mmss.split(':');
  return int.parse(m) * 60 + int.parse(s);
}

Album _songAlbum({
  required String id,
  required int number,
  required String title,
  required String subtitle,
  required CoverPlaceholder cover,
}) {
  const durations = [
    '6:40', '8:15', '7:02', '9:30', '6:55', //
    '8:48', '7:20', '10:05', '7:44', '8:10',
  ];
  final lessons = [
    for (var i = 0; i < durations.length; i++)
      Lesson(
        id: '$id-l${i + 1}',
        albumId: id,
        order: i + 1,
        title: '[Песня ${i + 1}]',
        durationSec: _sec(durations[i]),
        isFreePreview: i == 0,
        materialId: '$id-m${i + 1}',
        videoKey: 'videos/$id-l${i + 1}.mp4',
      ),
  ];
  return Album(
    id: id,
    type: AlbumType.songAlbum,
    activationNumber: number,
    title: title,
    subtitle: subtitle,
    level: Level.intermediate,
    cover: cover,
    lessons: lessons,
    materials: [
      for (final l in lessons)
        StudyMaterial(
          id: l.materialId!,
          albumId: id,
          lessonId: l.id,
          title: l.title,
          pages: 3,
        ),
    ],
  );
}

Album _single({
  required String id,
  required int number,
  required String title,
  required String artist,
  required CoverPlaceholder cover,
}) {
  return Album(
    id: id,
    type: AlbumType.single,
    activationNumber: number,
    title: title,
    subtitle: artist,
    level: Level.intermediate,
    cover: cover,
    lessons: [
      Lesson(
        id: '$id-l1',
        albumId: id,
        order: 1,
        title: title,
        durationSec: _sec('7:15'),
        previewLimitSec: 45,
        materialId: '$id-m1',
        videoKey: 'videos/$id-l1.mp4',
      ),
    ],
    materials: [
      StudyMaterial(
        id: '$id-m1',
        albumId: id,
        lessonId: '$id-l1',
        title: title,
        pages: 2,
      ),
    ],
  );
}

final List<Album> mockAlbums = () {
  const courseId = 'course-basics';
  const courseTitles = [
    'Как держать гитару', 'Настройка гитары', 'Первые аккорды', //
    'Смена аккордов', 'Ритм и бой', 'Перебор', 'Читаем табулатуру',
    'Баррэ', 'Первая песня', 'Итоговый урок',
  ];
  const courseDurations = [
    '5:20', '6:10', '9:40', '8:05', '10:15', //
    '9:30', '7:45', '11:20', '12:00', '8:30',
  ];
  final course = Album(
    id: courseId,
    type: AlbumType.course,
    activationNumber: 1,
    title: 'Гитара с нуля',
    subtitle: '[Имя музыканта]',
    level: Level.beginner,
    cover: const CoverPlaceholder(Color(0xFF2B3A35), Color(0xFFA9C7BC)),
    lessons: [
      for (var i = 0; i < courseTitles.length; i++)
        Lesson(
          id: '$courseId-l${i + 1}',
          albumId: courseId,
          order: i + 1,
          title: courseTitles[i],
          durationSec: _sec(courseDurations[i]),
          isFreePreview: i == 0,
          videoKey: 'videos/$courseId-l${i + 1}.mp4',
        ),
    ],
    materials: const [
      StudyMaterial(
        id: '$courseId-m1',
        albumId: courseId,
        title: 'Материалы курса',
        subtitle: 'Аккорды, схемы, упражнения',
        pages: 3,
      ),
    ],
  );

  return [
    course,
    _songAlbum(
      id: 'album-daler',
      number: 2,
      title: 'Далер Назаров',
      subtitle: 'Песни Далера Назарова',
      cover: const CoverPlaceholder(Color(0xFF3A2A1A), Color(0xFFE8C08A)),
    ),
    _songAlbum(
      id: 'album-muborakshoh',
      number: 3,
      title: 'Муборакшох',
      subtitle: 'Песни Муборакшох',
      cover: const CoverPlaceholder(Color(0xFF3B2430), Color(0xFFE3AFC4)),
    ),
    // Песня из альбома Далера Назарова, проданная отдельно:
    // открывается только своим ключом, ключ альбома её не открывает.
    _single(
      id: 'single-1',
      number: 4,
      title: '[Песня 1]',
      artist: 'Далер Назаров',
      cover: const CoverPlaceholder(Color(0xFF33291F), Color(0xFFE0A040)),
    ),
    _single(
      id: 'single-2',
      number: 5,
      title: '[Песня 2]',
      artist: 'Муборакшох',
      cover: const CoverPlaceholder(Color(0xFF2A2F24), Color(0xFFB7C98A)),
    ),
    _single(
      id: 'single-3',
      number: 6,
      title: '[Песня 3]',
      artist: '[Исполнитель]',
      cover: const CoverPlaceholder(Color(0xFF2E2638), Color(0xFFC3AEE0)),
    ),
  ];
}();
