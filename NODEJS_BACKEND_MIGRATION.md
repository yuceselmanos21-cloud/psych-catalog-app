# Node.js Backend Migration Guide

## 🎯 Genel Bakış

Firebase Functions'tan standalone Node.js backend'e geçiş yapıyoruz. Bu daha esnek, ölçeklenebilir ve maliyet-etkin bir çözüm.

## 📁 Yapı

```
backend/
├── src/
│   ├── index.js              # Express server
│   ├── config/
│   │   └── firebase.js       # Firebase Admin setup
│   ├── middleware/
│   │   ├── auth.js           # Firebase Auth middleware
│   │   └── rateLimit.js      # Rate limiting
│   ├── routes/
│   │   ├── ai.js             # AI analysis endpoints
│   │   └── test.js           # Test analysis endpoints
│   └── services/
│       └── gemini.js         # Gemini API service
├── .env.example
├── package.json
└── README.md
```

## 🚀 Kurulum

### 1. Backend Setup

```bash
cd backend
npm install
cp .env.example .env
# .env dosyasını düzenle
```

### 2. Environment Variables

`.env` dosyasına ekle:

```env
PORT=3000
GEMINI_API_KEY=your_gemini_api_key
FIREBASE_SERVICE_ACCOUNT={"type":"service_account",...}
ALLOWED_ORIGINS=http://localhost:8080,https://yourdomain.com
```

### 3. Firebase Service Account

Firebase Console'dan service account key indir:
1. Firebase Console → Project Settings → Service Accounts
2. "Generate new private key" tıkla
3. JSON'u `.env` dosyasına `FIREBASE_SERVICE_ACCOUNT` olarak ekle

### 4. Backend'i Çalıştır

```bash
npm run dev  # Development
npm start    # Production
```

## 📱 Flutter Client Güncellemesi

`lib/services/analysis_service.dart` dosyası güncellendi:
- Artık REST API kullanıyor (Cloud Functions yerine)
- Firebase ID token ile authentication
- Backend URL'i environment variable'dan alınabilir

### API URL Configuration

Production'da backend URL'ini ayarla:

```dart
static String get _apiUrl {
  const apiUrl = const String.fromEnvironment('API_URL');
  return apiUrl.isNotEmpty ? apiUrl : 'https://your-backend.railway.app';
}
```

Veya compile-time constant:
```dart
static const String _apiUrl = 'https://your-backend.railway.app';
```

## 🌐 Deployment Seçenekleri

### Railway (Önerilen)
1. Railway.app'e git
2. "New Project" → "Deploy from GitHub"
3. Repo'yu seç, `backend/` klasörünü seç
4. Environment variables ekle
5. Deploy!

### Render
1. Render.com'da "New Web Service"
2. GitHub repo'yu bağla
3. Root directory: `backend`
4. Build command: `npm install`
5. Start command: `npm start`
6. Environment variables ekle

### Heroku
```bash
cd backend
heroku create your-app-name
heroku config:set GEMINI_API_KEY=your_key
heroku config:set FIREBASE_SERVICE_ACCOUNT='{"type":"service_account",...}'
git push heroku main
```

## 🔄 Migration Checklist

- [x] Backend yapısı oluşturuldu
- [x] Express server kuruldu
- [x] Firebase Admin entegrasyonu
- [x] Authentication middleware
- [x] AI analysis endpoint
- [x] Test analysis endpoint
- [x] Rate limiting
- [x] Error handling
- [x] Flutter client güncellendi
- [ ] Backend deploy edildi
- [ ] API URL Flutter'da ayarlandı
- [ ] Test edildi
- [ ] Production'a alındı

## 💰 Maliyet Karşılaştırması

### Firebase Functions
- Blaze plan gerekli
- İlk 2M çağrı/ay ücretsiz
- Sonrası: ~$0.40/1M çağrı

### Node.js Backend (Railway/Render)
- Free tier mevcut
- Railway: $5/ay (500 saat)
- Render: Free tier (sleeps after inactivity)
- Daha esnek ölçeklendirme

## 🔐 Güvenlik

- ✅ Firebase ID token authentication
- ✅ Rate limiting (10 req/15min)
- ✅ CORS protection
- ✅ Input validation
- ✅ Error handling
- ✅ API key server-side only

## 📊 API Endpoints

### POST /api/ai/analyze
Text analysis endpoint.

**Request:**
```json
{
  "text": "Text to analyze"
}
```

**Response:**
```json
{
  "success": true,
  "analysis": "AI analysis..."
}
```

### POST /api/test/analyze
Test analysis endpoint (replaces Firebase Function).

**Request:**
```json
{
  "testId": "test_doc_id",
  "docId": "solved_test_doc_id"
}
```

## 🐛 Troubleshooting

### Backend başlamıyor
- `.env` dosyasını kontrol et
- `GEMINI_API_KEY` set edilmiş mi?
- `FIREBASE_SERVICE_ACCOUNT` doğru mu?

### Authentication hatası
- Firebase ID token doğru mu?
- Token expire olmuş olabilir
- Backend CORS ayarlarını kontrol et

### API çağrısı başarısız
- Backend URL doğru mu?
- Network bağlantısı var mı?
- Backend loglarını kontrol et

## 📝 Notlar

- Firebase Functions kodları `functions/` klasöründe kalabilir (backup için)
- Production'da environment variables kullan
- API URL'i Flutter'da compile-time veya runtime'da ayarlanabilir
- Rate limiting production'da önemli

