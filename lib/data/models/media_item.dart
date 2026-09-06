import 'media_format.dart';
import '../../core/utils/platform_utils.dart';

class MediaAuthor {
  final String name;
  final String username;
  final String avatar;

  const MediaAuthor({
    required this.name,
    required this.username,
    required this.avatar,
  });

  factory MediaAuthor.fromJson(Map<String, dynamic> json) {
    return MediaAuthor(
      name: json['name'] as String? ?? 'Creator',
      username: json['username'] as String? ?? '@creator',
      avatar: json['avatar'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'username': username,
      'avatar': avatar,
    };
  }
}

class MediaItem {
  final bool success;
  final String id;
  final SocialPlatform platform;
  final String title;
  final MediaAuthor author;
  final String thumbnail;
  final String duration;
  final int durationSeconds;
  final List<MediaFormat> formats;
  final String? originalUrl;

  const MediaItem({
    required this.success,
    required this.id,
    required this.platform,
    required this.title,
    required this.author,
    required this.thumbnail,
    required this.duration,
    required this.durationSeconds,
    required this.formats,
    this.originalUrl,
  });

  MediaFormat? get defaultVideoFormat {
    try {
      return formats.firstWhere((f) => f.isVideo);
    } catch (_) {
      return formats.isNotEmpty ? formats.first : null;
    }
  }

  MediaFormat? get hdFormat {
    try {
      return formats.firstWhere((f) => f.id.contains('hd') || f.quality.contains('1080') || f.label.contains('HD'));
    } catch (_) {
      return defaultVideoFormat;
    }
  }

  MediaFormat? get sdFormat {
    try {
      return formats.firstWhere((f) => f.id.contains('sd') || f.quality.contains('720') || f.label.contains('SD'));
    } catch (_) {
      return defaultVideoFormat;
    }
  }

  MediaFormat? get audioFormat {
    try {
      return formats.firstWhere((f) => f.isAudio);
    } catch (_) {
      return null;
    }
  }

  factory MediaItem.fromJson(Map<String, dynamic> json, {String? originalUrl}) {
    final formatList = (json['formats'] as List<dynamic>?)
            ?.map((f) => MediaFormat.fromJson(f as Map<String, dynamic>))
            .toList() ??
        [];

    return MediaItem(
      success: json['success'] as bool? ?? true,
      id: json['id'] as String? ?? 'item_${DateTime.now().millisecondsSinceEpoch}',
      platform: SocialPlatform.fromString(json['platform'] as String?),
      title: json['title'] as String? ?? 'Social Media Video',
      author: MediaAuthor.fromJson(json['author'] as Map<String, dynamic>? ?? {}),
      thumbnail: json['thumbnail'] as String? ?? '',
      duration: json['duration'] as String? ?? '00:00',
      durationSeconds: json['durationSeconds'] as int? ?? 0,
      formats: formatList,
      originalUrl: originalUrl,
    );
  }
}
