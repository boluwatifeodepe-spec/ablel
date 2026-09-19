import axios from 'axios';
import { ytDlpGetInfo, buildFormatsFromYtDlp } from './ytdlp.js';

const RAPID_KEY = process.env.RAPIDAPI_KEY || '923ea47142mshdd695209df086cep1c5026jsn222823935579';

/**
 * Extract TikTok video/audio without watermark
 * 1. TikWM API (Fast, HD 1080p, No-Watermark + MP3 Audio)
 * 2. RapidAPI TikTok Downloader
 * 3. yt-dlp & oEmbed Fallback
 * @param {string} url 
 * @returns {Promise<Object>}
 */
export async function extractTikTok(url) {
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
          label: 'HD PRO (1080p)',
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
          label: 'SD (720p)',
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
          label: 'Audio Only (MP3)',
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

  // ── 2. SECONDARY: RapidAPI TikTok Endpoint ─────────────────────────────────
  try {
    const rapidRes = await axios.get(
      `https://tiktok-downloader-download-tiktok-videos-without-watermark.p.rapidapi.com/index?url=${encodeURIComponent(targetUrl)}`,
      {
        headers: {
          'x-rapidapi-key': RAPID_KEY,
          'x-rapidapi-host': 'tiktok-downloader-download-tiktok-videos-without-watermark.p.rapidapi.com'
        },
        timeout: 10000
      }
    );
    if (rapidRes.data && (rapidRes.data.video || rapidRes.data.url)) {
      const vUrl = rapidRes.data.video || rapidRes.data.url;
      const aUrl = rapidRes.data.music || rapidRes.data.audio || vUrl;
      console.log('RapidAPI TikTok success');
      return {
        success: true,
        platform: 'tiktok',
        id: `tt_${Date.now()}`,
        title: rapidRes.data.title || 'TikTok Video',
        author: {
          name: rapidRes.data.author || 'TikTok User',
          username: '@tiktok',
          avatar: rapidRes.data.cover || ''
        },
        thumbnail: rapidRes.data.cover || '',
        duration: '00:30',
        durationSeconds: 30,
        formats: [
          { id: 'video_hd', label: 'HD PRO (1080p)', quality: '1080p', type: 'video', ext: 'mp4', url: vUrl, hasAudio: true, noWatermark: true },
          { id: 'audio_mp3', label: 'Audio Only (MP3)', quality: 'Original', type: 'audio', ext: 'mp3', url: aUrl, hasAudio: true, noWatermark: true }
        ]
      };
    }
  } catch (e) {
    console.warn('RapidAPI TikTok failed:', e.message);
  }

  // ── 3. TERTIARY: yt-dlp ────────────────────────────────────────────────────
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

  throw new Error('Could not extract direct TikTok video stream. Please verify the link is valid and public.');
}
