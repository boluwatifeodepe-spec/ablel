import 'package:flutter_test/flutter_test.dart';
import 'package:able_app/data/services/client_extractor.dart';

void main() {
  group('ClientExtractor Comprehensive Tests', () {
    test('sanitizeUrl handles tricky social links', () {
      expect(
        ClientExtractor.sanitizeUrl('https://www.youtube.com/watch?v=dQw4w9WgXcQ&feature=shared,'),
        'https://www.youtube.com/watch?v=dQw4w9WgXcQ&feature=shared',
      );
      expect(
        ClientExtractor.sanitizeUrl('https://instagram.com/reel/C3_abc123/?igsh=123;'),
        'https://instagram.com/reel/C3_abc123/?igsh=123',
      );
    });

    test('detectPlatform correctly detects all 5 platforms', () {
      expect(ClientExtractor.detectPlatform('https://www.instagram.com/reel/C3_abc123/'), 'instagram');
      expect(ClientExtractor.detectPlatform('https://www.facebook.com/reel/123456789'), 'facebook');
      expect(ClientExtractor.detectPlatform('https://fb.watch/abc123/'), 'facebook');
      expect(ClientExtractor.detectPlatform('https://x.com/elonmusk/status/12345'), 'twitter');
      expect(ClientExtractor.detectPlatform('https://youtu.be/dQw4w9WgXcQ'), 'youtube');
      expect(ClientExtractor.detectPlatform('https://vm.tiktok.com/ZN82eaEnd'), 'tiktok');
    });
  });
}
