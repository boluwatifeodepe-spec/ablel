import 'package:flutter_test/flutter_test.dart';
import 'package:able_app/data/services/client_extractor.dart';

void main() {
  test('Test TikTok extraction', () async {
    final tt = await ClientExtractor.extract('https://www.tiktok.com/@scout2015/video/6718335390845095173');
    print('[TikTok] title: ${tt.title}, formats: ${tt.formats.length}, thumb: ${tt.thumbnail}');
    expect(tt.formats.isNotEmpty, true);
  }, timeout: const Timeout(Duration(seconds: 25)));

  test('Test YouTube extraction', () async {
    final yt = await ClientExtractor.extract('https://www.youtube.com/watch?v=dQw4w9WgXcQ');
    print('[YouTube] title: ${yt.title}, formats: ${yt.formats.length}, thumb: ${yt.thumbnail}');
    expect(yt.formats.isNotEmpty, true);
  }, timeout: const Timeout(Duration(seconds: 25)));

  test('Test Twitter / X extraction', () async {
    final tw = await ClientExtractor.extract('https://x.com/Twitter/status/1858179023519871096');
    print('[Twitter] title: ${tw.title}, formats: ${tw.formats.length}, thumb: ${tw.thumbnail}');
    expect(tw.formats.isNotEmpty, true);
  }, timeout: const Timeout(Duration(seconds: 25)));

  test('Test Instagram extraction', () async {
    final ig = await ClientExtractor.extract('https://www.instagram.com/reel/C_Y0zGINR-Y/');
    print('[Instagram] title: ${ig.title}, formats: ${ig.formats.length}, thumb: ${ig.thumbnail}');
    expect(ig.formats.isNotEmpty, true);
  }, timeout: const Timeout(Duration(seconds: 25)));

  test('Test Facebook extraction', () async {
    final fb = await ClientExtractor.extract('https://www.facebook.com/watch/?v=10153231379946729');
    print('[Facebook] title: ${fb.title}, formats: ${fb.formats.length}, thumb: ${fb.thumbnail}');
    expect(fb.formats.isNotEmpty, true);
  }, timeout: const Timeout(Duration(seconds: 25)));
}
