import express from 'express';
import cors from 'cors';
import helmet from 'helmet';
import morgan from 'morgan';
import dotenv from 'dotenv';
import extractRoutes from './routes/extract.js';
import proxyRoutes from './routes/proxy.js';

dotenv.config();

const app = express();
const PORT = process.env.PORT || 3000;

// Security and middleware
app.use(helmet({ crossOriginResourcePolicy: false }));
app.use(cors({ origin: '*' }));
app.use(express.json());
app.use(express.urlencoded({ extended: true }));
app.use(morgan('dev'));

// Ping endpoint to keep Render server awake
app.get('/ping', (req, res) => res.json({ status: 'alive' }));
app.get('/api/ping', (req, res) => res.json({ status: 'alive' }));

// Health check endpoint (for Railway, Render, uptime bots)
app.get('/health', (req, res) => {

  res.json({
    status: 'ok',
    service: 'Able Media Extraction Backend',
    version: '1.0.0',
    timestamp: new Date().toISOString()
  });
});

app.get('/api/health', (req, res) => {
  res.json({
    status: 'ok',
    service: 'Able Media Extraction Backend',
    version: '1.0.0',
    timestamp: new Date().toISOString()
  });
});

// Mount routes
app.use('/api', extractRoutes);
app.use('/api', proxyRoutes);

// Root greeting
app.get('/', (req, res) => {
  res.json({
    message: 'Welcome to the Able API backend. Use POST /api/extract to extract media info.',
    health: '/health'
  });
});

// 404 handler
app.use((req, res) => {
  res.status(404).json({ success: false, error: 'Endpoint not found' });
});

// Error handling middleware
app.use((err, req, res, next) => {
  console.error('Unhandled server error:', err);
  res.status(500).json({
    success: false,
    error: 'Internal server error occurred.'
  });
});

// Only start listening if run directly (not imported in tests)
if (process.env.NODE_ENV !== 'test') {
  app.listen(PORT, '0.0.0.0', () => {
    console.log(`⚡ Able Extraction Backend running on http://0.0.0.0:${PORT}`);
  });
}

export default app;
