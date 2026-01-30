# Psych Catalog Flutter

Psikoloji uzmanları ve danışanları bir araya getiren sosyal platform.

## 📱 Özellikler

- ✅ Kullanıcı kimlik doğrulama ve profil yönetimi
- ✅ Uzman kayıt ve abonelik sistemi (499₺/ay)
- ✅ Test oluşturma ve çözme
- ✅ AI destekli analiz ve danışma
- ✅ Sosyal feed (post, yorum, beğeni, repost)
- ✅ Mesajlaşma sistemi
- ✅ Arama ve keşfet özellikleri
- ✅ Admin paneli
- ✅ Engelleme ve şikayet sistemi

## 🛠️ Teknoloji Stack

- **Framework:** Flutter 3.0+
- **State Management:** Riverpod 2.4.9
- **Backend:** Firebase (Auth, Firestore, Storage, Functions)
- **Backend API:** Node.js Express
- **Analytics:** Firebase Analytics, Crashlytics

## 🚀 Kurulum

1. Flutter SDK'yı yükleyin (3.0+)
2. Bağımlılıkları yükleyin:
   ```bash
   flutter pub get
   ```
3. Firebase yapılandırmasını tamamlayın (firebase_options.dart)
4. Backend'i başlatın:
   ```bash
   cd backend
   npm install
   npm start
   ```
5. Uygulamayı çalıştırın:
   ```bash
   flutter run
   ```

## 📚 Dokümantasyon

- [APPLICATION_EVALUATION.md](APPLICATION_EVALUATION.md) - Kapsamlı uygulama değerlendirmesi
- [ACCOUNT_DELETION_POLICY.md](ACCOUNT_DELETION_POLICY.md) - Hesap silme politikası
- [DATA_PRESERVATION_POLICY.md](DATA_PRESERVATION_POLICY.md) - Veri koruma politikası
- [ACCOUNT_SUBSCRIPTION_MANAGEMENT.md](ACCOUNT_SUBSCRIPTION_MANAGEMENT.md) - Abonelik yönetimi
- [EXPERT_SUBSCRIPTION_FLOW.md](EXPERT_SUBSCRIPTION_FLOW.md) - Uzman abonelik akışı
- [AI_PROMPT_AND_SCORING_SYSTEM.md](AI_PROMPT_AND_SCORING_SYSTEM.md) - AI prompt ve skorlama sistemi

## 🔒 Güvenlik

- Firestore Security Rules
- Storage Security Rules
- Input validation ve sanitization
- Rate limiting
- XSS protection

## 📊 Production Durumu

Uygulama production'a hazırdır. Detaylı değerlendirme için [APPLICATION_EVALUATION.md](APPLICATION_EVALUATION.md) dosyasına bakın.

**Not:** Payment gateway entegrasyonu (Stripe/PayTR/Iyzico) production için gereklidir.

## 📝 Lisans

Bu proje özel bir projedir.
