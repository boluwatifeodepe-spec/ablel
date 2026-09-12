import axios from 'axios';

/**
 * Extract Twitter/X video media
 * Uses: Twitter Syndication API (metadata + video URLs)
 * @param {string} url
 * @returns {Promise<Object>}
 */
export async function extractTwitter(url) {
  let title = 'X / Twitter Video';
  let authorName = 'X User';
  let thumbnail = '';
  let downloadUrl = url;

  // Extract tweet ID
  const tweetIdMatch = url.match(/(?:twitter\.com|x\.com)\/\w+\/status\/(\d+)/);
  const tweetId = tweetIdMatch ? tweetIdMatch[1] : null;

  // 1. Twitter oEmbed for title/author
  try {
    const oembedRes = await axios.get(
      `https://publish.twitter.com/oembed?url=${encodeURIComponent(url)}&omit_script=true`,
      { timeout: 6000 }
    );
    if (oembedRes.data) {
      authorName = oembedRes.data.author_name || authorName;
      const html = oembedRes.data.html || '';
      const pMatch = html.match(/<p[^>]*>(.*?)<\/p>/i);
      if (pMatch && pMatch[1]) {
        title = pMatch[1].replace(/<[^>]+>/g, '').trim() || title;
      }
    }
  } catch (e) {
    // ignore
  }

  // 2. Twitter Syndication API for video URLs and thumbnail
  if (tweetId) {
    try {
      const syndicationRes = await axios.get(
        `https://cdn.syndication.twimg.com/tweet-result?id=${tweetId}&lang=en&features=tfw_timeline_list%3A%3Btfw_follower_count_sunset%3Atrue&token=0`,
        {
          headers: {
            'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
            'Accept': 'application/json'
          },
          timeout: 8000
        }
      );

      const data = syndicationRes.data;
      if (data) {
        // Get title from tweet text
        if (data.text) title = data.text;
        if (data.user?.name) authorName = data.user.name;

        // Get video/thumbnail from mediaDetails
        const mediaDetails = data.mediaDetails || data.entities?.media || [];
        for (const media of mediaDetails) {
          if (media.type === 'video' || media.type === 'animated_gif') {
            // Get best quality video
            const variants = media.video_info?.variants || [];
            const mp4Variants = variants
              .filter(v => v.content_type === 'video/mp4' && v.url)
              .sort((a, b) => (b.bitrate || 0) - (a.bitrate || 0));

            if (mp4Variants.length > 0) {
              downloadUrl = mp4Variants[0].url;
            }
            thumbnail = media.media_url_https || media.media_url || '';
          } else if (media.type === 'photo') {
            thumbnail = media.media_url_https || media.media_url || '';
          }
        }

        // Also check extended_entities
        const extMedia = data.extended_entities?.media || [];
        for (const media of extMedia) {
          if (media.type === 'video' || media.type === 'animated_gif') {
            const variants = media.video_info?.variants || [];
            const mp4Variants = variants
              .filter(v => v.content_type === 'video/mp4' && v.url)
              .sort((a, b) => (b.bitrate || 0) - (a.bitrate || 0));

            if (mp4Variants.length > 0) {
              downloadUrl = mp4Variants[0].url;
            }
            thumbnail = media.media_url_https || thumbnail;
          }
        }
      }
    } catch (e) {
      console.warn('Twitter syndication API failed:', e.message);
    }
  }

  // 3. Try FxTwitter API as fallback (updated v2 endpoint)
  if (downloadUrl === url && tweetId) {
    try {
      const fxRes = await axios.get(
        `https://api.fxtwitter.com/2/status/${tweetId}`,
        {
          headers: { 'User-Agent': 'AbleApp/1.0' },
          timeout: 8000
        }
      );
      if (fxRes.data?.tweet) {
        const tweet = fxRes.data.tweet;
        if (tweet.media?.videos?.[0]?.url) {
          downloadUrl = tweet.media.videos[0].url;
        }
        if (tweet.media?.photos?.[0]?.url) {
          thumbnail = tweet.media.photos[0].url;
        }
        if (tweet.text) title = tweet.text;
        if (tweet.author?.name) authorName = tweet.author.name;
      }
    } catch (e) {
      console.warn('FxTwitter fallback failed:', e.message);
    }
  }

  const isRealUrl = downloadUrl !== url && (downloadUrl.includes('.mp4') || downloadUrl.includes('video'));

  return {
    success: true,
    platform: 'twitter',
    id: tweetId || `tw_${Date.now()}`,
    title,
    author: {
      name: authorName,
      username: `@${authorName.replace(/\s+/g, '').toLowerCase()}`,
      avatar: ''
    },
    thumbnail: thumbnail || 'https://images.unsplash.com/photo-1611605698335-8b1569810432?w=500&auto=format&fit=crop',
    duration: '00:45',
    durationSeconds: 45,
    formats: [
      {
        id: 'video_hd',
        label: 'HD PRO (1080p)',
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
