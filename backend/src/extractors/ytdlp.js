import { spawn } from 'child_process';
import { promisify } from 'util';
import { exec as execCb } from 'child_process';

const exec = promisify(execCb);

async function getYtDlpPath() {
  const candidates = [
    '/Library/Frameworks/Python.framework/Versions/3.12/bin/yt-dlp',
    '/usr/local/bin/yt-dlp',
    '/usr/bin/yt-dlp',
    'yt-dlp'
  ];

  for (const bin of candidates) {
    try {
      await exec(`${bin} --version`);
      return bin;
    } catch (e) { /* try next */ }
  }

  for (const py of ['python3', 'python']) {
    try {
      await exec(`${py} -m yt_dlp --version`);
      return `${py} -m yt_dlp`;
    } catch (e) { /* try next */ }
  }

  return null;
}

/**
 * Run yt-dlp to extract media JSON info
 * @param {string} url
 * @param {string[]} extraArgs
 * @returns {Promise<Object>}
 */
export async function ytDlpGetInfo(url, extraArgs = []) {
  const ytdlpCmd = await getYtDlpPath();
  if (!ytdlpCmd) throw new Error('yt-dlp is not available');

  const isPythonModule = ytdlpCmd.includes(' -m ');
  let binary = ytdlpCmd;
  let baseArgs = [];

  if (isPythonModule) {
    const parts = ytdlpCmd.split(' ');
    binary = parts[0];
    baseArgs = parts.slice(1);
  }

  const args = [
    ...baseArgs,
    '--no-check-certificate',
    '--dump-json',
    '--no-download',
    '--no-warnings',
    '--no-playlist',
    '--quiet',
    '--geo-bypass',
    '-f', 'bestvideo[ext=mp4]+bestaudio[ext=m4a]/best[ext=mp4]/best',
    '--socket-timeout', '15',
    ...extraArgs,
    url
  ];

  return new Promise((resolve, reject) => {
    let stdout = '';
    let stderr = '';
    const proc = spawn(binary, args, { timeout: 30000 });

    proc.stdout.on('data', (d) => { stdout += d.toString(); });
    proc.stderr.on('data', (d) => { stderr += d.toString(); });

    proc.on('close', (code) => {
      if (code === 0 && stdout) {
        try {
          const firstLine = stdout.trim().split('\n')[0];
          resolve(JSON.parse(firstLine));
        } catch (e) {
          reject(new Error(`yt-dlp JSON parse error: ${e.message}`));
        }
      } else {
        reject(new Error(`yt-dlp code ${code}: ${stderr.substring(0, 100)}`));
      }
    });

    proc.on('error', (e) => reject(new Error(`yt-dlp spawn error: ${e.message}`)));
  });
}

/**
 * Format converter for yt-dlp JSON
 */
export function buildFormatsFromYtDlp(info) {
  const formats = [];

  if (info.url) {
    formats.push({
      id: 'video_hd',
      label: `HD PRO (${info.height || 720}p)`,
      quality: `${info.height || 720}p`,
      type: 'video',
      ext: info.ext || 'mp4',
      url: info.url,
      hasAudio: true,
      noWatermark: true
    });
  }

  if (formats.length === 0 && info.formats) {
    const valid = info.formats.filter(f => f.url && f.vcodec !== 'none').sort((a, b) => (b.height || 0) - (a.height || 0));
    if (valid.length > 0) {
      formats.push({
        id: 'video_hd',
        label: `HD PRO (${valid[0].height || 720}p)`,
        quality: `${valid[0].height || 720}p`,
        type: 'video',
        ext: valid[0].ext || 'mp4',
        url: valid[0].url,
        hasAudio: true,
        noWatermark: true
      });
    }

    const audio = info.formats.filter(f => f.url && f.acodec !== 'none').sort((a, b) => (b.abr || 0) - (a.abr || 0));
    if (audio.length > 0) {
      formats.push({
        id: 'audio_mp3',
        label: 'Audio Only',
        quality: `${audio[0].abr || 128}kbps`,
        type: 'audio',
        ext: 'mp3',
        url: audio[0].url,
        hasAudio: true,
        noWatermark: true
      });
    }
  }

  return formats;
}
