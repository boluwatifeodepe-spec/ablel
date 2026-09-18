import axios from 'axios';
import { ytDlpGetInfo, buildFormatsFromYtDlp } from './ytdlp.js';

function cleanJsonUrl(raw) {
  if (!raw) return '';
  return raw.replace(/\\\//g, '/').replace(/\\u0026/g, '&').replace(/&amp;/g, '&');
}

/**
 * Extract Instagram Reel or Post video
 * Primary: Instagram Embed HTML
 * Secondary: yt-dlp
 * Tertiary: oEmbed metadata
 * @param {string} url
 * @returns {Promise<Object>}
 */
export async function extractInstagram(url) {
  // Resolve share/redirect URLs
  let targetUrl = url;
  if (url.includes('/share/') || url.includes('ig.me')) {
    try {
      const redRes = await axios.get(url, {
        maxRedirects: 5,
        headers: {
          'User-Agent': 'Mozilla/5.0 (iPhone; CPU iPhone OS 16_5 like Mac OS X) AppleWebKit/605.1.15'
        },
        timeout: 8000
      });
      if (redRes.request?.res?.responseUrl) targetUrl = redRes.request.res.responseUrl;
    } catch (e) {
      if (e.response?.headers?.location) targetUrl = e.response.headers.location;
    }
  }

  const shortcodeMatch = targetUrl.match(/(?:reel|p|tv|stories\/[^/]+)\/([A-Za-z0-9_-]+)/);
  const shortcode = shortcodeMatch ? shortcodeMatch[1] : null;

  let title = 'Instagram Reel';
  let authorName = 'Instagram Creator';
  let thumbnail = '';
  let downloadUrl = null;

  // ── 1. PRIMARY: Instagram Embed HTML ──────────────────────────────────────
  if (shortcode) {
    try {
      const embedRes = await axios.get(`https://www.instagram.com/p/${shortcode}/embed/captioned/`, {
        headers: {
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36',
          'Accept': 'text/html,application/xhtml+xml',
          'Referer': 'https://www.instagram.com/'
        },
        timeout: 10000
      });
      const html = embedRes.data.toString();

      const videoPatterns = [
        /"video_url"\s*:\s*"([^"]+)"/,
        /\\"video_url\\":\\"([^\\]+)\\"/,
        /<video[^>]+src="([^"]+)"/i,
        /"playable_url"\s*:\s*"([^"]+)"/,
        /"contentUrl"\s*:\s*"([^"]+)"/,
        /property="og:video"\s+content="([^"]+)"/
      ];

      for (const pat of videoPatterns) {
        const m = html.match(pat);
        if (m && m[1]) {
          downloadUrl = cleanJsonUrl(m[1]);
          console.log('IG embed HTML video found');
          break;
        }
      }

      const thumbPatterns = [
        /<img[^>]+class="EmbeddedMediaImage"[^>]+src="([^"]+)"/,
        /"display_url"\s*:\s*"([^"]+)"/,
        /property="og:image"\s+content="([^"]+)"/
      ];
      for (const pat of thumbPatterns) {
        const m = html.match(pat);
        if (m && m[1]) { thumbnail = cleanJsonUrl(m[1]); break; }
      }
    } catch (e) {
      console.warn('IG embed HTML failed:', e.message);
    }
  }

  // ── 2. SECONDARY: yt-dlp ──────────────────────────────────────────────────
  if (!downloadUrl) {
    try {
      const info = await ytDlpGetInfo(targetUrl);
      if (info) {
        title = info.title || title;
        authorName = info.uploader || authorName;
        thumbnail = info.thumbnail || thumbnail;
        const formats = buildFormatsFromYtDlp(info);
        if (formats.length > 0 && formats[0].url) {
          downloadUrl = formats[0].url;
          console.log('yt-dlp Instagram success');
        }
      }
    } catch (e) {
      console.warn('yt-dlp Instagram failed:', e.message);
    }
  }

  // ── 3. TERTIARY: oEmbed metadata ──────────────────────────────────────────
  try {
    const oe = await axios.get(
      `https://api.instagram.com/oembed/?url=${encodeURIComponent(targetUrl)}`,
      {
        timeout: 5000,
        headers: { 'User-Agent': 'Mozilla/5.0 (iPhone; CPU iPhone OS 16_5 like Mac OS X) AppleWebKit/605.1.15' }
      }
    );
    if (oe.data) {
      title = oe.data.title || title;
      authorName = oe.data.author_name || authorName;
      if (!thumbnail) thumbnail = oe.data.thumbnail_url || thumbnail;
    }
  } catch (e) { /* ignore */ }

  if (!downloadUrl) {
    throw new Error('Could not extract direct Instagram video stream. Please ensure the post/reel is public.');
  }

  return {
    success: true,
    platform: 'instagram',
    id: shortcode || `ig_${Date.now()}`,
    title,
    author: {
      name: authorName,
      username: `@${authorName.replace(/\s+/g, '').toLowerCase()}`,
      avatar: thumbnail
    },
    thumbnail: thumbnail || 'https://images.unsplash.com/photo-1611162617474-5b21e879e113?w=500&auto=format&fit=crop',
    duration: '00:30',
    durationSeconds: 30,
    formats: [
      {
        id: 'video_hd',
        label: 'HD PRO',
        quality: '1080p',
        type: 'video',
        ext: 'mp4',
        url: downloadUrl,
        hasAudio: true,
        noWatermark: true
      },
      {
        id: 'audio_mp3',
        label: 'Audio Only',
        quality: 'Original',
        type: 'audio',
        ext: 'mp3',
        url: downloadUrl,
        hasAudio: true,
        noWatermark: true
      }
    ]
  };
}
