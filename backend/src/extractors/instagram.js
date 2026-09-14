import axios from 'axios';

function cleanJsonUrl(raw) {
  if (!raw) return '';
  return raw.replace(/\\\/|\\/g, '/').replace(/\\u0026/g, '&').replace(/&amp;/g, '&');
}

/**
 * Extract Instagram Reel or Post video
 * Uses: Instagram Embed HTML + oEmbed + snapinsta API (stream URLs)
 * @param {string} url
 * @returns {Promise<Object>}
 */
export async function extractInstagram(url) {
  const shortcodeMatch = url.match(/(?:reel|p|tv|stories\/[^\/]+)\/([A-Za-z0-9_-]+)/);
  const shortcode = shortcodeMatch ? shortcodeMatch[1] : null;

  let title = 'Instagram Reel';
  let authorName = 'Instagram Creator';
  let thumbnail = '';
  let downloadUrl = null;

  // 1. Metadata via Instagram Embed HTML
  if (shortcode) {
    try {
      const embedRes = await axios.get(`https://www.instagram.com/p/${shortcode}/embed/captioned/`, {
        headers: {
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36'
        },
        timeout: 6000
      });
      const html = embedRes.data.toString();
      const videoMatch = html.match(/"video_url"\s*:\s*"([^"]+)"/) || html.match(/<video[^>]+src="([^"]+)"/);
      if (videoMatch && videoMatch[1]) {
        downloadUrl = cleanJsonUrl(videoMatch[1]);
      }
      const imgMatch = html.match(/<img[^>]+class="EmbeddedMediaImage"[^>]+src="([^"]+)"/) || html.match(/"display_url"\s*:\s*"([^"]+)"/);
      if (imgMatch && imgMatch[1]) {
        thumbnail = cleanJsonUrl(imgMatch[1]);
      }
    } catch (e) {
      // continue
    }
  }

  // 2. Metadata via oEmbed
  try {
    const oembedRes = await axios.get(
      `https://api.instagram.com/oembed/?url=${encodeURIComponent(url)}`,
      {
        timeout: 6000,
        headers: {
          'User-Agent': 'Mozilla/5.0 (iPhone; CPU iPhone OS 16_5 like Mac OS X) AppleWebKit/605.1.15'
        }
      }
    );
    if (oembedRes.data) {
      title = oembedRes.data.title || title;
      authorName = oembedRes.data.author_name || authorName;
      if (!thumbnail) thumbnail = oembedRes.data.thumbnail_url || thumbnail;
    }
  } catch (e) {
    // continue with defaults
  }

  // 3. Try snapinsta.app API for direct MP4 if not resolved
  if (!downloadUrl) {
    try {
      const tokenRes = await axios.get('https://snapinsta.app/', {
        headers: {
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36'
        },
        timeout: 8000
      });

      const tokenMatch = tokenRes.data.match(/name="_token"\s+value="([^"]+)"/);
      if (tokenMatch && tokenMatch[1]) {
        const token = tokenMatch[1];
        const dlRes = await axios.post(
          'https://snapinsta.app/action.php',
          new URLSearchParams({ url, _token: token }).toString(),
          {
            headers: {
              'Content-Type': 'application/x-www-form-urlencoded',
              'User-Agent': 'Mozilla/5.0',
              'Referer': 'https://snapinsta.app/'
            },
            timeout: 12000
          }
        );

        const mp4Match = dlRes.data.match(/href="(https:\/\/[^"]+\.mp4[^"]*)"/i);
        if (mp4Match && mp4Match[1]) {
          downloadUrl = cleanJsonUrl(mp4Match[1]);
        }
      }
    } catch (e) {
      console.warn('snapinsta failed:', e.message);
    }
  }

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
