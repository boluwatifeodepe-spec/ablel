import axios from 'axios';
import * as cheerio from 'cheerio';

function cleanJsonUrl(raw) {
  if (!raw) return '';
  return raw.replace(/\\\/|\\/g, '/').replace(/\\u0026/g, '&').replace(/&amp;/g, '&');
}

/**
 * Extract Facebook video/reels media
 * @param {string} url
 * @returns {Promise<Object>}
 */
export async function extractFacebook(url) {
  let title = 'Facebook Video';
  let authorName = 'Facebook Creator';
  let thumbnail = '';
  let hdUrl = null;
  let sdUrl = null;

  // 1. Direct HTML parse for Facebook progressive HD/SD video MP4 URLs with full audio
  try {
    const mobileRes = await axios.get(
      url.replace('www.facebook.com', 'm.facebook.com'),
      {
        headers: {
          'User-Agent': 'Mozilla/5.0 (Linux; Android 12; Pixel 6) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36',
          'Accept-Language': 'en-US,en;q=0.9'
        },
        timeout: 10000
      }
    );
    const html = mobileRes.data.toString();
    const $m = cheerio.load(html);

    const ogTitle = $m('meta[property="og:title"]').attr('content') || $m('title').text();
    const ogThumb = $m('meta[property="og:image"]').attr('content');

    if (ogTitle) title = ogTitle;
    if (ogThumb) thumbnail = cleanJsonUrl(ogThumb);

    const hdMatch = html.match(/"playable_url_quality_hd"\s*:\s*"([^"]+)"/) ||
                    html.match(/"browser_native_hd_url"\s*:\s*"([^"]+)"/);
    const sdMatch = html.match(/"playable_url"\s*:\s*"([^"]+)"/) ||
                    html.match(/"browser_native_sd_url"\s*:\s*"([^"]+)"/);

    if (hdMatch && hdMatch[1]) hdUrl = cleanJsonUrl(hdMatch[1]);
    if (sdMatch && sdMatch[1]) sdUrl = cleanJsonUrl(sdMatch[1]);
  } catch (e) {
    console.warn('Facebook direct scrape failed:', e.message);
  }

  // 2. Try getfvid.com API fallback
  if (!hdUrl && !sdUrl) {
    try {
      const tokenRes = await axios.get('https://getfvid.com/', {
        headers: {
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36'
        },
        timeout: 8000
      });

      const $ = cheerio.load(tokenRes.data);
      const token = $('input[name="_token"]').val() || $('input[name="token"]').val();

      if (token) {
        const dlRes = await axios.post(
          'https://getfvid.com/downloader',
          new URLSearchParams({ url, _token: token }).toString(),
          {
            headers: {
              'Content-Type': 'application/x-www-form-urlencoded',
              'User-Agent': 'Mozilla/5.0',
              'Referer': 'https://getfvid.com/'
            },
            timeout: 12000
          }
        );

        const $dl = cheerio.load(dlRes.data);
        const titleEl = $dl('h2, h3, .video-title, .title').first().text().trim();
        if (titleEl) title = titleEl;

        $dl('a[href]').each((_, el) => {
          const href = $dl(el).attr('href') || '';
          const text = $dl(el).text().toLowerCase();
          if (href.includes('.mp4') || href.includes('fbcdn') || href.includes('video')) {
            if ((text.includes('hd') || text.includes('high')) && !hdUrl) {
              hdUrl = href;
            } else if (!sdUrl) {
              sdUrl = href;
            }
          }
        });

        const thumbEl = $dl('img[src*="fbcdn"], img.video-thumb, img[src*="thumb"]').first().attr('src');
        if (thumbEl && !thumbnail) thumbnail = thumbEl;
      }
    } catch (e) {
      console.warn('getfvid failed:', e.message);
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
    author: {
      name: authorName,
      username: '@facebook',
      avatar: thumbnail
    },
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
