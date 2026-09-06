import express from 'express';
import { detectPlatform, normalizeUrl } from '../utils/detector.js';
import { extractTikTok } from '../extractors/tiktok.js';
import { extractYouTube } from '../extractors/youtube.js';
import { extractInstagram } from '../extractors/instagram.js';
import { extractTwitter } from '../extractors/twitter.js';
import { extractFacebook } from '../extractors/facebook.js';

const router = express.Router();

// Supported platform handlers map
const extractors = {
  tiktok: extractTikTok,
  youtube: extractYouTube,
  instagram: extractInstagram,
  twitter: extractTwitter,
  facebook: extractFacebook
};

/**
 * POST /api/extract
 * Request Body: { "url": "https://..." }
 */
router.post('/extract', async (req, res) => {
  try {
    const { url } = req.body;

    if (!url || typeof url !== 'string') {
      return res.status(400).json({
        success: false,
        error: 'Please provide a valid media URL in the request body.'
      });
    }

    const normalizedUrl = normalizeUrl(url);
    const platform = detectPlatform(normalizedUrl);

    if (platform === 'unknown') {
      // Return a friendly error or attempt generic fallback
      return res.status(422).json({
        success: false,
        error: 'Unsupported platform. Supported platforms: TikTok, Instagram, YouTube, X/Twitter, Facebook.'
      });
    }

    const extractor = extractors[platform];
    if (!extractor) {
      return res.status(501).json({
        success: false,
        error: `Extractor for ${platform} is not implemented yet.`
      });
    }

    const result = await extractor(normalizedUrl);
    return res.status(200).json(result);
  } catch (error) {
    console.error('Error during media extraction:', error);
    return res.status(500).json({
      success: false,
      error: error.message || 'Failed to extract media from the provided URL.'
    });
  }
});

/**
 * GET /api/platforms
 * List currently supported platforms and feature status
 */
router.get('/platforms', (req, res) => {
  res.json({
    success: true,
    platforms: [
      { id: 'tiktok', name: 'TikTok', enabled: true },
      { id: 'instagram', name: 'Instagram', enabled: true },
      { id: 'youtube', name: 'YouTube', enabled: process.env.YOUTUBE_ENABLED !== 'false' },
      { id: 'twitter', name: 'Twitter / X', enabled: true },
      { id: 'facebook', name: 'Facebook', enabled: true }
    ]
  });
});

export default router;
