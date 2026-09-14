import axios from 'axios';

/**
 * Extract TikTok video/audio without watermark
 * @param {string} url 
 * @returns {Promise<Object>}
 */
export async function extractTikTok(url) {
  try {
    // Primary: TikWM API (Fast, Reliable, No-Watermark HD/SD + Audio)
    const response = await axios.post(
      'https://www.tikwm.com/api/',
      new URLSearchParams({
        url: url,
        count: '12',
        cursor: '0',
        web: '1',
        hd: '1'
      }).toString(),
      {
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded; charset=UTF-8',
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36'
        },
        timeout: 10000
      }
    );

    if (response.data && response.data.code === 0 && response.data.data) {
      const data = response.data.data;
      
      const formats = [];

      // HD Video without watermark
      if (data.hdplay) {
        formats.push({
          id: 'video_hd',
          label: 'HD PRO',
          quality: '1080p',
          type: 'video',
          ext: 'mp4',
          url: data.hdplay.startsWith('http') ? data.hdplay : `https://www.tikwm.com${data.hdplay}`,
          filesize: data.hd_size || (data.size ? data.size * 1.5 : null),
          hasAudio: true,
          noWatermark: true
        });
      }

      // SD Video without watermark
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

      // Audio only
      if (data.music) {
        formats.push({
          id: 'audio_mp3',
          label: 'Audio (MP3)',
          quality: 'Original',
          type: 'audio',
          ext: 'mp3',
          url: data.music.startsWith('http') ? data.music : `https://www.tikwm.com${data.music}`,
          filesize: null,
          hasAudio: true,
          noWatermark: true
        });
      }

      // Format duration
      const durationSeconds = data.duration || 0;
      const mins = Math.floor(durationSeconds / 60).toString().padStart(2, '0');
      const secs = (durationSeconds % 60).toString().padStart(2, '0');
      const durationStr = `${mins}:${secs}`;

      return {
        success: true,
        platform: 'tiktok',
        id: data.id || `tt_${Date.now()}`,
        title: data.title || 'TikTok Video',
        author: {
          name: data.author?.nickname || 'TikTok User',
          username: data.author?.unique_id ? `@${data.author.unique_id}` : '@user',
          avatar: data.author?.avatar || ''
        },
        thumbnail: data.cover || data.origin_cover || '',
        duration: durationStr,
        durationSeconds: durationSeconds,
        formats: formats.length > 0 ? formats : [
          {
            id: 'video_default',
            label: 'HD',
            quality: '720p',
            type: 'video',
            ext: 'mp4',
            url: data.play || url,
            hasAudio: true,
            noWatermark: true
          }
        ]
      };
    }

    throw new Error('Failed to parse TikTok response from TikWM');
  } catch (error) {
    // Fallback: Try oEmbed + public web parser or throw
    console.error('TikTok extraction error:', error.message);
    
    // Attempt fallback via rapid open parser
    try {
      const oembedRes = await axios.get(`https://www.tiktok.com/oembed?url=${encodeURIComponent(url)}`, {
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
          formats: []
        };
      }
    } catch (e) {
      // ignore
    }

    throw new Error('Could not extract direct TikTok video stream. Please verify the link is valid and public.');
  }
}
