import { describe, it } from 'node:test';
import assert from 'node:assert';
import { detectPlatform, normalizeUrl } from '../src/utils/detector.js';

describe('Detector Utility Tests', () => {
  it('should accurately detect TikTok URLs', () => {
    assert.strictEqual(detectPlatform('https://www.tiktok.com/@user/video/123456789'), 'tiktok');
    assert.strictEqual(detectPlatform('https://vm.tiktok.com/ZGd8ABCD/'), 'tiktok');
  });

  it('should accurately detect Instagram URLs', () => {
    assert.strictEqual(detectPlatform('https://www.instagram.com/reel/C3abcxyz/'), 'instagram');
    assert.strictEqual(detectPlatform('https://instagram.com/p/C3abcxyz/'), 'instagram');
  });

  it('should accurately detect YouTube URLs', () => {
    assert.strictEqual(detectPlatform('https://www.youtube.com/watch?v=dQw4w9WgXcQ'), 'youtube');
    assert.strictEqual(detectPlatform('https://youtu.be/dQw4w9WgXcQ'), 'youtube');
    assert.strictEqual(detectPlatform('https://www.youtube.com/shorts/dQw4w9WgXcQ'), 'youtube');
  });

  it('should accurately detect Twitter/X URLs', () => {
    assert.strictEqual(detectPlatform('https://x.com/user/status/123456789'), 'twitter');
    assert.strictEqual(detectPlatform('https://twitter.com/user/status/123456789'), 'twitter');
  });

  it('should accurately detect Facebook URLs', () => {
    assert.strictEqual(detectPlatform('https://www.facebook.com/reel/123456789'), 'facebook');
    assert.strictEqual(detectPlatform('https://fb.watch/123456/'), 'facebook');
  });

  it('should return unknown for unsupported domains', () => {
    assert.strictEqual(detectPlatform('https://google.com'), 'unknown');
    assert.strictEqual(detectPlatform(''), 'unknown');
  });

  it('should normalize URLs with missing protocol', () => {
    assert.strictEqual(normalizeUrl('tiktok.com/@user/video/123'), 'https://tiktok.com/@user/video/123');
    assert.strictEqual(normalizeUrl('https://instagram.com/reel/123'), 'https://instagram.com/reel/123');
  });
});
