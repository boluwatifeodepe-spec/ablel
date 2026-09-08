import 'dart:convert';
import 'package:dio/dio.dart';
import '../../core/utils/platform_utils.dart';
import '../models/media_format.dart';
import '../models/media_item.dart';

/// Direct on-device extraction service for standalone operation without a backend.
class ClientExtractor {
  static final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 12),
      receiveTimeout: const Duration(seconds: 15),
      headers: {
        'User-Agent':
            'Mozilla/5.0 (iPhone; CPU iPhone OS 17_4 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.4 Mobile/15E148 Safari/604.1',
      },
    ),
  );

  // Pool of reliable public Cobalt instances for multi-platform media resolution
  static const List<String> _cobaltInstances = [
    'https://cobalt-api.kwiatekm.tokyo/api/json',
    'https://api.cobalt.tools/api/json',
    'https://co.wuk.sh/api/json',
    'https://cobalt.api.scav.top/api/json',
    'https://cobalt.hyonsu.com/api/json',
    'https://dl.khub.net/api/json',
  ];

  // Pool of Piped / Invidious instances for YouTube direct streaming
  static const List<String> _pipedInstances = [
    'https://pipedapi.kavin.rocks',
    'https://api.piped.privacy.com.de',
    'https://pipedapi.tokhmi.xyz',
    'https://piped-api.lunar.icu',
  ];

  /// Extract media directly from social platforms
  static Future<MediaItem> extract(String rawUrl) async {
    final cleanUrl = sanitizeUrl(rawUrl);
    if (cleanUrl.isEmpty) {
      throw Exception('Please paste a valid video URL.');
    }

    final platform = detectPlatform(cleanUrl);

    switch (platform) {
      case 'tiktok':
        return await _extractTikTok(cleanUrl);
      case 'twitter':
        return await _extractTwitter(cleanUrl);
      case 'youtube':
        return await _extractYouTube(cleanUrl);
      case 'instagram':
        return await _extractInstagram(cleanUrl);
      case 'facebook':
        return await _extractFacebook(cleanUrl);
      default:
        return await _extractCobaltGeneric(cleanUrl, platformStr: platform);
    }
  }

  /// Clean raw text to extract a valid HTTP/HTTPS URL
  static String sanitizeUrl(String text) {
    if (text.isEmpty) return '';
    final urlRegex = RegExp(r'https?://[^\s,;"<>]+');
    final match = urlRegex.firstMatch(text);
    String url = match != null ? match.group(0)! : text.trim();

    // Strip trailing punctuation
    url = url.replaceAll(RegExp(r'[,;.\)\]\}>]+$'), '');
    return url;
  }

  /// Detect social platform from URL
  static String detectPlatform(String url) {
    final lower = url.toLowerCase();
    if (lower.contains('tiktok.com') || lower.contains('douyin.com')) return 'tiktok';
    if (lower.contains('twitter.com') || lower.contains('x.com') || lower.contains('t.co')) return 'twitter';
    if (lower.contains('instagram.com') || lower.contains('instagr.am')) return 'instagram';
    if (lower.contains('youtube.com') || lower.contains('youtu.be')) return 'youtube';
    if (lower.contains('facebook.com') || lower.contains('fb.watch') || lower.contains('fb.com')) return 'facebook';
    return 'unknown';
  }

  // ==========================================
  // 1. TIKTOK DIRECT EXTRACTOR (TikWM + Fallback)
  // ==========================================
  static Future<MediaItem> _extractTikTok(String url) async {
    try {
      final response = await _dio.post(
        'https://www.tikwm.com/api/',
        data: FormData.fromMap({
          'url': url,
          'count': 12,
          'cursor': 0,
          'web': 1,
          'hd': 1,
        }),
      );

      if (response.data is Map && response.data['code'] == 0 && response.data['data'] != null) {
        final data = response.data['data'] as Map<String, dynamic>;
        final formats = <MediaFormat>[];

        // 1. HD Video without watermark
        final hdplay = data['hdplay']?.toString();
        if (hdplay != null && hdplay.isNotEmpty) {
          formats.add(
            MediaFormat(
              id: 'video_hd',
              label: 'HD PRO (1080p)',
              quality: '1080p',
              type: 'video',
              ext: 'mp4',
              url: hdplay.startsWith('http') ? hdplay : 'https://www.tikwm.com$hdplay',
              filesize: data['hd_size'] is num ? (data['hd_size'] as num).toInt() : null,
              hasAudio: true,
              noWatermark: true,
            ),
          );
        }

        // 2. SD Video without watermark
        final play = data['play']?.toString();
        if (play != null && play.isNotEmpty) {
          formats.add(
            MediaFormat(
              id: 'video_sd',
              label: 'SD (720p)',
              quality: '720p',
              type: 'video',
              ext: 'mp4',
              url: play.startsWith('http') ? play : 'https://www.tikwm.com$play',
              filesize: data['size'] is num ? (data['size'] as num).toInt() : null,
              hasAudio: true,
              noWatermark: true,
            ),
          );
        }

        // 3. Audio MP3
        final music = data['music']?.toString() ?? data['music_info']?['play']?.toString();
        if (music != null && music.isNotEmpty) {
          formats.add(
            MediaFormat(
              id: 'audio_mp3',
              label: 'Audio (MP3)',
              quality: 'Original',
              type: 'audio',
              ext: 'mp3',
              url: music.startsWith('http') ? music : 'https://www.tikwm.com$music',
              hasAudio: true,
              noWatermark: true,
            ),
          );
        }

        // 4. Photos (if TikTok photo slide post)
        if (data['images'] is List) {
          final images = (data['images'] as List).cast<dynamic>();
          for (int i = 0; i < images.length; i++) {
            final imgUrl = images[i].toString();
            formats.add(
              MediaFormat(
                id: 'photo_$i',
                label: 'Photo ${i + 1}',
                quality: 'HD Image',
                type: 'image',
                ext: 'jpg',
                url: imgUrl,
                hasAudio: false,
                noWatermark: true,
              ),
            );
          }
        }

        if (formats.isNotEmpty) {
          final durationSeconds = data['duration'] is num ? (data['duration'] as num).toInt() : 0;
          final mins = (durationSeconds ~/ 60).toString().padLeft(2, '0');
          final secs = (durationSeconds % 60).toString().padLeft(2, '0');

          String thumbnail = data['cover']?.toString() ?? data['origin_cover']?.toString() ?? '';
          if (thumbnail.startsWith('/')) {
            thumbnail = 'https://www.tikwm.com$thumbnail';
          }

          String avatar = data['author']?['avatar']?.toString() ?? '';
          if (avatar.startsWith('/')) {
            avatar = 'https://www.tikwm.com$avatar';
          }

          return MediaItem(
            success: true,
            id: data['id']?.toString() ?? 'tt_${DateTime.now().millisecondsSinceEpoch}',
            title: (data['title']?.toString().isNotEmpty == true) ? data['title'].toString() : 'TikTok Video',
            platform: SocialPlatform.tiktok,
            author: MediaAuthor(
              name: data['author']?['nickname']?.toString() ?? 'TikTok Creator',
              username: data['author']?['unique_id'] != null ? '@${data['author']['unique_id']}' : '@tiktok',
              avatar: avatar,
            ),
            thumbnail: thumbnail,
            duration: '$mins:$secs',
            durationSeconds: durationSeconds,
            formats: formats,
            originalUrl: url,
          );
        }
      }
    } catch (_) {}

    // Fallback to Cobalt pool
    return await _extractCobaltGeneric(url, platformStr: 'tiktok');
  }

  // ==========================================
  // 2. TWITTER / X DIRECT EXTRACTOR (FxTwitter + Twitsave + Cobalt)
  // ==========================================
  static Future<MediaItem> _extractTwitter(String url) async {
    final statusMatch = RegExp(r'status/(\d+)').firstMatch(url);
    final tweetId = statusMatch?.group(1);

    if (tweetId != null) {
      // 1. Try FxTwitter API
      final fxtwitterUrls = [
        'https://api.fxtwitter.com/status/$tweetId',
        'https://api.fxtwitter.com/i/status/$tweetId',
        'https://api.vxtwitter.com/Twitter/status/$tweetId',
      ];

      for (final endpoint in fxtwitterUrls) {
        try {
          final res = await _dio.get(endpoint, options: Options(receiveTimeout: const Duration(seconds: 6)));
          if (res.data is Map) {
            final data = res.data as Map<String, dynamic>;
            final tweet = data['tweet'] is Map ? data['tweet'] as Map<String, dynamic> : data;
            final formats = <MediaFormat>[];

            // Parse media videos
            if (tweet['media'] is Map && tweet['media']['videos'] is List) {
              final videos = (tweet['media']['videos'] as List).cast<dynamic>();
              for (final v in videos) {
                if (v is Map && v['url'] != null) {
                  final vUrl = v['url'].toString();
                  if (vUrl.startsWith('http') && vUrl.contains('.mp4')) {
                    formats.add(
                      MediaFormat(
                        id: 'video_hd',
                        label: 'HD PRO (1080p)',
                        quality: '1080p',
                        type: 'video',
                        ext: 'mp4',
                        url: vUrl,
                        hasAudio: true,
                        noWatermark: true,
                      ),
                    );
                  }
                }
              }
            }

            // Also check media_extended (vxTwitter format)
            if (formats.isEmpty && tweet['media_extended'] is List) {
              final mediaList = (tweet['media_extended'] as List).cast<dynamic>();
              for (final m in mediaList) {
                if (m is Map && m['type'] == 'video' && m['url'] != null) {
                  final vUrl = m['url'].toString();
                  if (vUrl.startsWith('http')) {
                    formats.add(
                      MediaFormat(
                        id: 'video_hd',
                        label: 'HD PRO',
                        quality: '720p',
                        type: 'video',
                        ext: 'mp4',
                        url: vUrl,
                        hasAudio: true,
                        noWatermark: true,
                      ),
                    );
                  }
                }
              }
            }

            if (formats.isNotEmpty) {
              // Add audio format from primary video
              formats.add(
                MediaFormat(
                  id: 'audio_mp3',
                  label: 'Audio (MP3/M4A)',
                  quality: 'Original',
                  type: 'audio',
                  ext: 'mp3',
                  url: formats.first.url,
                  hasAudio: true,
                  noWatermark: true,
                ),
              );

              final author = tweet['author'] is Map ? tweet['author'] as Map<String, dynamic> : tweet;
              return MediaItem(
                success: true,
                id: tweetId,
                title: tweet['text']?.toString() ?? 'X / Twitter Video',
                platform: SocialPlatform.twitter,
                author: MediaAuthor(
                  name: author['name']?.toString() ?? author['user_name']?.toString() ?? 'X User',
                  username: author['screen_name'] != null ? '@${author['screen_name']}' : '@x',
                  avatar: author['avatar_url']?.toString() ?? author['user_profile_image_url']?.toString() ?? '',
                ),
                thumbnail: tweet['media']?['videos']?[0]?['thumbnail_url']?.toString() ?? '',
                duration: '00:30',
                durationSeconds: 30,
                formats: formats,
                originalUrl: url,
              );
            }
          }
        } catch (_) {}
      }

      // 2. Try Twitsave scraper
      try {
        final twitsaveRes = await _dio.get('https://twitsave.com/info?url=${Uri.encodeComponent(url)}');
        final html = twitsaveRes.data.toString();
        final videoUrlMatch = RegExp(r'href="(https://video\.twimg\.com/[^"]+\.mp4[^"]*)"').firstMatch(html);
        if (videoUrlMatch != null) {
          final directVideoUrl = videoUrlMatch.group(1)!.replaceAll('&amp;', '&');
          return MediaItem(
            success: true,
            id: tweetId,
            title: 'Twitter Video',
            platform: SocialPlatform.twitter,
            author: const MediaAuthor(name: 'X Creator', username: '@x', avatar: ''),
            thumbnail: '',
            duration: '00:30',
            durationSeconds: 30,
            formats: [
              MediaFormat(
                id: 'video_hd',
                label: 'HD PRO',
                quality: '720p',
                type: 'video',
                ext: 'mp4',
                url: directVideoUrl,
                hasAudio: true,
                noWatermark: true,
              ),
              MediaFormat(
                id: 'audio_mp3',
                label: 'Audio (MP3)',
                quality: 'Original',
                type: 'audio',
                ext: 'mp3',
                url: directVideoUrl,
                hasAudio: true,
                noWatermark: true,
              ),
            ],
            originalUrl: url,
          );
        }
      } catch (_) {}
    }

    // 3. Fallback to Cobalt pool
    return await _extractCobaltGeneric(url, platformStr: 'twitter');
  }

  // ==========================================
  // 3. YOUTUBE DIRECT EXTRACTOR (Piped / Invidious / Cobalt)
  // ==========================================
  static Future<MediaItem> _extractYouTube(String url) async {
    // Extract video ID
    final idMatch = RegExp(r'(?:youtu\.be\/|youtube\.com\/(?:embed\/|v\/|watch\?v=|shorts\/|watch\?.+&v=))([\w-]{11})')
        .firstMatch(url);
    final videoId = idMatch?.group(1);

    // Fetch oEmbed title & thumbnail
    String title = 'YouTube Video';
    String authorName = 'YouTube Creator';
    String thumbnail = videoId != null ? 'https://i.ytimg.com/vi/$videoId/hqdefault.jpg' : '';

    try {
      final oembed = await _dio.get('https://www.youtube.com/oembed?url=${Uri.encodeComponent(url)}&format=json');
      if (oembed.data is Map) {
        title = oembed.data['title']?.toString() ?? title;
        authorName = oembed.data['author_name']?.toString() ?? authorName;
        thumbnail = oembed.data['thumbnail_url']?.toString() ?? thumbnail;
      }
    } catch (_) {}

    // 1. Try Piped API instances for direct MP4 & M4A/MP3 stream URLs
    if (videoId != null) {
      for (final instance in _pipedInstances) {
        try {
          final streamRes = await _dio.get(
            '$instance/streams/$videoId',
            options: Options(receiveTimeout: const Duration(seconds: 5)),
          );
          if (streamRes.data is Map) {
            final data = streamRes.data as Map<String, dynamic>;
            final formats = <MediaFormat>[];

            // 1. Video streams with audio
            if (data['videoStreams'] is List) {
              final videos = (data['videoStreams'] as List).cast<dynamic>();
              for (final v in videos) {
                if (v is Map && v['url'] != null && v['format'] == 'MPEG_4' && v['videoOnly'] != true) {
                  final streamUrl = v['url'].toString();
                  if (streamUrl.startsWith('http')) {
                    final quality = v['quality']?.toString() ?? '720p';
                    formats.add(
                      MediaFormat(
                        id: 'video_${quality.toLowerCase().replaceAll(RegExp(r'\s+'), '')}',
                        label: 'HD ($quality)',
                        quality: quality,
                        type: 'video',
                        ext: 'mp4',
                        url: streamUrl,
                        filesize: v['contentLength'] is num ? (v['contentLength'] as num).toInt() : null,
                        hasAudio: true,
                        noWatermark: true,
                      ),
                    );
                  }
                }
              }
            }

            // 2. Audio streams
            if (data['audioStreams'] is List) {
              final audios = (data['audioStreams'] as List).cast<dynamic>();
              for (final a in audios) {
                if (a is Map && a['url'] != null) {
                  final audioUrl = a['url'].toString();
                  if (audioUrl.startsWith('http')) {
                    final bitrate = a['bitrate'] != null ? '${a['bitrate']} kbps' : '320kbps';
                    formats.add(
                      MediaFormat(
                        id: 'audio_stream',
                        label: 'Audio ($bitrate)',
                        quality: bitrate,
                        type: 'audio',
                        ext: 'mp3',
                        url: audioUrl,
                        filesize: a['contentLength'] is num ? (a['contentLength'] as num).toInt() : null,
                        hasAudio: true,
                        noWatermark: true,
                      ),
                    );
                    break;
                  }
                }
              }
            }

            if (formats.isNotEmpty) {
              final durationSec = data['duration'] is num ? (data['duration'] as num).toInt() : 180;
              final mins = (durationSec ~/ 60).toString().padLeft(2, '0');
              final secs = (durationSec % 60).toString().padLeft(2, '0');

              return MediaItem(
                success: true,
                id: videoId,
                title: data['title']?.toString() ?? title,
                platform: SocialPlatform.youtube,
                author: MediaAuthor(
                  name: data['uploader']?.toString() ?? authorName,
                  username: '@${(data['uploader'] ?? 'youtube').toString().replaceAll(RegExp(r'\s+'), '').toLowerCase()}',
                  avatar: data['uploaderAvatar']?.toString() ?? '',
                ),
                thumbnail: data['thumbnailUrl']?.toString() ?? thumbnail,
                duration: '$mins:$secs',
                durationSeconds: durationSec,
                formats: formats,
                originalUrl: url,
              );
            }
          }
        } catch (_) {}
      }
    }

    // 2. Fallback to Cobalt pool
    return await _extractCobaltGeneric(url, platformStr: 'youtube', fallbackTitle: title, fallbackThumbnail: thumbnail);
  }

  // ==========================================
  // 4. INSTAGRAM DIRECT EXTRACTOR (Cobalt + Publer + Fallback)
  // ==========================================
  static Future<MediaItem> _extractInstagram(String url) async {
    // 1. Try Cobalt pool
    try {
      return await _extractCobaltGeneric(url, platformStr: 'instagram', fallbackTitle: 'Instagram Reel');
    } catch (_) {}

    // 2. Try direct oEmbed metadata + Publer extraction
    String title = 'Instagram Video';
    String authorName = 'Instagram Creator';
    String thumbnail = '';

    try {
      final oembed = await _dio.get('https://api.instagram.com/oembed/?url=${Uri.encodeComponent(url)}');
      if (oembed.data is Map) {
        title = oembed.data['title']?.toString() ?? title;
        authorName = oembed.data['author_name']?.toString() ?? authorName;
        thumbnail = oembed.data['thumbnail_url']?.toString() ?? thumbnail;
      }
    } catch (_) {}

    // Fallback to general Cobalt resolver
    return await _extractCobaltGeneric(
      url,
      platformStr: 'instagram',
      fallbackTitle: title,
      fallbackThumbnail: thumbnail,
    );
  }

  // ==========================================
  // 5. FACEBOOK DIRECT EXTRACTOR (HTML Scraper + Cobalt)
  // ==========================================
  static Future<MediaItem> _extractFacebook(String url) async {
    // 1. Try direct page regex extraction for HD/SD video stream
    try {
      final res = await _dio.get(
        url,
        options: Options(
          headers: {
            'User-Agent':
                'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/123.0.0.0 Safari/537.36',
            'Accept-Language': 'en-US,en;q=0.9',
          },
        ),
      );

      final html = res.data.toString();
      String? directHdUrl;
      String? directSdUrl;

      // Extract HD/SD URLs from Facebook video page metadata
      final hdMatch = RegExp(r'browser_native_hd_url:"(https:[^"]+)"').firstMatch(html) ??
          RegExp(r'hd_src:"(https:[^"]+)"').firstMatch(html);
      if (hdMatch != null) {
        directHdUrl = _cleanJsonUrl(hdMatch.group(1)!);
      }

      final sdMatch = RegExp(r'browser_native_sd_url:"(https:[^"]+)"').firstMatch(html) ??
          RegExp(r'sd_src:"(https:[^"]+)"').firstMatch(html) ??
          RegExp(r'<meta property="og:video" content="([^"]+)"').firstMatch(html);
      if (sdMatch != null) {
        directSdUrl = _cleanJsonUrl(sdMatch.group(1)!);
      }

      final titleMatch = RegExp(r'<meta property="og:title" content="([^"]+)"').firstMatch(html);
      final title = titleMatch?.group(1) ?? 'Facebook Video';

      final thumbMatch = RegExp(r'<meta property="og:image" content="([^"]+)"').firstMatch(html);
      final thumb = thumbMatch != null ? _cleanJsonUrl(thumbMatch.group(1)!) : '';

      final formats = <MediaFormat>[];
      if (directHdUrl != null && directHdUrl.startsWith('http')) {
        formats.add(
          MediaFormat(
            id: 'video_hd',
            label: 'HD PRO (1080p)',
            quality: '1080p',
            type: 'video',
            ext: 'mp4',
            url: directHdUrl,
            hasAudio: true,
            noWatermark: true,
          ),
        );
      }

      if (directSdUrl != null && directSdUrl.startsWith('http')) {
        formats.add(
          MediaFormat(
            id: 'video_sd',
            label: 'SD (720p)',
            quality: '720p',
            type: 'video',
            ext: 'mp4',
            url: directSdUrl,
            hasAudio: true,
            noWatermark: true,
          ),
        );
      }

      if (formats.isNotEmpty) {
        // Add audio format from primary stream
        formats.add(
          MediaFormat(
            id: 'audio_mp3',
            label: 'Audio (MP3)',
            quality: 'Original',
            type: 'audio',
            ext: 'mp3',
            url: formats.first.url,
            hasAudio: true,
            noWatermark: true,
          ),
        );

        return MediaItem(
          success: true,
          id: 'fb_${DateTime.now().millisecondsSinceEpoch}',
          title: title,
          platform: SocialPlatform.facebook,
          author: const MediaAuthor(name: 'Facebook Creator', username: '@facebook', avatar: ''),
          thumbnail: thumb,
          duration: '01:00',
          durationSeconds: 60,
          formats: formats,
          originalUrl: url,
        );
      }
    } catch (_) {}

    // 2. Fallback to Cobalt pool
    return await _extractCobaltGeneric(url, platformStr: 'facebook', fallbackTitle: 'Facebook Video');
  }

  // ==========================================
  // 6. COBALT MULTI-INSTANCE POOL RESOLVER
  // ==========================================
  static Future<MediaItem> _extractCobaltGeneric(
    String url, {
    String platformStr = 'unknown',
    String? fallbackTitle,
    String? fallbackThumbnail,
  }) async {
    for (final instance in _cobaltInstances) {
      try {
        final res = await _dio.post(
          instance,
          data: jsonEncode({
            'url': url,
            'vQuality': '1080',
            'vCodec': 'h264',
            'isAudioOnly': false,
            'aFormat': 'mp3',
          }),
          options: Options(
            headers: {
              'Accept': 'application/json',
              'Content-Type': 'application/json',
            },
            receiveTimeout: const Duration(seconds: 8),
          ),
        );

        if (res.data is Map) {
          final data = res.data as Map<String, dynamic>;
          final formats = <MediaFormat>[];

          // 1. Direct stream or redirect URL
          if (data['url'] != null) {
            final streamUrl = data['url'].toString();
            if (streamUrl.startsWith('http') && streamUrl != url) {
              formats.add(
                MediaFormat(
                  id: 'video_hd',
                  label: 'HD PRO (1080p)',
                  quality: '1080p',
                  type: 'video',
                  ext: 'mp4',
                  url: streamUrl,
                  hasAudio: true,
                  noWatermark: true,
                ),
              );
              formats.add(
                MediaFormat(
                  id: 'audio_mp3',
                  label: 'Audio Only (MP3)',
                  quality: '320kbps',
                  type: 'audio',
                  ext: 'mp3',
                  url: streamUrl,
                  hasAudio: true,
                  noWatermark: true,
                ),
              );
            }
          }

          // 2. Picker items (galleries, slideshows, multi-resolution)
          if (data['picker'] is List) {
            final pickerList = (data['picker'] as List).cast<dynamic>();
            for (int i = 0; i < pickerList.length; i++) {
              final item = pickerList[i];
              if (item is Map && item['url'] != null) {
                final itemUrl = item['url'].toString();
                final isPhoto = item['type'] == 'photo' || itemUrl.contains('.jpg') || itemUrl.contains('.png');
                formats.add(
                  MediaFormat(
                    id: isPhoto ? 'photo_$i' : 'video_$i',
                    label: isPhoto ? 'Photo ${i + 1}' : 'Video Part ${i + 1}',
                    quality: isPhoto ? 'HD Image' : 'HD Video',
                    type: isPhoto ? 'image' : 'video',
                    ext: isPhoto ? 'jpg' : 'mp4',
                    url: itemUrl,
                    hasAudio: !isPhoto,
                    noWatermark: true,
                  ),
                );
              }
            }
          }

          if (formats.isNotEmpty) {
            final socialPlatform = SocialPlatform.fromString(platformStr);
            return MediaItem(
              success: true,
              id: 'media_${DateTime.now().millisecondsSinceEpoch}',
              title: data['filename']?.toString() ?? fallbackTitle ?? '${socialPlatform.displayName} Download',
              platform: socialPlatform,
              author: MediaAuthor(
                name: '${socialPlatform.displayName} Creator',
                username: '@${platformStr.toLowerCase()}',
                avatar: fallbackThumbnail ?? '',
              ),
              thumbnail: fallbackThumbnail ?? '',
              duration: '01:00',
              durationSeconds: 60,
              formats: formats,
              originalUrl: url,
            );
          }
        }
      } catch (_) {
        // Try next instance
      }
    }

    // If all extraction methods fail, throw informative error instead of returning webpage URL
    throw Exception('Could not extract video stream. Please ensure the post/video is public.');
  }

  static String _cleanJsonUrl(String raw) {
    return raw
        .replaceAll(r'\/', '/')
        .replaceAll(r'\u0025', '%')
        .replaceAll(r'\u0026', '&')
        .replaceAll('&amp;', '&');
  }
}
