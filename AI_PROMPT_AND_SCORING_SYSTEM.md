# AI Prompt ve Uzman Önerisi Puanlama Sistemi

## 📋 İçindekiler
1. [AI Prompt'ları](#ai-promptları)
2. [Puanlama Sistemi](#puanlama-sistemi)
3. [Sıralama Algoritması](#sıralama-algoritması)
4. [Öneri Limitleri](#öneri-limitleri)

---

## 🤖 AI Prompt'ları

### 1. Test Analizi için Prompt

**Dosya:** `backend/src/services/gemini.js` - `analyzeTestAnswers()`

**System Instruction (Varsayılan):**
```
Sen uzman bir psikologsun. Analiz et.
```

**System Instruction (Test'e Özel):**
- Her test için `tests` koleksiyonunda `aiSystemInstruction` alanı varsa o kullanılır
- Yoksa varsayılan yukarıdaki prompt kullanılır

**Tam Prompt Yapısı:**
```
[System Instruction]

Kullanıcı Cevapları:

Soru 1: [Soru metni]
Cevap: [Kullanıcı cevabı]

Soru 2: [Soru metni]
Cevap: [Kullanıcı cevabı]

... (tüm sorular ve cevaplar)

[Eğer görsel cevap varsa:]
(Kullanıcı görsel yükledi)
[Base64 encoded görsel]

Bu verilere göre analiz yap. Tıbbi teşhis koyma.
```

**Örnek:**
```
Sen uzman bir psikologsun. Analiz et.

Kullanıcı Cevapları:

Soru 1: Son zamanlarda kendinizi nasıl hissediyorsunuz?
Cevap: Çok kötü, hiçbir şey yapmak istemiyorum

Soru 2: Uyku düzeniniz nasıl?
Cevap: Çok az uyuyorum, uyuyamıyorum

Bu verilere göre analiz yap. Tıbbi teşhis koyma.
```

### 2. Genel Metin Analizi için Prompt

**Dosya:** `backend/src/services/gemini.js` - `analyzeText()`

**Prompt:**
```
Sen uzman bir psikologsun. Aşağıdaki metni analiz et ve yapıcı geri bildirim ver. Tıbbi teşhis koyma.

Metin:
[Kullanıcı metni]
```

---

## 📊 Puanlama Sistemi

### Toplam Puan Hesaplama

Her uzman için toplam puan aşağıdaki kriterlere göre hesaplanır:

### 1. Şehir Eşleşmesi
- **Puan:** 70 puan
- **Açıklama:** Kullanıcının şehri ile uzmanın şehri eşleşiyorsa
- **Kod:** `lib/screens/result_detail_screen.dart` - Satır 195-199

### 2. Online Görüşme Bonusu (Şehir Dışı)
- **Puan:** 25 puan
- **Açıklama:** Şehir dışı uzmanlar için online görüşme yapabiliyorsa
- **Kod:** `lib/screens/result_detail_screen.dart` - Satır 201-204

### 3. Uzmanlık Alanı Eşleşmesi
- **Base Puan:** 50 puan
- **AI Önerisi Bonusu:** +30 puan (AI'ın önerdiği uzmanlık alanlarıyla eşleşme)
- **Tam Eşleşme Bonusu:** +15 puan (her tam eşleşme için)
- **Güçlü Eşleşme Bonusu:** +12 puan (her güçlü eşleşme için)
- **Kısmi Eşleşme Bonusu:** +4 puan (her kısmi eşleşme için)

**Toplam Maksimum:** 50 + 30 + (15 × n) + (12 × m) + (4 × k) puan

**Açıklama:**
- AI analizinden çıkarılan uzmanlık alanları (depresyon, anksiyete, vb.) ile uzmanın specialties alanı karşılaştırılır
- AI'ın önerdiği uzmanlık alanlarıyla eşleşme varsa ekstra 30 puan bonus

**Kod:** `lib/screens/result_detail_screen.dart` - Satır 206-263

### 4. Profesyon (Meslek) Eşleşmesi
- **Base Puan:** 30 puan
- **AI Önerisi Bonusu:** +25 puan (AI'ın önerdiği mesleklerle eşleşme)
- **Her Eşleşme Bonusu:** +4 puan

**Toplam Maksimum:** 30 + 25 + (4 × n) puan

**Açıklama:**
- AI analizinden çıkarılan meslek önerileri (psikolog, psikiyatr, terapist, vb.) ile uzmanın profession alanı karşılaştırılır
- AI'ın önerdiği mesleklerle eşleşme varsa ekstra 25 puan bonus

**Kod:** `lib/screens/result_detail_screen.dart` - Satır 265-295

### 5. About/Hakkımda Eşleşmesi
- **Base Puan:** 15 puan
- **Güçlü Eşleşme Bonusu:** +5 puan (her güçlü eşleşme için - 4+ karakter keyword)
- **Normal Eşleşme Bonusu:** +2 puan (her normal eşleşme için - 3+ karakter keyword)

**Toplam Maksimum:** 15 + (5 × n) + (2 × m) puan

**Kod:** `lib/screens/result_detail_screen.dart` - Satır 297-314

### 6. Popülerlik (Takipçi Sayısı)
- **Puan:** 0-12 puan (maksimum)
- **Formül:** `(followersCount / 10).clamp(0, 12)`
- **Açıklama:** 
  - 10 takipçi = 1 puan
  - 120+ takipçi = 12 puan (maksimum)

**Kod:** `lib/screens/result_detail_screen.dart` - Satır 316-321

### 7. Deneyim (Hesap Yaşı)
- **Puan:** 0-12 puan (maksimum)
- **Formül:** `(accountAge / 30.4).clamp(0, 12)`
- **Açıklama:**
  - 30.4 gün (yaklaşık 1 ay) = 1 puan
  - 365 gün (1 yıl) = 12 puan (maksimum)

**Kod:** `lib/screens/result_detail_screen.dart` - Satır 323-329

### 8. Online Görüşme Bonusu (Genel)
- **Puan:** 5 puan
- **Açıklama:** Online görüşme yapabilen tüm uzmanlar için (şehir içi/dışı fark etmez)

**Kod:** `lib/screens/result_detail_screen.dart` - Satır 331-334

### 9. Testi Oluşturan Uzman Bonusu ⭐
- **Puan:** 100 puan
- **Açıklama:** Testi oluşturan uzmana çok yüksek bonus (en yüksek öncelik)
- **Kod:** `lib/screens/result_detail_screen.dart` - Satır 336-340

---

## 🔄 Sıralama Algoritması

Uzmanlar aşağıdaki öncelik sırasına göre sıralanır:

### 1. Testi Oluşturan Uzman (EN YÜKSEK ÖNCELİK)
- Testi oluşturan uzman her zaman ilk sırada gösterilir
- Diğer tüm kriterlerden önce gelir

### 2. Şehir İçi Uzmanlar
- Şehir içi uzmanlar, şehir dışı uzmanlardan önce gösterilir

### 3. Skor (Yüksekten Düşüğe)
- Aynı kategorideyse (ikisi de şehir içi veya ikisi de şehir dışı) skora göre sıralanır

### 4. Online Görüşme
- Eşit skorlarda online görüşme yapabilenler öncelikli

### 5. Specialty Matches
- Her şey eşitse uzmanlık alanı eşleşme sayısına bakılır

**Kod:** `lib/screens/result_detail_screen.dart` - Satır 355-392

---

## 📈 Öneri Limitleri

- **Şehir İçi Uzmanlar:** 15 uzman
- **Şehir Dışı Uzmanlar:** 10 uzman

**Toplam:** Maksimum 25 uzman önerilir

**Kod:** `lib/screens/result_detail_screen.dart` - Satır 394-405

---

## 🎯 AI'dan Çıkarılan Bilgiler

### 1. Anahtar Kelimeler
- **Fonksiyon:** `_extractKeywordsAdvanced()`
- **Açıklama:** AI analizinden önemli kelimeler çıkarılır
- **Özellikler:**
  - Yaygın kelimeler filtrelenir
  - Psikoloji terimlerine bonus puan verilir
  - En önemli 15 kelime seçilir

### 2. Meslek Önerileri
- **Fonksiyon:** `_extractRecommendedProfessions()`
- **Açıklama:** AI analizinden hangi mesleklerle görüşülebileceği çıkarılır
- **Örnekler:** "psikolog ile görüş", "bir psikiyatr öneririm"
- **Desteklenen Meslekler:**
  - Psikolog, Klinik Psikolog, Nöropsikolog
  - Psikiyatr, Psikiyatrist
  - Terapist, Psikoterapist
  - Aile Terapisti, Çift Terapisti
  - Çocuk Psikologu, Ergen Psikologu
  - Sosyal Hizmet Uzmanı, Aile Danışmanı
  - Diyetisyen, Yaşam Koçu, vb.

### 3. Uzmanlık Alanı Önerileri
- **Fonksiyon:** `_extractRecommendedSpecialties()`
- **Açıklama:** AI analizinden hangi uzmanlık alanlarında uzmanlaşmış kişilerle görüşülebileceği çıkarılır
- **Örnekler:** "depresyon konusunda uzmanlaşmış psikolog", "anksiyete ile ilgili uzman"
- **Desteklenen Uzmanlık Alanları:**
  - Depresyon, Anksiyete, Panik, Fobi
  - Travma, Stres, Yeme Bozukluğu
  - Bağımlılık, İlişki, Aile, Çocuk
  - Dikkat, Otizm, Kişilik, vb.

---

## 📝 Örnek Puanlama Senaryosu

### Senaryo: Depresyon Testi Çözen Kullanıcı

**AI Analizi:**
- "Depresyon belirtileri gösteriyorsunuz. Bir psikolog veya psikiyatr ile görüşmenizi öneririm."
- "Depresyon konusunda uzmanlaşmış bir uzmanla görüşebilirsiniz."

**Çıkarılan Bilgiler:**
- **Meslekler:** psikolog, psikiyatr
- **Uzmanlık Alanları:** depresyon
- **Anahtar Kelimeler:** depresyon, belirti, öner, görüş

**Uzman A (Şehir İçi, Depresyon Uzmanı Psikolog):**
- Şehir eşleşmesi: +70
- Uzmanlık alanı (depresyon - AI önerisi): +50 + 30 (AI bonus) = +80
- Profesyon (psikolog - AI önerisi): +30 + 25 (AI bonus) = +55
- Popülerlik (50 takipçi): +5
- Deneyim (6 ay): +6
- Online görüşme: +5
- **TOPLAM: 221 puan**

**Uzman B (Şehir Dışı, Genel Psikolog):**
- Şehir eşleşmesi: 0
- Online görüşme bonusu: +25
- Uzmanlık alanı (kısmi eşleşme): +50 + 4 = +54
- Profesyon (psikolog - AI önerisi): +30 + 25 (AI bonus) = +55
- Popülerlik (100 takipçi): +10
- Deneyim (1 yıl): +12
- Online görüşme: +5
- **TOPLAM: 161 puan**

**Sonuç:** Uzman A öncelikli gösterilir (şehir içi + AI önerileriyle eşleşme)

---

## 🔧 Teknik Detaylar

### Model
- **Gemini Model:** `gemini-2.0-flash-lite-001`
- **API Endpoint:** `https://generativelanguage.googleapis.com/v1beta/models/{MODEL}:generateContent`

### Retry Mekanizması
- **Max Retries:** 3
- **Retry Delay:** 2 saniye (exponential backoff: 2s, 4s, 8s)
- **Timeout:** 120 saniye

### Hata Yönetimi
- **429 (Rate Limit):** Retry yapılır
- **503 (Service Unavailable):** Retry yapılır
- **401/403 (Unauthorized):** Hata mesajı gösterilir
- **Timeout:** Hata mesajı gösterilir

---

## 📌 Notlar

1. **Tıbbi Teşhis:** AI hiçbir zaman tıbbi teşhis koymaz, sadece analiz ve öneri yapar
2. **Görsel Desteği:** Test cevaplarında görsel varsa Base64 formatında Gemini API'ye gönderilir
3. **Cache:** Genel metin analizi için client-side cache kullanılır
4. **Güvenlik:** Tüm API çağrıları Firebase ID token ile doğrulanır

---

**Son Güncelleme:** 2025-01-05
**Versiyon:** 2.0

