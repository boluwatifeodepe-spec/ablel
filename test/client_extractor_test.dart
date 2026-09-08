import 'package:flutter_test/flutter_test.dart';
import 'package:able_app/data/services/client_extractor.dart';

void main() {
  group('ClientExtractor Unit Tests', () {
    test('sanitizeUrl cleans trailing punctuation and extracts URLs', () {
      expect(
        ClientExtractor.sanitizeUrl('Check this out: https://vm.tiktok.com/ZN82eaEnd,'),
        'https://vm.tiktok.com/ZN82eaEnd',
      );

      expect(
        ClientExtractor.sanitizeUrl('https://x.com/user/status/1234567890?s=20;'),
        'https://x.com/user/status/1234567890?s=20',
      );

      expect(
        ClientExtractor.sanitizeUrl('Watch: (https://youtu.be/dQw4w9WgXcQ)'),
        'https://youtu.be/dQw4w9WgXcQ',
      );

      expect(
        ClientExtractor.sanitizeUrl('https://www.instagram.com/reel/C3_abc123/'),
        'https://www.instagram.com/reel/C3_abc123/',
      );
    });

    test('detectPlatform correctly identifies supported platforms', () {
      expect(ClientExtractor.detectPlatform('https://vm.tiktok.com/ZN82eaEnd'), 'tiktok');
      expect(ClientExtractor.detectPlatform('https://www.tiktok.com/@user/video/123'), 'tiktok');
      expect(ClientExtractor.detectPlatform('https://x.com/user/status/123'), 'twitter');
      expect(ClientExtractor.detectPlatform('https://twitter.com/user/status/123'), 'twitter');
      expect(ClientExtractor.detectPlatform('https://www.instagram.com/reel/C3_abc123/'), 'instagram');
      expect(ClientExtractor.detectPlatform('https://youtu.be/dQw4w9WgXcQ'), 'youtube');
      expect(ClientExtractor.detectPlatform('https://www.facebook.com/watch/?v=123'), 'facebook');
      expect(ClientExtractor.detectPlatform('https://otherplatform.com/video'), 'unknown');
    });
  });
}
