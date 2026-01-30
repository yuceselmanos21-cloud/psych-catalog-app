import express from 'express';
import cors from 'cors';
import dotenv from 'dotenv';
import { fileURLToPath } from 'url';
import { dirname, join } from 'path';
import { existsSync } from 'fs';
import { initializeFirebase } from './config/firebase.js';
import { authMiddleware } from './middleware/auth.js';
import { analyzeTextRoute } from './routes/ai.js';
import { testAnalysisRoute } from './routes/test.js';
import { searchRoute } from './routes/search.js';
import { discoverRoute } from './routes/discover.js';

// ✅ .env dosyasını backend klasöründen oku
const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);
const envPath = join(__dirname, '../.env');

const result = dotenv.config({ path: envPath });
if (result.error) {
  console.warn('⚠️  Error loading .env:', result.error.message);
} else {
  console.log('✅ .env loaded from:', envPath);
  console.log('✅ .env file exists:', existsSync(envPath));
}

// ✅ Proxy ayarlarını temizle (yanlış proxy ayarları Firestore bağlantısını engelleyebilir)
if (process.env.http_proxy && process.env.http_proxy.includes('127.0.0.1:9')) {
  console.warn('⚠️  Invalid proxy detected, disabling...');
  delete process.env.http_proxy;
  delete process.env.HTTP_PROXY;
}
if (process.env.https_proxy && process.env.https_proxy.includes('127.0.0.1:9')) {
  console.warn('⚠️  Invalid proxy detected, disabling...');
  delete process.env.https_proxy;
  delete process.env.HTTPS_PROXY;
}

// ✅ Hemen GEMINI_API_KEY kontrolü (dotenv.config sonrası)
console.log('🔵 Immediate GEMINI_API_KEY check after dotenv.config:');
console.log('  - process.env.GEMINI_API_KEY:', process.env.GEMINI_API_KEY ? `SET (${process.env.GEMINI_API_KEY.length} chars)` : 'NOT SET');
console.log('  - All env keys with "API" or "GEMINI":', Object.keys(process.env).filter(k => k.includes('API') || k.includes('GEMINI')));

console.log('🔵 FIREBASE_SERVICE_ACCOUNT:', process.env.FIREBASE_SERVICE_ACCOUNT ? 'SET' : 'NOT SET');
if (process.env.FIREBASE_SERVICE_ACCOUNT) {
  const firstChars = process.env.FIREBASE_SERVICE_ACCOUNT.substring(0, 100);
  console.log('🔵 First 100 chars:', firstChars);
  try {
    const parsed = JSON.parse(process.env.FIREBASE_SERVICE_ACCOUNT);
    console.log('✅ JSON is valid, project_id:', parsed.project_id);
  } catch (e) {
    console.error('❌ JSON parse error:', e.message);
  }
}

// ✅ GEMINI_API_KEY kontrolü
console.log('🔵 GEMINI_API_KEY:', process.env.GEMINI_API_KEY ? `SET (${process.env.GEMINI_API_KEY.length} karakter, başlangıç: ${process.env.GEMINI_API_KEY.substring(0, 10)}...)` : 'NOT SET');
if (!process.env.GEMINI_API_KEY) {
  console.error('❌ ============================================');
  console.error('❌ GEMINI_API_KEY environment variable not set!');
  console.error('❌ AI analysis features will not work');
  console.error('❌ Please add GEMINI_API_KEY to .env file');
  console.error('❌ ============================================');
}

const app = express();
const PORT = process.env.PORT || 3000;

// Initialize Firebase Admin (OPTIONAL for development)
console.log('🔵 Initializing Firebase Admin at startup...');
let firebaseInitialized = false;
try {
  const adminApp = initializeFirebase();
  if (adminApp && adminApp.options.projectId) {
    console.log('✅ Firebase Admin initialized successfully at startup');
    console.log('✅ Project ID:', adminApp.options.projectId);
    firebaseInitialized = true;
  } else {
    throw new Error('Firebase Admin initialization returned invalid app');
  }
} catch (error) {
  console.warn('⚠️  ============================================');
  console.warn('⚠️  Firebase initialization failed at startup!');
  console.warn('⚠️  Error message:', error.message);
  console.warn('⚠️  ============================================');
  console.warn('⚠️  Server will start but Firebase features will be disabled');
  console.warn('⚠️  To enable Firebase, please check:');
  console.warn('⚠️    1. FIREBASE_SERVICE_ACCOUNT in .env file');
  console.warn('⚠️    2. .env file path:', join(__dirname, '../.env'));
  console.warn('⚠️    3. JSON format is valid');
  console.warn('⚠️  ============================================');
  firebaseInitialized = false;
  // ✅ Server'ı durdurma, development için çalışmaya devam et
}

// Middleware
app.use(cors({
  origin: function (origin, callback) {
    // Development: Tüm origin'lere izin ver (Flutter web için)
    if (process.env.NODE_ENV === 'production') {
      const allowedOrigins = process.env.ALLOWED_ORIGINS?.split(',') || [];
      if (!origin || allowedOrigins.includes(origin)) {
        callback(null, true);
      } else {
        callback(new Error('CORS policy violation'));
      }
    } else {
      // Development: Her şeye izin ver
      callback(null, true);
    }
  },
  credentials: true,
  methods: ['GET', 'POST', 'PUT', 'DELETE', 'OPTIONS'],
  allowedHeaders: ['Content-Type', 'Authorization'],
}));
app.use(express.json({ limit: '10mb' }));
app.use(express.urlencoded({ extended: true }));

// Health check
app.get('/health', (req, res) => {
  res.json({ status: 'ok', timestamp: new Date().toISOString() });
});

// Debug endpoint - API key kontrolü
app.get('/debug/api-key', (req, res) => {
  const key = process.env.GEMINI_API_KEY;
  res.json({
    hasKey: !!key,
    keyLength: key ? key.length : 0,
    keyPreview: key ? `${key.substring(0, 10)}...${key.substring(key.length - 5)}` : null,
    allEnvKeys: Object.keys(process.env).filter(k => k.includes('API') || k.includes('GEMINI')),
    nodeEnv: process.env.NODE_ENV,
  });
});

// API Routes
// ✅ Development için: Eğer FIREBASE_SERVICE_ACCOUNT yoksa auth'u atla
const skipAuth = !process.env.FIREBASE_SERVICE_ACCOUNT && process.env.NODE_ENV !== 'production';

if (skipAuth) {
  console.warn('⚠️  WARNING: Running without authentication (development mode)');
  console.warn('⚠️  Set FIREBASE_SERVICE_ACCOUNT in .env for production');
  app.use('/api/ai', analyzeTextRoute);
  app.use('/api/test', testAnalysisRoute);
  app.use('/api/search', searchRoute);
  app.use('/api/discover', discoverRoute);
} else {
  app.use('/api/ai', authMiddleware, analyzeTextRoute);
  app.use('/api/test', authMiddleware, testAnalysisRoute);
  app.use('/api/search', authMiddleware, searchRoute);
  app.use('/api/discover', authMiddleware, discoverRoute);
}

// Error handling
app.use((err, req, res, next) => {
  console.error('Error:', err);
  res.status(err.status || 500).json({
    error: err.message || 'Internal server error',
  });
});

// 404 handler
app.use((req, res) => {
  res.status(404).json({ error: 'Route not found' });
});

// Start server
app.listen(PORT, () => {
  console.log(`🚀 Server running on port ${PORT}`);
  console.log(`📝 Environment: ${process.env.NODE_ENV || 'development'}`);
});

