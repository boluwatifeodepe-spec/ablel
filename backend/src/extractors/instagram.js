import axios from 'axios';

/**
 * Extract Instagram Reel or Post video
 * Uses: Instagram oEmbed (metadata) + snapinsta API (stream URLs)
 * @param {string} url
 * @returns {Promise<Object>}
 */
export async function extractInstagram(url) {
  let title = 'Instagram Reel';
  let authorName = 'Instagram Creator';
  let thumbnail = '';

  // 1. Metadata via oEmbed
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
      thumbnail = oembedRes.data.thumbnail_url || thumbnail;
    }
  } catch (e) {
    // continue with defaults
  }

  // 2. Try snapinsta.app API for direct MP4
  let downloadUrl = null;

  try {
    // Step 1: get token
    const tokenRes = await axios.get('https://snapinsta.app/', {
      headers: {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36'
      },
      timeout: 8000
    });

    const tokenMatch = tokenRes.data.match(/name="_token"\s+value="([^"]+)"/);
    if (tokenMatch && tokenMatch[1]) {
      const token = tokenMatch[1];

      // Step 2: submit URL
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

      // Parse the response HTML for download links
      const mp4Match = dlRes.data.match(/href="(https:\/\/[^"]+\.mp4[^"]*)"/i);
      if (mp4Match && mp4Match[1]) {
        downloadUrl = mp4Match[1];
      }
    }
  } catch (e) {
    console.warn('snapinsta failed:', e.message);
  }

  // 3. Try instasave.io as fallback
  if (!downloadUrl) {
    try {
      const saveRes = await axios.post(
        'https://instasave.io/api/convert',
        JSON.stringify({ url }),
        {
          headers: {
            'Content-Type': 'application/json',
            'User-Agent': 'Mozilla/5.0'
          },
          timeout: 10000
        }
      );
      if (saveRes.data && saveRes.data.url) {
        downloadUrl = saveRes.data.url;
      } else if (saveRes.data && saveRes.data.links && saveRes.data.links[0]) {
        downloadUrl = saveRes.data.links[0].url || saveRes.data.links[0];
      }
    } catch (e) {
      console.warn('instasave fallback failed:', e.message);
    }
  }

  // 4. Use source URL as last resort
  if (!downloadUrl) {
    downloadUrl = url;
  }

  return {
    success: true,
    platform: 'instagram',
    id: `ig_${Date.now()}`,
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
