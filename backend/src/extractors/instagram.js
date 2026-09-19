import axios from 'axios';
import { ytDlpGetInfo, buildFormatsFromYtDlp } from './ytdlp.js';

const RAPID_KEY = process.env.RAPIDAPI_KEY || '923ea47142mshdd695209df086cep1c5026jsn222823935579';

function cleanJsonUrl(raw) {
  if (!raw) return '';
  return raw.replace(/\\\//g, '/').replace(/\\u0026/g, '&').replace(/&amp;/g, '&');
}

/**
 * Extract Instagram Reel or Post video/audio
 * 1. RapidAPI endpoint as specified by user
 * 2. Instagram Embed HTML
 * 3. yt-dlp & oEmbed metadata
 * @param {string} url
 * @returns {Promise<Object>}
 */
export async function extractInstagram(url) {
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
  const shortcode = shortcodeMatch ? shortcodeMatch[1] : `ig_${Date.now()}`;

  let title = 'Instagram Reel';
  let authorName = 'Instagram Creator';
  let thumbnail = '';
  let videoUrl = null;
  let audioUrl = null;

  // ── 1. RAPIDAPI ENDPOINT ──────────────────────────────────────────────────
  try {
    const rapidRes = await axios.get(
      `https://instagram-downloader-download-instagram-videos-stories.p.rapidapi.com/index?url=${encodeURIComponent(targetUrl)}`,
      {
        headers: {
          'x-rapidapi-key': RAPID_KEY,
          'x-rapidapi-host': 'instagram-downloader-download-instagram-videos-stories.p.rapidapi.com'
        },
        timeout: 10000
      }
    );

    if (rapidRes.data) {
      const data = rapidRes.data;
      thumbnail = data.thumbnail || thumbnail;
      title = data.title || title;

      if (data.medias && Array.isArray(data.medias) && data.medias.length > 0) {
        const vMedia = data.medias.find(m => m.type === 'video' || m.url?.includes('.mp4')) || data.medias[0];
        const aMedia = data.medias.find(m => m.type === 'audio' || m.ext === 'mp3') || data.medias[1] || vMedia;

        if (vMedia && vMedia.url) videoUrl = cleanJsonUrl(vMedia.url);
        if (aMedia && aMedia.url) audioUrl = cleanJsonUrl(aMedia.url);
      }
      if (videoUrl) console.log('RapidAPI Instagram success');
    }
  } catch (e) {
    console.warn('RapidAPI Instagram failed:', e.message);
  }

  // ── 2. INSTAGRAM EMBED HTML ───────────────────────────────────────────────
  if (!videoUrl && shortcode) {
    try {
      const embedRes = await axios.get(`https://www.instagram.com/p/${shortcode}/embed/captioned/`, {
        headers: {
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36',
          'Accept': 'text/html,application/xhtml+xml',
          'Referer': 'https://www.instagram.com/'
        },
        timeout: 8000
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
          videoUrl = cleanJsonUrl(m[1]);
          console.log('IG embed HTML success');
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
        if (m && m[1] && !thumbnail) { thumbnail = cleanJsonUrl(m[1]); break; }
      }
    } catch (e) {
      console.warn('IG embed HTML failed:', e.message);
    }
  }

  // ── 3. YT-DLP FALLBACK ────────────────────────────────────────────────────
  if (!videoUrl) {
    try {
      const info = await ytDlpGetInfo(targetUrl);
      if (info) {
        title = info.title || title;
        authorName = info.uploader || authorName;
        if (!thumbnail) thumbnail = info.thumbnail || '';
        const formats = buildFormatsFromYtDlp(info);
        if (formats.length > 0 && formats[0].url) {
          videoUrl = formats[0].url;
          console.log('yt-dlp Instagram success');
        }
      }
    } catch (e) {
      console.warn('yt-dlp Instagram failed:', e.message);
    }
  }

  // ── 4. OEMBED METADATA FALLBACK ───────────────────────────────────────────
  try {
    const oe = await axios.get(
      `https://api.instagram.com/oembed/?url=${encodeURIComponent(targetUrl)}`,
      {
        timeout: 4000,
        headers: { 'User-Agent': 'Mozilla/5.0 (iPhone; CPU iPhone OS 16_5 like Mac OS X) AppleWebKit/605.1.15' }
      }
    );
    if (oe.data) {
      title = oe.data.title || title;
      authorName = oe.data.author_name || authorName;
      if (!thumbnail) thumbnail = oe.data.thumbnail_url || '';
    }
  } catch (e) { /* ignore */ }

  if (!videoUrl) {
    throw new Error('Could not extract direct Instagram video stream. Please ensure the Reel/Post is public.');
  }

  const finalAudioUrl = audioUrl || videoUrl;

  return {
    success: true,
    platform: 'instagram',
    id: shortcode,
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
        label: 'HD PRO (1080p)',
        quality: '1080p',
        type: 'video',
        ext: 'mp4',
        url: videoUrl,
        hasAudio: true,
        noWatermark: true
      },
      {
        id: 'audio_mp3',
        label: 'Audio Only (MP3)',
        quality: 'Original',
        type: 'audio',
        ext: 'mp3',
        url: finalAudioUrl,
        hasAudio: true,
        noWatermark: true
      }
    ]
  };
}
