import 'dart:convert';
import 'package:dio/dio.dart';
import '../../core/utils/platform_utils.dart';
import '../models/media_format.dart';
import '../models/media_item.dart';

/// Direct on-device extraction service for standalone operation without a dedicated backend.
class ClientExtractor {
  static final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 20),
      headers: {
        'User-Agent':
            'Mozilla/5.0 (iPhone; CPU iPhone OS 17_4 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.4 Mobile/15E148 Safari/604.1',
        'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,*/*;q=0.8',
        'Accept-Language': 'en-US,en;q=0.9',
      },
    ),
  );

  // Pool of reliable public Cobalt instances (supporting v10 and v7)
  static const List<Map<String, String>> _cobaltInstances = [
    {'url': 'https://api.cobalt.tools', 'version': 'v10'},
    {'url': 'https://cobalt.hyonsu.com', 'version': 'v10'},
    {'url': 'https://cobalt-api.kwiatekm.tokyo', 'version': 'v10'},
    {'url': 'https://co.wuk.sh/api/json', 'version': 'v7'},
    {'url': 'https://dl.khub.net/api/json', 'version': 'v7'},
    {'url': 'https://cobalt.api.scav.top/api/json', 'version': 'v7'},
  ];

  // Pool of reliable Invidious instances for YouTube extraction
  static const List<String> _invidiousInstances = [
    'https://invidious.jing.rocks',
    'https://inv.nadeko.net',
    'https://invidious.nerdvpn.de',
    'https://invidious.drgns.space',
    'https://vid.puffyan.us',
    'https://invidious.private.coffee',
    'https://yt.artemislena.eu',
    'https://invidious.f5.si',
  ];

  // Pool of Piped instances for YouTube streams
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
    return await _extractCobaltGeneric(url, platformStr: 'tiktok', fallbackTitle: 'TikTok Video');
  }

  // ==========================================
  // 2. TWITTER / X DIRECT EXTRACTOR (Syndication + FxTwitter + Twitsave + Cobalt)
  // ==========================================
  static Future<MediaItem> _extractTwitter(String url) async {
    final statusMatch = RegExp(r'status(?:es)?/(\d+)').firstMatch(url);
    final tweetId = statusMatch?.group(1);

    if (tweetId != null) {
      // Tier 1: Twitter Official Syndication API (Twimg direct MP4s with quality variants)
      try {
        final syndicationRes = await _dio.get(
          'https://cdn.syndication.twimg.com/tweet-result?id=$tweetId&lang=en',
          options: Options(receiveTimeout: const Duration(seconds: 8)),
        );

        if (syndicationRes.data is Map) {
          final data = syndicationRes.data as Map<String, dynamic>;
          final formats = <MediaFormat>[];
          final text = data['text']?.toString() ?? 'X / Twitter Video';
          final user = data['user'] is Map ? data['user'] as Map<String, dynamic> : null;
          final authorName = user?['name']?.toString() ?? 'X User';
          final username = user?['screen_name'] != null ? '@${user!['screen_name']}' : '@x';
          final avatar = user?['profile_image_url_https']?.toString() ?? '';
          String thumbnail = '';

          // Look into mediaDetails
          if (data['mediaDetails'] is List) {
            final mediaDetails = (data['mediaDetails'] as List).cast<dynamic>();
            for (final m in mediaDetails) {
              if (m is Map) {
                if (thumbnail.isEmpty && m['media_url_https'] != null) {
                  thumbnail = m['media_url_https'].toString();
                }

                final videoInfo = m['video_info'] is Map ? m['video_info'] as Map<String, dynamic> : null;
                if (videoInfo != null && videoInfo['variants'] is List) {
                  final variants = (videoInfo['variants'] as List).cast<dynamic>();
                  // Filter mp4 variants and sort by bitrate descending
                  final mp4s = <Map<String, dynamic>>[];
                  for (final v in variants) {
                    if (v is Map && v['content_type'] == 'video/mp4' && v['url'] != null) {
                      mp4s.add(Map<String, dynamic>.from(v));
                    }
                  }

                  mp4s.sort((a, b) {
                    final bBitrate = (b['bitrate'] is num) ? (b['bitrate'] as num).toInt() : 0;
                    final aBitrate = (a['bitrate'] is num) ? (a['bitrate'] as num).toInt() : 0;
                    return bBitrate.compareTo(aBitrate);
                  });

                  for (int i = 0; i < mp4s.length; i++) {
                    final v = mp4s[i];
                    final vUrl = v['url'].toString();
                    final bitrate = (v['bitrate'] is num) ? (v['bitrate'] as num).toInt() : 0;
                    String label = 'HD PRO (1080p)';
                    String quality = '1080p';
                    if (i == 1 || bitrate < 1000000) {
                      label = 'SD (720p)';
                      quality = '720p';
                    } else if (i >= 2) {
                      label = 'Standard (480p)';
                      quality = '480p';
                    }

                    formats.add(
                      MediaFormat(
                        id: 'video_x_$i',
                        label: label,
                        quality: quality,
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
          }

          if (formats.isNotEmpty) {
            // Add MP3 Audio Option
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
              id: tweetId,
              title: text,
              platform: SocialPlatform.twitter,
              author: MediaAuthor(
                name: authorName,
                username: username,
                avatar: avatar,
              ),
              thumbnail: thumbnail,
              duration: '00:30',
              durationSeconds: 30,
              formats: formats,
              originalUrl: url,
            );
          }
        }
      } catch (_) {}

      // Tier 2: Try FxTwitter / FixupX API
      final fxtwitterEndpoints = [
        'https://api.fxtwitter.com/status/$tweetId',
        'https://api.fixupx.com/status/$tweetId',
        'https://api.vxtwitter.com/Twitter/status/$tweetId',
      ];

      for (final endpoint in fxtwitterEndpoints) {
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

      // Tier 3: Try Twitsave scraper
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

    // Tier 4: Fallback to Cobalt pool
    return await _extractCobaltGeneric(url, platformStr: 'twitter', fallbackTitle: 'X / Twitter Video');
  }

  // ==========================================
  // 3. YOUTUBE DIRECT EXTRACTOR (Invidious + InnerTube + Piped + Cobalt)
  // ==========================================
  static Future<MediaItem> _extractYouTube(String url) async {
    // Extract video ID (works with shorts, watch?v=, youtu.be, embed)
    final idMatch = RegExp(r'(?:youtu\.be\/|youtube\.com\/(?:embed\/|v\/|watch\?v=|shorts\/|live\/|watch\?.+&v=))([\w-]{11})')
        .firstMatch(url);
    final videoId = idMatch?.group(1);

    // Initial fallback metadata from oEmbed
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

    if (videoId != null) {
      // Tier 1: Invidious Instances API
      for (final instance in _invidiousInstances) {
        try {
          final res = await _dio.get(
            '$instance/api/v1/videos/$videoId',
            options: Options(receiveTimeout: const Duration(seconds: 6)),
          );

          if (res.data is Map) {
            final data = res.data as Map<String, dynamic>;
            final formats = <MediaFormat>[];

            // 1. Combined Audio + Video Streams (MP4 720p / 360p)
            if (data['formatStreams'] is List) {
              final streams = (data['formatStreams'] as List).cast<dynamic>();
              for (final s in streams) {
                if (s is Map && s['url'] != null) {
                  final sUrl = s['url'].toString();
                  final container = s['container']?.toString() ?? 'mp4';
                  if (sUrl.startsWith('http') && (container.contains('mp4') || sUrl.contains('.mp4'))) {
                    final quality = s['qualityLabel']?.toString() ?? s['resolution']?.toString() ?? '720p';
                    formats.add(
                      MediaFormat(
                        id: 'video_${quality.toLowerCase().replaceAll(RegExp(r'\s+'), '')}',
                        label: 'HD ($quality)',
                        quality: quality,
                        type: 'video',
                        ext: 'mp4',
                        url: sUrl,
                        filesize: s['size'] is num ? (s['size'] as num).toInt() : null,
                        hasAudio: true,
                        noWatermark: true,
                      ),
                    );
                  }
                }
              }
            }

            // 2. High-quality Audio Stream (M4A / WebM / MP3)
            if (data['adaptiveFormats'] is List) {
              final adaptives = (data['adaptiveFormats'] as List).cast<dynamic>();
              for (final a in adaptives) {
                if (a is Map && a['url'] != null && a['type']?.toString().startsWith('audio/') == true) {
                  final aUrl = a['url'].toString();
                  if (aUrl.startsWith('http')) {
                    final bitrate = a['bitrate'] != null ? '${((a['bitrate'] as num) / 1000).round()} kbps' : '128 kbps';
                    formats.add(
                      MediaFormat(
                        id: 'audio_m4a',
                        label: 'Audio ($bitrate)',
                        quality: bitrate,
                        type: 'audio',
                        ext: 'mp3',
                        url: aUrl,
                        filesize: a['contentLength'] is num
                            ? (a['contentLength'] as num).toInt()
                            : int.tryParse(a['clen']?.toString() ?? ''),
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
              final lengthSeconds = data['lengthSeconds'] is num ? (data['lengthSeconds'] as num).toInt() : 180;
              final mins = (lengthSeconds ~/ 60).toString().padLeft(2, '0');
              final secs = (lengthSeconds % 60).toString().padLeft(2, '0');

              return MediaItem(
                success: true,
                id: videoId,
                title: data['title']?.toString() ?? title,
                platform: SocialPlatform.youtube,
                author: MediaAuthor(
                  name: data['author']?.toString() ?? authorName,
                  username: data['authorId'] != null ? '@${data['authorId']}' : '@youtube',
                  avatar: data['authorThumbnails']?[0]?['url']?.toString() ?? '',
                ),
                thumbnail: data['videoThumbnails']?[0]?['url']?.toString() ?? thumbnail,
                duration: '$mins:$secs',
                durationSeconds: lengthSeconds,
                formats: formats,
                originalUrl: url,
              );
            }
          }
        } catch (_) {}
      }

      // Tier 2: YouTube InnerTube Android Client API
      try {
        final innerTubeRes = await _dio.post(
          'https://www.youtube.com/youtubei/v1/player',
          data: jsonEncode({
            'videoId': videoId,
            'context': {
              'client': {
                'clientName': 'ANDROID',
                'clientVersion': '19.09.37',
                'androidSdkVersion': 30,
                'hl': 'en',
                'gl': 'US',
              }
            }
          }),
          options: Options(
            headers: {
              'Content-Type': 'application/json',
              'User-Agent': 'com.google.android.youtube/19.09.37 (Linux; U; Android 11) gzip',
            },
            receiveTimeout: const Duration(seconds: 7),
          ),
        );

        if (innerTubeRes.data is Map) {
          final sData = innerTubeRes.data['streamingData'];
          if (sData is Map) {
            final formats = <MediaFormat>[];
            final videoDetails = innerTubeRes.data['videoDetails'] as Map<String, dynamic>?;

            // Direct progressive formats (contains both video and audio)
            if (sData['formats'] is List) {
              final list = (sData['formats'] as List).cast<dynamic>();
              for (final f in list) {
                if (f is Map && f['url'] != null) {
                  final fUrl = f['url'].toString();
                  final quality = f['qualityLabel']?.toString() ?? '720p';
                  formats.add(
                    MediaFormat(
                      id: 'video_${quality.toLowerCase().replaceAll(RegExp(r'\s+'), '')}',
                      label: 'HD ($quality)',
                      quality: quality,
                      type: 'video',
                      ext: 'mp4',
                      url: fUrl,
                      filesize: int.tryParse(f['contentLength']?.toString() ?? ''),
                      hasAudio: true,
                      noWatermark: true,
                    ),
                  );
                }
              }
            }

            // Audio only format
            if (sData['adaptiveFormats'] is List) {
              final list = (sData['adaptiveFormats'] as List).cast<dynamic>();
              for (final f in list) {
                if (f is Map && f['url'] != null && f['mimeType']?.toString().startsWith('audio/') == true) {
                  final aUrl = f['url'].toString();
                  formats.add(
                    MediaFormat(
                      id: 'audio_innertube',
                      label: 'Audio (MP3/M4A)',
                      quality: 'Original',
                      type: 'audio',
                      ext: 'mp3',
                      url: aUrl,
                      filesize: int.tryParse(f['contentLength']?.toString() ?? ''),
                      hasAudio: true,
                      noWatermark: true,
                    ),
                  );
                  break;
                }
              }
            }

            if (formats.isNotEmpty) {
              final lengthSec = int.tryParse(videoDetails?['lengthSeconds']?.toString() ?? '180') ?? 180;
              final mins = (lengthSec ~/ 60).toString().padLeft(2, '0');
              final secs = (lengthSec % 60).toString().padLeft(2, '0');

              return MediaItem(
                success: true,
                id: videoId,
                title: videoDetails?['title']?.toString() ?? title,
                platform: SocialPlatform.youtube,
                author: MediaAuthor(
                  name: videoDetails?['author']?.toString() ?? authorName,
                  username: '@${(videoDetails?['author'] ?? 'youtube').toString().replaceAll(RegExp(r'\s+'), '').toLowerCase()}',
                  avatar: '',
                ),
                thumbnail: thumbnail,
                duration: '$mins:$secs',
                durationSeconds: lengthSec,
                formats: formats,
                originalUrl: url,
              );
            }
          }
        }
      } catch (_) {}

      // Tier 3: Piped Instances API
      for (final instance in _pipedInstances) {
        try {
          final streamRes = await _dio.get(
            '$instance/streams/$videoId',
            options: Options(receiveTimeout: const Duration(seconds: 5)),
          );
          if (streamRes.data is Map) {
            final data = streamRes.data as Map<String, dynamic>;
            final formats = <MediaFormat>[];

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

            if (data['audioStreams'] is List) {
              final audios = (data['audioStreams'] as List).cast<dynamic>();
              for (final a in audios) {
                if (a is Map && a['url'] != null) {
                  final audioUrl = a['url'].toString();
                  if (audioUrl.startsWith('http')) {
                    formats.add(
                      MediaFormat(
                        id: 'audio_stream',
                        label: 'Audio (MP3)',
                        quality: '128kbps',
                        type: 'audio',
                        ext: 'mp3',
                        url: audioUrl,
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

    // Tier 4: Fallback to Cobalt pool
    return await _extractCobaltGeneric(
      url,
      platformStr: 'youtube',
      fallbackTitle: title,
      fallbackThumbnail: thumbnail,
    );
  }

  // ==========================================
  // 4. INSTAGRAM DIRECT EXTRACTOR (Direct Graph + Open Resolvers + Scraper + Cobalt)
  // ==========================================
  static Future<MediaItem> _extractInstagram(String url) async {
    // Clean and extract shortcode
    final shortcodeMatch = RegExp(r'(?:reel|p|tv|stories/[^/]+)/([A-Za-z0-9_-]+)').firstMatch(url);
    final shortcode = shortcodeMatch?.group(1);

    // Initial oEmbed info
    String title = 'Instagram Reel';
    String authorName = 'Instagram Creator';
    String thumbnail = '';

    try {
      final oembed = await _dio.get(
        'https://api.instagram.com/oembed/?url=${Uri.encodeComponent(url)}',
        options: Options(receiveTimeout: const Duration(seconds: 5)),
      );
      if (oembed.data is Map) {
        title = oembed.data['title']?.toString() ?? title;
        authorName = oembed.data['author_name']?.toString() ?? authorName;
        thumbnail = oembed.data['thumbnail_url']?.toString() ?? thumbnail;
      }
    } catch (_) {}

    // Tier 1: Try Direct Instagram JSON endpoint with clean User-Agent
    if (shortcode != null) {
      try {
        final igRes = await _dio.get(
          'https://www.instagram.com/p/$shortcode/?__a=1&__d=dis',
          options: Options(
            headers: {
              'User-Agent':
                  'Mozilla/5.0 (iPhone; CPU iPhone OS 17_4 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.4 Mobile/15E148 Safari/604.1',
              'Accept': '*/*',
              'X-IG-App-ID': '936619743392459',
            },
            receiveTimeout: const Duration(seconds: 6),
          ),
        );

        if (igRes.data is Map) {
          final items = igRes.data['items'] as List?;
          if (items != null && items.isNotEmpty) {
            final item = items[0] as Map<String, dynamic>;
            final formats = <MediaFormat>[];

            // Check video versions
            if (item['video_versions'] is List) {
              final versions = (item['video_versions'] as List).cast<dynamic>();
              for (int i = 0; i < versions.length; i++) {
                final v = versions[i];
                if (v is Map && v['url'] != null) {
                  final vUrl = v['url'].toString();
                  final width = v['width'] ?? 1080;
                  final height = v['height'] ?? 1920;
                  formats.add(
                    MediaFormat(
                      id: 'video_$i',
                      label: i == 0 ? 'HD PRO ($width x $height)' : 'SD ($width x $height)',
                      quality: '${height}p',
                      type: 'video',
                      ext: 'mp4',
                      url: vUrl,
                      hasAudio: true,
                      noWatermark: true,
                    ),
                  );
                  if (i >= 1) break;
                }
              }
            }

            // Check image versions
            if (formats.isEmpty && item['image_versions2']?['candidates'] is List) {
              final candidates = (item['image_versions2']['candidates'] as List).cast<dynamic>();
              if (candidates.isNotEmpty && candidates[0]['url'] != null) {
                formats.add(
                  MediaFormat(
                    id: 'photo_0',
                    label: 'HD Photo',
                    quality: 'HD Image',
                    type: 'image',
                    ext: 'jpg',
                    url: candidates[0]['url'].toString(),
                    hasAudio: false,
                    noWatermark: true,
                  ),
                );
              }
            }

            if (formats.isNotEmpty) {
              // Add audio track option
              if (formats.first.isVideo) {
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
              }

              final user = item['user'] as Map<String, dynamic>?;
              return MediaItem(
                success: true,
                id: shortcode,
                title: item['caption']?['text']?.toString() ?? title,
                platform: SocialPlatform.instagram,
                author: MediaAuthor(
                  name: user?['full_name']?.toString() ?? authorName,
                  username: user?['username'] != null ? '@${user!['username']}' : '@instagram',
                  avatar: user?['profile_pic_url']?.toString() ?? '',
                ),
                thumbnail: item['image_versions2']?['candidates']?[0]?['url']?.toString() ?? thumbnail,
                duration: '00:30',
                durationSeconds: 30,
                formats: formats,
                originalUrl: url,
              );
            }
          }
        }
      } catch (_) {}
    }

    // Tier 2: Try SaveIG / SaveVid Open Resolvers
    final saveResolvers = [
      {'url': 'https://saveig.me/api/ajaxSearch', 'param': 'q'},
      {'url': 'https://v3.savevid.net/api/ajaxSearch', 'param': 'q'},
    ];

    for (final res in saveResolvers) {
      try {
        final ajaxRes = await _dio.post(
          res['url']!,
          data: '${res['param']}=${Uri.encodeComponent(url)}&t=media&lang=en',
          options: Options(
            headers: {
              'Content-Type': 'application/x-www-form-urlencoded; charset=UTF-8',
              'X-Requested-With': 'XMLHttpRequest',
            },
            receiveTimeout: const Duration(seconds: 7),
          ),
        );

        final html = ajaxRes.data.toString();
        // Regex for direct video or photo download URL
        final downloadMatch = RegExp(r'href="((https:[^"]+cdninstagram\.com[^"]+|https:[^"]+\.mp4[^"]*))"').firstMatch(html) ??
            RegExp(r'href="(https:[^"]+dl\.snapinsta\.app[^"]*)"').firstMatch(html) ??
            RegExp(r'href="(https:[^"]+saveig[^"]+download[^"]*)"').firstMatch(html);

        if (downloadMatch != null) {
          final directUrl = downloadMatch.group(1)!.replaceAll('&amp;', '&');
          final isPhoto = directUrl.contains('.jpg') || directUrl.contains('.png');
          return MediaItem(
            success: true,
            id: shortcode ?? 'ig_${DateTime.now().millisecondsSinceEpoch}',
            title: title,
            platform: SocialPlatform.instagram,
            author: MediaAuthor(name: authorName, username: '@instagram', avatar: thumbnail),
            thumbnail: thumbnail,
            duration: '00:30',
            durationSeconds: 30,
            formats: [
              MediaFormat(
                id: isPhoto ? 'photo_hd' : 'video_hd',
                label: isPhoto ? 'HD Photo' : 'HD PRO (1080p)',
                quality: isPhoto ? 'HD Image' : '1080p',
                type: isPhoto ? 'image' : 'video',
                ext: isPhoto ? 'jpg' : 'mp4',
                url: directUrl,
                hasAudio: !isPhoto,
                noWatermark: true,
              ),
              if (!isPhoto)
                MediaFormat(
                  id: 'audio_mp3',
                  label: 'Audio (MP3)',
                  quality: 'Original',
                  type: 'audio',
                  ext: 'mp3',
                  url: directUrl,
                  hasAudio: true,
                  noWatermark: true,
                ),
            ],
            originalUrl: url,
          );
        }
      } catch (_) {}
    }

    // Tier 3: Direct Instagram HTML Page Regex Parsing
    try {
      final pageRes = await _dio.get(
        url,
        options: Options(
          headers: {
            'User-Agent':
                'Mozilla/5.0 (iPhone; CPU iPhone OS 16_6 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/16.6 Mobile/15E148 Safari/604.1',
          },
          receiveTimeout: const Duration(seconds: 7),
        ),
      );

      final html = pageRes.data.toString();
      final videoMatch = RegExp(r'"video_url":"(https:[^"]+)"').firstMatch(html) ??
          RegExp(r'"playable_url":"(https:[^"]+)"').firstMatch(html) ??
          RegExp(r'<meta property="og:video" content="([^"]+)"').firstMatch(html) ??
          RegExp(r'<meta property="og:video:secure_url" content="([^"]+)"').firstMatch(html);

      if (videoMatch != null) {
        final directVideoUrl = _cleanJsonUrl(videoMatch.group(1)!);
        if (directVideoUrl.startsWith('http')) {
          return MediaItem(
            success: true,
            id: shortcode ?? 'ig_${DateTime.now().millisecondsSinceEpoch}',
            title: title,
            platform: SocialPlatform.instagram,
            author: MediaAuthor(name: authorName, username: '@instagram', avatar: thumbnail),
            thumbnail: thumbnail,
            duration: '00:30',
            durationSeconds: 30,
            formats: [
              MediaFormat(
                id: 'video_hd',
                label: 'HD PRO (1080p)',
                quality: '1080p',
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
      }
    } catch (_) {}

    // Tier 4: Fallback to Cobalt pool
    return await _extractCobaltGeneric(
      url,
      platformStr: 'instagram',
      fallbackTitle: title,
      fallbackThumbnail: thumbnail,
    );
  }

  // ==========================================
  // 5. FACEBOOK DIRECT EXTRACTOR (HTML Scraper + FDownloader + Cobalt)
  // ==========================================
  static Future<MediaItem> _extractFacebook(String url) async {
    // Tier 1: Try direct page regex extraction for HD/SD video stream
    try {
      final res = await _dio.get(
        url,
        options: Options(
          headers: {
            'User-Agent':
                'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/123.0.0.0 Safari/537.36',
            'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
            'Accept-Language': 'en-US,en;q=0.9',
            'Sec-Fetch-Mode': 'navigate',
          },
          receiveTimeout: const Duration(seconds: 8),
        ),
      );

      final html = res.data.toString();
      String? directHdUrl;
      String? directSdUrl;

      // Extract HD/SD URLs from Facebook video page metadata
      final hdMatch = RegExp(r'browser_native_hd_url:"(https:[^"]+)"').firstMatch(html) ??
          RegExp(r'"browser_native_hd_url":"(https:[^"]+)"').firstMatch(html) ??
          RegExp(r'playable_url_quality_hd:"(https:[^"]+)"').firstMatch(html) ??
          RegExp(r'hd_src:"(https:[^"]+)"').firstMatch(html) ??
          RegExp(r'hd_src_no_ratelimit:"(https:[^"]+)"').firstMatch(html);
      if (hdMatch != null) {
        directHdUrl = _cleanJsonUrl(hdMatch.group(1)!);
      }

      final sdMatch = RegExp(r'browser_native_sd_url:"(https:[^"]+)"').firstMatch(html) ??
          RegExp(r'"browser_native_sd_url":"(https:[^"]+)"').firstMatch(html) ??
          RegExp(r'playable_url:"(https:[^"]+)"').firstMatch(html) ??
          RegExp(r'sd_src:"(https:[^"]+)"').firstMatch(html) ??
          RegExp(r'sd_src_no_ratelimit:"(https:[^"]+)"').firstMatch(html) ??
          RegExp(r'<meta property="og:video" content="([^"]+)"').firstMatch(html) ??
          RegExp(r'<meta property="og:video:url" content="([^"]+)"').firstMatch(html);
      if (sdMatch != null) {
        directSdUrl = _cleanJsonUrl(sdMatch.group(1)!);
      }

      final titleMatch = RegExp(r'<meta property="og:title" content="([^"]+)"').firstMatch(html) ??
          RegExp(r'<title>([^<]+)</title>').firstMatch(html);
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

      if (directSdUrl != null && directSdUrl.startsWith('http') && directSdUrl != directHdUrl) {
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
          title: title.replaceAll('&amp;', '&'),
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

    // Tier 2: Try FDownloader API
    try {
      final fdownRes = await _dio.post(
        'https://fdownloader.net/api/ajaxSearch',
        data: 'q=${Uri.encodeComponent(url)}&lang=en',
        options: Options(
          headers: {
            'Content-Type': 'application/x-www-form-urlencoded; charset=UTF-8',
            'X-Requested-With': 'XMLHttpRequest',
          },
          receiveTimeout: const Duration(seconds: 7),
        ),
      );

      final html = fdownRes.data.toString();
      final matches = RegExp(r'href="(https:[^"]+fbcdn\.net[^"]+|https:[^"]+\.mp4[^"]*)"').allMatches(html);
      final formats = <MediaFormat>[];

      for (final m in matches) {
        final videoUrl = m.group(1)!.replaceAll('&amp;', '&');
        if (!formats.any((f) => f.url == videoUrl)) {
          final isHd = videoUrl.contains('hd_src') || formats.isEmpty;
          formats.add(
            MediaFormat(
              id: 'video_${formats.length}',
              label: isHd ? 'HD PRO (1080p)' : 'SD (720p)',
              quality: isHd ? '1080p' : '720p',
              type: 'video',
              ext: 'mp4',
              url: videoUrl,
              hasAudio: true,
              noWatermark: true,
            ),
          );
        }
      }

      if (formats.isNotEmpty) {
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
          title: 'Facebook Video',
          platform: SocialPlatform.facebook,
          author: const MediaAuthor(name: 'Facebook Creator', username: '@facebook', avatar: ''),
          thumbnail: '',
          duration: '01:00',
          durationSeconds: 60,
          formats: formats,
          originalUrl: url,
        );
      }
    } catch (_) {}

    // Tier 3: Fallback to Cobalt pool
    return await _extractCobaltGeneric(url, platformStr: 'facebook', fallbackTitle: 'Facebook Video');
  }

  // ==========================================
  // 6. COBALT MULTI-INSTANCE POOL RESOLVER (V10 & V7 COMPLIANT)
  // ==========================================
  static Future<MediaItem> _extractCobaltGeneric(
    String url, {
    String platformStr = 'unknown',
    String? fallbackTitle,
    String? fallbackThumbnail,
  }) async {
    for (final instance in _cobaltInstances) {
      try {
        final endpoint = instance['url']!;
        final isV10 = instance['version'] == 'v10';

        // Prepare proper payload based on Cobalt version
        final payload = isV10
            ? {
                'url': url,
                'videoQuality': '1080',
                'youtubeVideoCodec': 'h264',
                'audioFormat': 'mp3',
              }
            : {
                'url': url,
                'vQuality': '1080',
                'vCodec': 'h264',
                'isAudioOnly': false,
                'aFormat': 'mp3',
              };

        final res = await _dio.post(
          endpoint,
          data: jsonEncode(payload),
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

          // 1. Direct stream / redirect URL (v10 status: tunnel/redirect/stream, v7 status: stream)
          final streamUrl = data['url']?.toString();
          if (streamUrl != null && streamUrl.startsWith('http') && streamUrl != url) {
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
        // Try next instance in pool
      }
    }

    // If all extraction methods fail, throw clear error
    throw Exception('Could not extract media. Please verify the link is valid and public.');
  }

  static String _cleanJsonUrl(String raw) {
    return raw
        .replaceAll(r'\/', '/')
        .replaceAll(r'\u0025', '%')
        .replaceAll(r'\u0026', '&')
        .replaceAll('&amp;', '&');
  }
}
