import 'package:flutter_test/flutter_test.dart';
import 'package:able_app/core/utils/platform_utils.dart';
import 'package:able_app/data/models/download_record.dart';
import 'package:able_app/data/models/media_format.dart';
import 'package:able_app/data/models/media_item.dart';

void main() {
  group('Data Models Unit Tests', () {
    test('MediaFormat fromJson and toJson work correctly', () {
      final json = {
        'id': 'video_hd',
        'label': 'HD PRO',
        'quality': '1080p',
        'type': 'video',
        'ext': 'mp4',
        'url': 'https://example.com/video.mp4',
        'filesize': 25000000,
        'hasAudio': true,
        'noWatermark': true,
      };

      final format = MediaFormat.fromJson(json);
      expect(format.id, 'video_hd');
      expect(format.label, 'HD PRO');
      expect(format.isVideo, isTrue);
      expect(format.isAudio, isFalse);
      expect(format.noWatermark, isTrue);

      final outJson = format.toJson();
      expect(outJson['id'], 'video_hd');
      expect(outJson['quality'], '1080p');
    });

    test('MediaItem fromJson parses platforms and formats properly', () {
      final json = {
        'success': true,
        'id': 'tt_123456',
        'platform': 'tiktok',
        'title': 'Cyberpunk City Timelapse',
        'author': {
          'name': 'NatureVids',
          'username': '@naturevids',
          'avatar': 'https://example.com/avatar.jpg'
        },
        'thumbnail': 'https://example.com/thumb.jpg',
        'duration': '00:45',
        'durationSeconds': 45,
        'formats': [
          {
            'id': 'video_hd',
            'label': 'HD PRO',
            'quality': '1080p',
            'type': 'video',
            'ext': 'mp4',
            'url': 'https://example.com/hd.mp4',
            'noWatermark': true
          },
          {
            'id': 'audio_mp3',
            'label': 'Audio',
            'quality': 'Original',
            'type': 'audio',
            'ext': 'mp3',
            'url': 'https://example.com/audio.mp3'
          }
        ]
      };

      final item = MediaItem.fromJson(json, originalUrl: 'https://tiktok.com/@test/123');
      expect(item.platform, SocialPlatform.tiktok);
      expect(item.title, 'Cyberpunk City Timelapse');
      expect(item.author.name, 'NatureVids');
      expect(item.formats.length, 2);
      expect(item.hdFormat?.id, 'video_hd');
      expect(item.audioFormat?.id, 'audio_mp3');
      expect(item.originalUrl, 'https://tiktok.com/@test/123');
    });

    test('DownloadRecord serializes and deserializes', () {
      final now = DateTime.now();
      final record = DownloadRecord(
        id: 'rec_1',
        title: 'Skate Edit',
        filePath: '/path/to/skate.mp4',
        thumbnail: 'https://example.com/thumb.jpg',
        platform: 'instagram',
        fileSize: 18000000,
        duration: '01:12',
        format: 'mp4',
        quality: 'HD',
        downloadedAt: now,
      );

      expect(record.socialPlatform, SocialPlatform.instagram);
      expect(record.isAudio, isFalse);

      final map = record.toMap();
      final restored = DownloadRecord.fromMap(map);
      expect(restored.id, record.id);
      expect(restored.title, record.title);
      expect(restored.fileSize, record.fileSize);
    });
  });
}
