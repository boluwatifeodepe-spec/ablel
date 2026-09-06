import express from 'express';
import axios from 'axios';

const router = express.Router();

/**
 * GET /api/proxy?url=...&filename=...
 * Streams media from remote CDN to client with proper Content-Disposition
 */
router.get('/proxy', async (req, res) => {
  try {
    const mediaUrl = req.query.url;
    const filename = req.query.filename || 'media.mp4';

    if (!mediaUrl) {
      return res.status(400).json({ success: false, error: 'URL query parameter is required' });
    }

    const response = await axios({
      method: 'GET',
      url: mediaUrl,
      responseType: 'stream',
      headers: {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36'
      },
      timeout: 30000
    });

    res.setHeader('Content-Disposition', `attachment; filename="${encodeURIComponent(filename)}"`);
    if (response.headers['content-type']) {
      res.setHeader('Content-Type', response.headers['content-type']);
    }
    if (response.headers['content-length']) {
      res.setHeader('Content-Length', response.headers['content-length']);
    }

    response.data.pipe(res);
  } catch (error) {
    console.error('Proxy download stream error:', error.message);
    res.status(502).json({ success: false, error: 'Failed to stream media from source URL.' });
  }
});

export default router;
