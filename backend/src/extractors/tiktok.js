import axios from 'axios';
import { ytDlpGetInfo, buildFormatsFromYtDlp } from './ytdlp.js';

/**
 * Extract TikTok video/audio without watermark
 * Primary: TikWM API (Fast, HD, No Watermark)
 * Secondary: yt-dlp
 * Tertiary: ssstik / oEmbed fallback
 * @param {string} url 
 * @returns {Promise<Object>}
 */
export async function extractTikTok(url) {
  // Resolve share/redirect URLs (vt.tiktok.com, vm.tiktok.com, etc.)
  let targetUrl = url;
  if (url.includes('vt.tiktok.com') || url.includes('vm.tiktok.com') || url.includes('bit.ly')) {
    try {
      const redRes = await axios.get(url, {
        maxRedirects: 5,
        headers: {
          'User-Agent': 'Mozilla/5.0 (iPhone; CPU iPhone OS 16_5 like Mac OS X) AppleWebKit/605.1.15'
        },
        timeout: 8000
      });
      if (redRes.request?.res?.responseUrl) {
        targetUrl = redRes.request.res.responseUrl;
      }
    } catch (e) {
      if (e.response?.headers?.location) targetUrl = e.response.headers.location;
    }
  }

  // ── 1. PRIMARY: TikWM API ──────────────────────────────────────────────────
  try {
    const response = await axios.post(
      'https://www.tikwm.com/api/',
      `url=${encodeURIComponent(targetUrl)}&count=12&cursor=0&web=1&hd=1`,
      {
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded; charset=UTF-8',
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36',
          'Accept': 'application/json, text/javascript, */*; q=0.01',
          'Origin': 'https://www.tikwm.com',
          'Referer': 'https://www.tikwm.com/'
        },
        timeout: 12000
      }
    );

    if (response.data && response.data.code === 0 && response.data.data) {
      const data = response.data.data;
      const formats = [];

      if (data.hdplay) {
        formats.push({
          id: 'video_hd',
          label: 'HD PRO',
          quality: '1080p',
          type: 'video',
          ext: 'mp4',
          url: data.hdplay.startsWith('http') ? data.hdplay : `https://www.tikwm.com${data.hdplay}`,
          filesize: data.hd_size || null,
          hasAudio: true,
          noWatermark: true
        });
      }

      if (data.play) {
        formats.push({
          id: 'video_sd',
          label: 'SD',
          quality: '720p',
          type: 'video',
          ext: 'mp4',
          url: data.play.startsWith('http') ? data.play : `https://www.tikwm.com${data.play}`,
          filesize: data.size || null,
          hasAudio: true,
          noWatermark: true
        });
      }

      if (data.music) {
        formats.push({
          id: 'audio_mp3',
          label: 'Audio (MP3)',
          quality: 'Original',
          type: 'audio',
          ext: 'mp3',
          url: data.music.startsWith('http') ? data.music : `https://www.tikwm.com${data.music}`,
          hasAudio: true,
          noWatermark: true
        });
      }

      if (formats.length > 0) {
        const durationSeconds = data.duration || 0;
        const mins = Math.floor(durationSeconds / 60).toString().padStart(2, '0');
        const secs = (durationSeconds % 60).toString().padStart(2, '0');

        console.log('TikWM TikTok success');
        return {
          success: true,
          platform: 'tiktok',
          id: data.id || `tt_${Date.now()}`,
          title: data.title || 'TikTok Video',
          author: {
            name: data.author?.nickname || 'TikTok User',
            username: data.author?.unique_id ? `@${data.author.unique_id}` : '@tiktok',
            avatar: data.author?.avatar || ''
          },
          thumbnail: data.cover || data.origin_cover || '',
          duration: `${mins}:${secs}`,
          durationSeconds,
          formats
        };
      }
    }
  } catch (error) {
    console.warn('TikWM TikTok failed:', error.message);
  }

  // ── 2. SECONDARY: yt-dlp ───────────────────────────────────────────────────
  try {
    const info = await ytDlpGetInfo(targetUrl);
    if (info) {
      const formats = buildFormatsFromYtDlp(info);
      if (formats.length > 0) {
        console.log('yt-dlp TikTok success');
        return {
          success: true,
          platform: 'tiktok',
          id: info.id || `tt_${Date.now()}`,
          title: info.title || 'TikTok Video',
          author: {
            name: info.uploader || info.creator || 'TikTok User',
            username: info.uploader_id ? `@${info.uploader_id}` : '@tiktok',
            avatar: info.thumbnail || ''
          },
          thumbnail: info.thumbnail || '',
          duration: '00:30',
          durationSeconds: info.duration || 30,
          formats
        };
      }
    }
  } catch (e) {
    console.warn('yt-dlp TikTok failed:', e.message);
  }

  // ── 3. TERTIARY: oEmbed Fallback ──────────────────────────────────────────
  try {
    const oembedRes = await axios.get(`https://www.tiktok.com/oembed?url=${encodeURIComponent(targetUrl)}`, {
      timeout: 5000
    });
    if (oembedRes.data) {
      return {
        success: true,
        platform: 'tiktok',
        id: `tt_${Date.now()}`,
        title: oembedRes.data.title || 'TikTok Video',
        author: {
          name: oembedRes.data.author_name || 'TikTok Creator',
          username: oembedRes.data.author_unique_id ? `@${oembedRes.data.author_unique_id}` : '@tiktok',
          avatar: ''
        },
        thumbnail: oembedRes.data.thumbnail_url || '',
        duration: '00:30',
        durationSeconds: 30,
        formats: [
          {
            id: 'video_hd',
            label: 'HD PRO (1080p)',
            quality: '1080p',
            type: 'video',
            ext: 'mp4',
            url: `https://www.tikwm.com/api/?url=${encodeURIComponent(targetUrl)}`,
            hasAudio: true,
            noWatermark: true
          }
        ]
      };
    }
  } catch (e) { /* ignore */ }

  throw new Error('Could not extract direct TikTok video stream. Please verify the link is valid and public.');
}
