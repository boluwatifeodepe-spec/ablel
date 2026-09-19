import axios from 'axios';
import * as cheerio from 'cheerio';
import { ytDlpGetInfo, buildFormatsFromYtDlp } from './ytdlp.js';

const RAPID_KEY = process.env.RAPIDAPI_KEY || '923ea47142mshdd695209df086cep1c5026jsn222823935579';

function cleanJsonUrl(raw) {
  if (!raw) return '';
  return raw.replace(/\\\//g, '/').replace(/\\u0026/g, '&').replace(/&amp;/g, '&');
}

/**
 * Extract Facebook video/reels media
 * 1. RapidAPI Facebook Downloader
 * 2. Facebook Video Plugin Embed API
 * 3. yt-dlp & mobile HTML scrape
 * @param {string} url
 * @returns {Promise<Object>}
 */
export async function extractFacebook(url) {
  let title = 'Facebook Video';
  let authorName = 'Facebook Creator';
  let thumbnail = '';
  let hdUrl = null;
  let sdUrl = null;

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

  // ── 1. RAPIDAPI FACEBOOK ENDPOINT ─────────────────────────────────────────
  try {
    const rapidRes = await axios.get(
      `https://facebook-reel-and-video-downloader.p.rapidapi.com/get-media?url=${encodeURIComponent(targetUrl)}`,
      {
        headers: {
          'x-rapidapi-key': RAPID_KEY,
          'x-rapidapi-host': 'facebook-reel-and-video-downloader.p.rapidapi.com'
        },
        timeout: 10000
      }
    );
    if (rapidRes.data) {
      const data = rapidRes.data;
      hdUrl = data.hd || data.hd_url || data.links?.hd || data.video_hd;
      sdUrl = data.sd || data.sd_url || data.links?.sd || data.video_sd || hdUrl;
      thumbnail = data.thumbnail || data.cover || thumbnail;
      title = data.title || title;
      if (hdUrl || sdUrl) console.log('RapidAPI Facebook success');
    }
  } catch (e) {
    console.warn('RapidAPI Facebook failed:', e.message);
  }

  // ── 2. FACEBOOK PLUGIN EMBED API ──────────────────────────────────────────
  if (!hdUrl && !sdUrl) {
    try {
      const pluginRes = await axios.get(
        `https://www.facebook.com/plugins/video.php?href=${encodeURIComponent(targetUrl)}&width=640`,
        {
          headers: {
            'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36',
            'Accept-Language': 'en-US,en;q=0.9'
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
      if (thumbPat && !thumbnail) thumbnail = cleanJsonUrl(thumbPat[1]);

      if (hdUrl || sdUrl) console.log('FB plugin embed success');
    } catch (e) {
      console.warn('Facebook plugin embed failed:', e.message);
    }
  }

  // ── 3. YT-DLP FALLBACK ────────────────────────────────────────────────────
  if (!hdUrl && !sdUrl) {
    try {
      const info = await ytDlpGetInfo(targetUrl);
      if (info) {
        title = info.title || title;
        authorName = info.uploader || authorName;
        if (!thumbnail) thumbnail = info.thumbnail || '';
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
        label: 'Audio Only (MP3)',
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
