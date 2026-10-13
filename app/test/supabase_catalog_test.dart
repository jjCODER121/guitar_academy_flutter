import 'package:flutter_test/flutter_test.dart';
import 'package:guitar_school/features/catalog/data/supabase_catalog.dart';
import 'package:guitar_school/features/catalog/domain/catalog_models.dart';

void main() {
  test('строка из Supabase → модель приложения', () {
    final row = {
      'id': 'p1',
      'type': 'course',
      'title': 'Гитараи Хусрав',
      'subtitle': '',
      'level': 'beginner',
      'activation_number': 1,
      'cover_path': 'p1/cover.jpg',
      'lessons': [
        {
          'id': 'l1',
          'position': 1,
          'title': 'Как держать гитару',
          'duration_sec': 233,
          'is_free_preview': false,
          'preview_limit_sec': null,
          'video_key': 'videos/a.mp4',
        },
        {
          'id': 'l2',
          'position': 2,
          'title': 'Как играть на гитаре',
          'duration_sec': 233,
          'is_free_preview': true,
          'preview_limit_sec': null,
          'video_key': 'videos/b.mp4',
        },
      ],
      'materials': [
        {'id': 'm1', 'title': 'Аккорды', 'lesson_id': null, 'position': 1},
        {'id': 'm2', 'title': 'Ноты', 'lesson_id': 'l2', 'position': 2},
      ],
    };
    final album = albumFromRow(row, (path) => 'https://cdn/$path');

    expect(album.type, AlbumType.course);
    expect(album.activationNumber, 1);
    expect(album.coverUrl, 'https://cdn/p1/cover.jpg');
    expect(album.lessons.map((l) => l.order), [1, 2]);
    expect(album.lessons[1].isFreePreview, isTrue);
    expect(album.lessons[0].materialId, isNull);
    expect(album.lessons[1].materialId, 'm2');
    expect(album.generalMaterial?.title, 'Аккорды');
  });

  test('отдельная песня без обложки', () {
    final row = {
      'id': 's1',
      'type': 'single',
      'title': '[Песня 1]',
      'subtitle': 'Далер Назаров',
      'level': 'intermediate',
      'activation_number': 4,
      'cover_path': null,
      'lessons': <Map<String, dynamic>>[],
      'materials': <Map<String, dynamic>>[],
    };
    final album = albumFromRow(row, (_) => null);
    expect(album.type, AlbumType.single);
    expect(album.level, Level.intermediate);
    expect(album.coverUrl, isNull);
  });
}
