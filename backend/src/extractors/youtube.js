import axios from 'axios';
import ytdl from '@distube/ytdl-core';
import { ytDlpGetInfo, buildFormatsFromYtDlp } from './ytdlp.js';

/**
 * Extract YouTube video/audio details
 * Primary: yt-dlp (fast & reliable with --no-check-certificate)
 * Secondary: @distube/ytdl-core
 * Tertiary: Invidious / oEmbed metadata
 * @param {string} url
 * @returns {Promise<Object>}
 */
export async function extractYouTube(url) {
  const isEnabled = process.env.YOUTUBE_ENABLED !== 'false';
  if (!isEnabled) {
    throw new Error('YouTube downloads are temporarily disabled.');
  }

  const match = url.match(/(?:youtu\.be\/|youtube\.com\/(?:embed\/|v\/|watch\?v=|shorts\/|watch\?.+&v=))([\w-]{11})/);
  if (!match || !match[1]) {
    throw new Error('Invalid YouTube URL or Video ID not found');
  }
  const videoId = match[1];
  const canonicalUrl = `https://www.youtube.com/watch?v=${videoId}`;
  const thumbnail = `https://i.ytimg.com/vi/${videoId}/hqdefault.jpg`;
  let title = 'YouTube Video';
  let authorName = 'YouTube Creator';
  let formats = [];

  // Fetch oEmbed title & author for baseline metadata
  try {
    const oe = await axios.get(
      `https://www.youtube.com/oembed?url=${encodeURIComponent(canonicalUrl)}&format=json`,
      { timeout: 4000 }
    );
    if (oe.data) {
      title = oe.data.title || title;
      authorName = oe.data.author_name || authorName;
    }
  } catch (e) { /* ignore */ }

  // ── 1. PRIMARY: yt-dlp ───────────────────────────────────────────────────
  try {
    const info = await ytDlpGetInfo(canonicalUrl);
    if (info) {
      title = info.title || title;
      authorName = info.uploader || info.channel || authorName;
      const parsedFormats = buildFormatsFromYtDlp(info);
      if (parsedFormats.length > 0) {
        formats = parsedFormats;
        console.log(`yt-dlp YouTube success for ${videoId}`);
      }
    }
  } catch (e) {
    console.warn('yt-dlp YouTube failed:', e.message);
  }

  // ── 2. SECONDARY: @distube/ytdl-core ─────────────────────────────────────
  if (formats.length === 0) {
    try {
      const info = await ytdl.getInfo(canonicalUrl, {
        requestOptions: {
          headers: {
            'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36'
          }
        }
      });
      title = info.videoDetails.title || title;
      authorName = info.videoDetails.author?.name || authorName;

      const videoFormats = ytdl.filterFormats(info.formats, 'videoandaudio');
      const bestVideo = videoFormats.sort((a, b) => (b.height || 0) - (a.height || 0))[0];
      const audioFormats = ytdl.filterFormats(info.formats, 'audioonly');
      const bestAudio = audioFormats.sort((a, b) => (b.audioBitrate || 0) - (a.audioBitrate || 0))[0];

      if (bestVideo) {
        formats.push({
          id: 'video_hd',
          label: `HD PRO (${bestVideo.height || 720}p)`,
          quality: `${bestVideo.height || 720}p`,
          type: 'video',
          ext: 'mp4',
          url: bestVideo.url,
          hasAudio: true,
          noWatermark: true
        });
      }
      if (bestAudio) {
        formats.push({
          id: 'audio_mp3',
          label: 'Audio Only',
          quality: `${bestAudio.audioBitrate || 128}kbps`,
          type: 'audio',
          ext: 'mp3',
          url: bestAudio.url,
          hasAudio: true,
          noWatermark: true
        });
      }
      if (formats.length > 0) console.log('ytdl-core: success');
    } catch (e) {
      console.warn('ytdl-core failed:', e.message);
    }
  }

  // ── 3. TERTIARY: Invidious Instances ──────────────────────────────────────
  if (formats.length === 0) {
    const invInstances = [
      'https://invidious.projectsegfau.lt',
      'https://iv.ggtyler.dev',
      'https://invidious.nerdvpn.de',
      'https://inv.tux.pizza'
    ];
    for (const inst of invInstances) {
      try {
        const res = await axios.get(`${inst}/api/v1/videos/${videoId}`, { timeout: 5000 });
        if (res.data?.formatStreams) {
          title = res.data.title || title;
          authorName = res.data.author || authorName;
          const mp4s = res.data.formatStreams.filter(s => s.url);
          if (mp4s.length > 0) {
            formats.push({
              id: 'video_hd',
              label: `HD PRO (${mp4s[0].qualityLabel || '720p'})`,
              quality: mp4s[0].qualityLabel || '720p',
              type: 'video',
              ext: 'mp4',
              url: mp4s[0].url,
              hasAudio: true,
              noWatermark: true
            });
            break;
          }
        }
      } catch (e) { /* ignore */ }
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
