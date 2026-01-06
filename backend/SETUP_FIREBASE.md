# Firebase Admin SDK Kurulumu

## Sorun: "Unauthorized: Invalid token" hatası

Bu hata, Firebase Admin SDK'nın doğru şekilde initialize edilmemesinden kaynaklanır.

## Çözüm: Firebase Service Account Key İndirme

### 1. Firebase Console'a Git
- https://console.firebase.google.com/
- Projenizi seçin

### 2. Service Account Key İndir
1. **Project Settings** (⚙️) → **Service Accounts** sekmesine gidin
2. **Generate New Private Key** butonuna tıklayın
3. JSON dosyasını indirin (örn: `serviceAccountKey.json`)

### 3. Service Account Key'i .env'e Ekle

**Seçenek A: JSON'u .env'e ekle (Önerilen)**
```bash
# backend/.env dosyasına ekleyin:
FIREBASE_SERVICE_ACCOUNT='{"type":"service_account","project_id":"your-project-id",...}'
```

**Seçenek B: JSON dosyasını kullan**
```bash
# backend/.env dosyasına ekleyin:
GOOGLE_APPLICATION_CREDENTIALS=./serviceAccountKey.json
```

### 4. .env Dosyasını Güncelle

`backend/.env` dosyasını açın ve şu satırı güncelleyin:

```env
# Yorum satırını kaldırın ve JSON'u ekleyin:
FIREBASE_SERVICE_ACCOUNT={"type":"service_account","project_id":"your-project-id","private_key_id":"...","private_key":"-----BEGIN PRIVATE KEY-----\n...\n-----END PRIVATE KEY-----\n","client_email":"...","client_id":"...","auth_uri":"...","token_uri":"...","auth_provider_x509_cert_url":"...","client_x509_cert_url":"..."}
```

**ÖNEMLİ:** JSON'u tek satırda yazın, tırnak içinde.

### 5. Backend'i Yeniden Başlat

```bash
cd backend
npm run dev
```

Backend console'da şunu görmelisiniz:
```
✅ Firebase Admin initialized
✅ Firestore available: true
✅ Auth available: true
```

## Alternatif: Geçici Çözüm (Sadece Development)

Eğer service account key'i şimdilik ekleyemiyorsanız, auth middleware'i geçici olarak devre dışı bırakabilirsiniz (SADECE DEVELOPMENT İÇİN):

`backend/src/routes/test.js` dosyasında:
```javascript
// Geçici olarak auth middleware'i kaldırın:
// app.use('/api/test', authMiddleware, testAnalysisRoute);
app.use('/api/test', testAnalysisRoute);
```

**UYARI:** Bu sadece development için geçici bir çözümdür. Production'da MUTLAKA service account kullanın!

