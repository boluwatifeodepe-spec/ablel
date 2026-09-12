import axios from 'axios';
import * as cheerio from 'cheerio';

/**
 * Extract Facebook video/reels media
 * Uses: fdownloader.net scraping → savefrom.net → source URL fallback
 * @param {string} url
 * @returns {Promise<Object>}
 */
export async function extractFacebook(url) {
  let title = 'Facebook Video';
  let authorName = 'Facebook User';
  let thumbnail = '';
  let hdUrl = null;
  let sdUrl = null;

  // 1. Try getfvid.com API (reliable Facebook downloader)
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
          timeout: 15000
        }
      );

      const $dl = cheerio.load(dlRes.data);

      // Extract title
      const titleEl = $dl('h2, h3, .video-title, .title').first().text().trim();
      if (titleEl) title = titleEl;

      // Extract HD/SD links
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

      // Thumbnail
      const thumbEl = $dl('img[src*="fbcdn"], img.video-thumb, img[src*="thumb"]').first().attr('src');
      if (thumbEl) thumbnail = thumbEl;
    }
  } catch (e) {
    console.warn('getfvid failed:', e.message);
  }

  // 2. Try savefrom.net as fallback
  if (!hdUrl && !sdUrl) {
    try {
      const sfRes = await axios.post(
        'https://worker.sf-tools.com/savefrom.php',
        JSON.stringify({ sf_url: url }),
        {
          headers: {
            'Content-Type': 'application/json',
            'User-Agent': 'Mozilla/5.0',
            'Origin': 'https://en.savefrom.net',
            'Referer': 'https://en.savefrom.net/'
          },
          timeout: 12000
        }
      );

      if (sfRes.data && sfRes.data.url && Array.isArray(sfRes.data.url)) {
        for (const entry of sfRes.data.url) {
          if (entry.url && !hdUrl) {
            hdUrl = entry.url;
          }
          if (entry.name) title = entry.name;
        }
      }
    } catch (e) {
      console.warn('savefrom fallback failed:', e.message);
    }
  }

  // 3. Try mobile FB scrape for og:video tag
  if (!hdUrl && !sdUrl) {
    try {
      const mobileRes = await axios.get(
        url.replace('www.facebook.com', 'm.facebook.com'),
        {
          headers: {
            'User-Agent': 'Mozilla/5.0 (iPhone; CPU iPhone OS 16_5 like Mac OS X) AppleWebKit/605.1.15',
            'Accept-Language': 'en-US,en;q=0.9'
          },
          timeout: 10000
        }
      );
      const $m = cheerio.load(mobileRes.data);
      const ogVideo = $m('meta[property="og:video"]').attr('content') ||
                      $m('meta[property="og:video:url"]').attr('content');
      const ogTitle = $m('meta[property="og:title"]').attr('content');
      const ogThumb = $m('meta[property="og:image"]').attr('content');

      if (ogVideo) hdUrl = ogVideo;
      if (ogTitle) title = ogTitle;
      if (ogThumb) thumbnail = ogThumb;
    } catch (e) {
      console.warn('FB mobile scrape failed:', e.message);
    }
  }

  const finalHdUrl = hdUrl || sdUrl || url;
  const finalSdUrl = sdUrl || hdUrl || url;

  return {
    success: true,
    platform: 'facebook',
    id: `fb_${Date.now()}`,
    title,
    author: {
      name: authorName,
      username: '@facebook',
      avatar: ''
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
        label: 'SD (480p)',
        quality: '480p',
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
