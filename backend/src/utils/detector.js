/**
 * Detect social platform from a given URL
 * @param {string} rawUrl 
 * @returns {'tiktok' | 'instagram' | 'youtube' | 'twitter' | 'facebook' | 'unknown'}
 */
export function detectPlatform(rawUrl) {
  if (!rawUrl || typeof rawUrl !== 'string') return 'unknown';

  const clean = rawUrl.trim().toLowerCase();

  if (/tiktok\.com|douyin\.com|vt\.tiktok\.com|vm\.tiktok\.com/i.test(clean)) {
    return 'tiktok';
  }
  if (/instagram\.com|instagr\.am/i.test(clean)) {
    return 'instagram';
  }
  if (/youtube\.com|youtu\.be/i.test(clean)) {
    return 'youtube';
  }
  if (/twitter\.com|x\.com|t\.co/i.test(clean)) {
    return 'twitter';
  }
  if (/facebook\.com|fb\.watch|fb\.me|fb\.com/i.test(clean)) {
    return 'facebook';
  }

  return 'unknown';
}

/**
 * Clean and normalize URL
 * @param {string} rawUrl 
 * @returns {string}
 */
export function normalizeUrl(rawUrl) {
  if (!rawUrl) return '';
  let url = rawUrl.trim();
  // Strip trailing tracking parameters if needed or keep full url
  if (!url.startsWith('http://') && !url.startsWith('https://')) {
    url = `https://${url}`;
  }
  return url;
}
