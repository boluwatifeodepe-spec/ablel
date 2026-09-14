import axios from 'axios';

/**
 * Extract YouTube video/audio details using yt-dlp-web APIs
 * @param {string} url
 * @returns {Promise<Object>}
 */
export async function extractYouTube(url) {
  const isEnabled = process.env.YOUTUBE_ENABLED !== 'false';
  if (!isEnabled) {
    throw new Error('YouTube downloads are temporarily disabled.');
  }

  // Extract video ID
  let videoId = '';
  const match = url.match(/(?:youtu\.be\/|youtube\.com\/(?:embed\/|v\/|watch\?v=|shorts\/|watch\?.+&v=))([\w-]{11})/);
  if (match && match[1]) {
    videoId = match[1];
  } else {
    throw new Error('Invalid YouTube URL or Video ID not found');
  }

  // 1. Fetch metadata via YouTube oEmbed (always works)
  let title = 'YouTube Video';
  let authorName = 'YouTube Creator';
  const thumbnail = `https://i.ytimg.com/vi/${videoId}/hqdefault.jpg`;

  try {
    const oembedRes = await axios.get(
      `https://www.youtube.com/oembed?url=https://www.youtube.com/watch?v=${videoId}&format=json`,
      { timeout: 6000 }
    );
    if (oembedRes.data) {
      title = oembedRes.data.title || title;
      authorName = oembedRes.data.author_name || authorName;
    }
  } catch (e) {
    // continue with defaults
  }

  // 2. Try y2mate API for real stream URLs
  let formats = [];

  try {
    const analyzeRes = await axios.post(
      'https://www.y2mate.com/mates/analyzeV2/ajax',
      new URLSearchParams({
        k_query: `https://www.youtube.com/watch?v=${videoId}`,
        k_page: 'home',
        hl: 'en',
        q_auto: '0'
      }).toString(),
      {
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36'
        },
        timeout: 10000
      }
    );

    if (analyzeRes.data && analyzeRes.data.status === 'ok') {
      const links = analyzeRes.data.links || {};
      const mp4Links = links.mp4 || {};
      const mp3Links = links.mp3 || {};

      // Pick best video quality
      const qualityOrder = ['1080p', '720p', '480p', '360p'];
      for (const q of qualityOrder) {
        if (mp4Links[q] && mp4Links[q].k) {
          try {
            const convertRes = await axios.post(
              'https://www.y2mate.com/mates/convertV2/index',
              new URLSearchParams({
                vid: videoId,
                k: mp4Links[q].k
              }).toString(),
              {
                headers: {
                  'Content-Type': 'application/x-www-form-urlencoded',
                  'User-Agent': 'Mozilla/5.0'
                },
                timeout: 15000
              }
            );
            if (convertRes.data && convertRes.data.dlink) {
              formats.push({
                id: 'video_hd',
                label: `HD PRO (${q})`,
                quality: q,
                type: 'video',
                ext: 'mp4',
                url: convertRes.data.dlink,
                hasAudio: true,
                noWatermark: true
              });
              break;
            }
          } catch (e) { /* skip */ }
        }
      }

      // Pick audio
      const mp3Key = Object.keys(mp3Links)[0];
      if (mp3Key && mp3Links[mp3Key]?.k) {
        try {
          const audioRes = await axios.post(
            'https://www.y2mate.com/mates/convertV2/index',
            new URLSearchParams({
              vid: videoId,
              k: mp3Links[mp3Key].k
            }).toString(),
            {
              headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
              timeout: 15000
            }
          );
          if (audioRes.data && audioRes.data.dlink) {
            formats.push({
              id: 'audio_mp3',
              label: 'Audio Only (MP3)',
              quality: '128kbps',
              type: 'audio',
              ext: 'mp3',
              url: audioRes.data.dlink,
              hasAudio: true,
              noWatermark: true
            });
          }
        } catch (e) { /* skip */ }
      }
    }
  } catch (e) {
    console.warn('y2mate failed for YouTube:', e.message);
  }

  // 3. Fallback: try Invidious y.com.sb API
  if (formats.length === 0) {
    try {
      const invRes = await axios.get(`https://y.com.sb/api/v1/videos/${videoId}`, { timeout: 6000 });
      if (invRes.data && Array.isArray(invRes.data.formatStreams)) {
        const mp4s = invRes.data.formatStreams.filter(s => s.url && s.url.includes('googlevideo'));
        if (mp4s.length > 0) {
          formats.push({
            id: 'video_hd',
            label: 'HD PRO (720p)',
            quality: '720p',
            type: 'video',
            ext: 'mp4',
            url: mp4s[0].url,
            hasAudio: true,
            noWatermark: true
          });
        }
      }
    } catch (e) {
      console.warn('Invidious y.com.sb failed:', e.message);
    }
  }

  // 4. Fallback: try yt1s
  if (formats.length === 0) {
    try {
      const yt1sRes = await axios.post(
        'https://yt1s.com/api/ajaxSearch/index',
        new URLSearchParams({
          q: `https://www.youtube.com/watch?v=${videoId}`,
          vt: 'home'
        }).toString(),
        {
          headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
          timeout: 10000
        }
      );
      if (yt1sRes.data && yt1sRes.data.status === 'ok') {
        const links = yt1sRes.data.links?.mp4 || {};
        const best = links['360p'] || links['480p'] || links['720p'];
        if (best?.k) {
          const dlRes = await axios.post(
            'https://yt1s.com/api/ajaxConvert/convert',
            new URLSearchParams({ vid: videoId, k: best.k }).toString(),
            {
              headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
              timeout: 15000
            }
          );
          if (dlRes.data?.dlink) {
            formats.push({
              id: 'video_hd',
              label: 'HD PRO (720p)',
              quality: '720p',
              type: 'video',
              ext: 'mp4',
              url: dlRes.data.dlink,
              hasAudio: true,
              noWatermark: true
            });
          }
        }
      }
    } catch (e) {
      console.warn('yt1s failed:', e.message);
    }
  }

  if (formats.length === 0) {
    throw new Error('Could not resolve direct video stream for this YouTube video. Please ensure it is public.');
  }

  return {
    success: true,
    platform: 'youtube',
    id: videoId,
    title,
    author: {
      name: authorName,
      username: authorName ? `@${authorName.replace(/\s+/g, '').toLowerCase()}` : '@youtube',
      avatar: thumbnail
    },
    thumbnail,
    duration: '00:00',
    durationSeconds: 0,
    formats
  };
}
