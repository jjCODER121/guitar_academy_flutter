import 'package:flutter/painting.dart';

enum AlbumType { course, songAlbum, single }

enum Level { beginner, intermediate, advanced }

/// Цвета обложки-заглушки — пока у продукта нет настоящего фото.
class CoverPlaceholder {
  const CoverPlaceholder(this.background, this.foreground);

  final Color background;
  final Color foreground;
}

class Lesson {
  const Lesson({
    required this.id,
    required this.albumId,
    required this.order,
    required this.title,
    required this.durationSec,
    this.isFreePreview = false,
    this.previewLimitSec,
    this.materialId,
    this.videoKey,
  });

  final String id;
  final String albumId;

  /// Номер в списке, с 1.
  final int order;
  final String title;
  final int durationSec;

  /// Урок целиком доступен бесплатно (первый урок курса, первая песня альбома).
  final bool isFreePreview;

  /// Бесплатен только начальный фрагмент этой длины (отдельная песня).
  final int? previewLimitSec;

  /// PDF с нотами именно этой песни.
  final String? materialId;

  /// Файл видео на сервере (null — ещё не загружено). Меняется, когда видео
  /// заменили, — тогда сохранённая на телефоне копия устарела.
  final String? videoKey;

  bool get hasPreview => isFreePreview || previewLimitSec != null;
}

class StudyMaterial {
  const StudyMaterial({
    required this.id,
    required this.albumId,
    required this.title,
    required this.pages,
    this.subtitle,
    this.lessonId,
  });

  final String id;
  final String albumId;
  final String title;
  final String? subtitle;

  /// null — материал ко всему продукту (например, PDF курса).
  final String? lessonId;
  final int pages;
}

class Album {
  const Album({
    required this.id,
    required this.type,
    required this.title,
    required this.subtitle,
    required this.level,
    required this.activationNumber,
    required this.cover,
    required this.lessons,
    this.materials = const [],
    this.coverUrl,
  });

  final String id;
  final AlbumType type;
  final String title;

  /// Одна строка: исполнитель или короткое описание.
  final String subtitle;
  final Level level;

  /// Номер продукта в алгоритме ключа активации: ключ открывает только
  /// продукт со своим номером — и никакой другой (даже песню из альбома,
  /// проданную отдельно). Задаётся в админке и не меняется.
  final int activationNumber;

  final String? coverUrl;
  final CoverPlaceholder cover;
  final List<Lesson> lessons;
  final List<StudyMaterial> materials;

  /// PDF ко всему продукту, если есть.
  StudyMaterial? get generalMaterial {
    for (final m in materials) {
      if (m.lessonId == null) return m;
    }
    return null;
  }

  StudyMaterial? material(String id) {
    for (final m in materials) {
      if (m.id == id) return m;
    }
    return null;
  }

  Lesson? lesson(String id) {
    for (final l in lessons) {
      if (l.id == id) return l;
    }
    return null;
  }

  Lesson? lessonAfter(Lesson lesson) {
    final i = lessons.indexWhere((l) => l.id == lesson.id);
    return i >= 0 && i + 1 < lessons.length ? lessons[i + 1] : null;
  }
}
