import axios from 'axios';
import * as cheerio from 'cheerio';
import { ytDlpGetInfo, buildFormatsFromYtDlp } from './ytdlp.js';

function cleanJsonUrl(raw) {
  if (!raw) return '';
  return raw.replace(/\\\//g, '/').replace(/\\u0026/g, '&').replace(/&amp;/g, '&');
}

/**
 * Extract Facebook video/reels media
 * Primary: Facebook Video Plugin Embed API (official)
 * Secondary: yt-dlp
 * Tertiary: Mobile/Desktop HTML Scrape
 * @param {string} url
 * @returns {Promise<Object>}
 */
export async function extractFacebook(url) {
  let title = 'Facebook Video';
  let authorName = 'Facebook Creator';
  let thumbnail = '';
  let hdUrl = null;
  let sdUrl = null;

  // ── RESOLVE SHARE/REDIRECT URLS ───────────────────────────────────────────
  let targetUrl = url;
  if (url.includes('/share/') || url.includes('fb.watch') || url.includes('fb.me')) {
    try {
      const redRes = await axios.get(url, {
        maxRedirects: 5,
        headers: {
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36'
        },
        timeout: 10000
      });
      if (redRes.request?.res?.responseUrl && !redRes.request.res.responseUrl.includes('/login')) {
        targetUrl = redRes.request.res.responseUrl;
      }
    } catch (e) {
      if (e.response?.headers?.location && !e.response.headers.location.includes('/login')) {
        targetUrl = e.response.headers.location;
      }
    }
  }

  // ── 1. PRIMARY: Facebook Video Plugin Embed API ───────────────────────────
  try {
    const pluginRes = await axios.get(
      `https://www.facebook.com/plugins/video.php?href=${encodeURIComponent(targetUrl)}&width=640`,
      {
        headers: {
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36',
          'Accept-Language': 'en-US,en;q=0.9',
          'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8'
        },
        timeout: 10000
      }
    );
    const html = pluginRes.data.toString();

    const hdPatterns = [
      /"hd_src"\s*:\s*"([^"]+)"/,
      /\\"hd_src\\":\s*\\"([^\\]+)\\"/,
      /"browser_native_hd_url"\s*:\s*"([^"]+)"/
    ];
    const sdPatterns = [
      /"sd_src"\s*:\s*"([^"]+)"/,
      /\\"sd_src\\":\s*\\"([^\\]+)\\"/,
      /"browser_native_sd_url"\s*:\s*"([^"]+)"/,
      /"playable_url"\s*:\s*"([^"]+)"/
    ];

    for (const pat of hdPatterns) {
      const m = html.match(pat); if (m && m[1]) { hdUrl = cleanJsonUrl(m[1]); break; }
    }
    for (const pat of sdPatterns) {
      const m = html.match(pat); if (m && m[1]) { sdUrl = cleanJsonUrl(m[1]); break; }
    }

    const thumbPat = html.match(/"thumbnail_src"\s*:\s*"([^"]+)"/) || html.match(/"cover_image_url"\s*:\s*"([^"]+)"/);
    if (thumbPat) thumbnail = cleanJsonUrl(thumbPat[1]);

    if (hdUrl || sdUrl) console.log('FB plugin embed: success');
  } catch (e) {
    console.warn('Facebook plugin embed failed:', e.message);
  }

  // ── 2. SECONDARY: yt-dlp ──────────────────────────────────────────────────
  if (!hdUrl && !sdUrl) {
    try {
      const info = await ytDlpGetInfo(targetUrl);
      if (info) {
        title = info.title || title;
        authorName = info.uploader || authorName;
        thumbnail = info.thumbnail || thumbnail;
        const formats = buildFormatsFromYtDlp(info);
        if (formats.length > 0 && formats[0].url) {
          hdUrl = formats[0].url;
          console.log('yt-dlp Facebook success');
        }
      }
    } catch (e) {
      console.warn('yt-dlp Facebook failed:', e.message);
    }
  }

  // ── 3. TERTIARY: Mobile/Desktop HTML scrape ───────────────────────────────
  if (!hdUrl && !sdUrl) {
    for (const [ua, urlTransform] of [
      ['Mozilla/5.0 (Linux; Android 12; Pixel 6) AppleWebKit/537.36 Chrome/120.0.0.0 Mobile Safari/537.36',
        u => u.replace('www.facebook.com', 'm.facebook.com')],
      ['Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 Chrome/124.0.0.0 Safari/537.36',
        u => u]
    ]) {
      try {
        const res = await axios.get(urlTransform(targetUrl), {
          headers: { 'User-Agent': ua, 'Accept-Language': 'en-US,en;q=0.9' },
          timeout: 10000
        });
        const html = res.data.toString();
        const $ = cheerio.load(html);
        if (!title || title === 'Facebook Video') {
          title = $('meta[property="og:title"]').attr('content') || $('title').text() || title;
        }
        if (!thumbnail) thumbnail = cleanJsonUrl($('meta[property="og:image"]').attr('content') || '');

        const hdPats = [
          /"playable_url_quality_hd"\s*:\s*"([^"]+)"/,
          /"browser_native_hd_url"\s*:\s*"([^"]+)"/,
          /"hd_src"\s*:\s*"([^"]+)"/
        ];
        const sdPats = [
          /"playable_url"\s*:\s*"([^"]+)"/,
          /"browser_native_sd_url"\s*:\s*"([^"]+)"/,
          /"sd_src"\s*:\s*"([^"]+)"/
        ];

        for (const p of hdPats) { const m = html.match(p); if (m && m[1]) { hdUrl = cleanJsonUrl(m[1]); break; } }
        for (const p of sdPats) { const m = html.match(p); if (m && m[1]) { sdUrl = cleanJsonUrl(p[1]); break; } }

        if (hdUrl || sdUrl) { console.log('FB HTML scrape success'); break; }
      } catch (e) {
        console.warn('FB HTML scrape failed:', e.message);
      }
    }
  }

  if (!hdUrl && !sdUrl) {
    throw new Error('Could not extract direct Facebook video stream. Please ensure the video is public.');
  }

  const finalHdUrl = hdUrl || sdUrl;
  const finalSdUrl = sdUrl || hdUrl;

  return {
    success: true,
    platform: 'facebook',
    id: `fb_${Date.now()}`,
    title,
    author: { name: authorName, username: '@facebook', avatar: thumbnail },
    thumbnail: thumbnail || 'https://images.unsplash.com/photo-1611162616305-c69b3fa7fbe0?w=500&auto=format&fit=crop',
    duration: '01:15',
    durationSeconds: 75,
    formats: [
      {
        id: 'video_hd',
        label: 'HD PRO (1080p)',
        quality: '1080p',
        type: 'video',
        ext: 'mp4',
        url: finalHdUrl,
        hasAudio: true,
        noWatermark: true
      },
      {
        id: 'video_sd',
        label: 'SD (720p)',
        quality: '720p',
        type: 'video',
        ext: 'mp4',
        url: finalSdUrl,
        hasAudio: true,
        noWatermark: true
      },
      {
        id: 'audio_mp3',
        label: 'Audio Only',
        quality: 'Original',
        type: 'audio',
        ext: 'mp3',
        url: finalHdUrl,
        hasAudio: true,
        noWatermark: true
      }
    ]
  };
}
