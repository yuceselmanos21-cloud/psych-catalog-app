import axios from 'axios';
import crypto from 'crypto';
import { getDb } from '../config/firebase.js';
import admin from 'firebase-admin';
import { logger } from '../utils/logger.js';

const GEMINI_MODEL = 'gemini-2.0-flash-lite-001';
const MAX_RETRIES = 3;
const RETRY_DELAY_MS = 2000;
const REQUEST_TIMEOUT_MS = 120000;
const CACHE_TTL_MS = 7 * 24 * 60 * 60 * 1000; // 7 gün

/**
 * Create SHA256 hash for cache key
 */
function createCacheKey(testId, answers) {
  const data = JSON.stringify({ testId, answers });
  return crypto.createHash('sha256').update(data).digest('hex');
}

/**
 * Get cached analysis if available
 */
async function getCachedAnalysis(testId, answers) {
  try {
    const db = getDb();
    const cacheKey = createCacheKey(testId, answers);
    const cacheDoc = await db.collection('analysisCache').doc(cacheKey).get();
    
    if (cacheDoc.exists) {
      const data = cacheDoc.data();
      const createdAt = data.createdAt?.toMillis() || 0;
      const age = Date.now() - createdAt;
      
      if (age < CACHE_TTL_MS) {
        logger.info(`[Cache Hit] Analiz cache'den alındı`, { 
          ageMinutes: Math.round(age / 1000 / 60),
          testId,
        });
        return data.analysis;
      } else {
        // Expired cache, delete it
        await db.collection('analysisCache').doc(cacheKey).delete();
        logger.debug(`[Cache Expired] Eski cache silindi`, { testId });
      }
    }
    return null;
  } catch (error) {
    logger.error('Cache okuma hatası', error);
    return null;
  }
}

/**
 * Save analysis to cache
 */
async function setCachedAnalysis(testId, answers, analysis) {
  try {
    const db = getDb();
    const cacheKey = createCacheKey(testId, answers);
    await db.collection('analysisCache').doc(cacheKey).set({
      testId,
      analysis,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      expiresAt: new Date(Date.now() + CACHE_TTL_MS),
    });
    logger.debug(`[Cache Saved] Analiz cache'e kaydedildi`, { testId });
  } catch (error) {
    logger.error('Cache yazma hatası', error);
    // Cache hatası analizi engellemez
  }
}

/**
 * Get Gemini API key from environment (lazy evaluation)
 * This ensures .env is loaded before accessing the key
 */
export function getApiKey() {
  const key = process.env.GEMINI_API_KEY;
  console.log('🔵 getApiKey() called, process.env.GEMINI_API_KEY:', key ? `SET (${key.length} chars)` : 'NOT SET');
  
  if (!key) {
    console.error('❌ GEMINI_API_KEY not found in process.env');
    console.error('❌ All process.env keys:', Object.keys(process.env).sort().join(', '));
    console.error('❌ Available env vars with "API" or "GEMINI":', Object.keys(process.env).filter(k => k.includes('API') || k.includes('GEMINI')));
    throw new Error('GEMINI_API_KEY not configured');
  }
  
  const trimmedKey = key.trim();
  if (trimmedKey.length === 0) {
    console.error('❌ GEMINI_API_KEY is empty after trim');
    throw new Error('GEMINI_API_KEY is empty');
  }
  
  console.log('✅ getApiKey() returning key, length:', trimmedKey.length);
  return trimmedKey;
}

/**
 * Retry helper with exponential backoff
 */
async function retryWithBackoff(fn, maxRetries = MAX_RETRIES, delayMs = RETRY_DELAY_MS) {
  let lastError;

  for (let attempt = 0; attempt < maxRetries; attempt++) {
    try {
      return await fn();
    } catch (error) {
      lastError = error;

      const shouldRetry =
        error.response?.status === 429 ||
        error.response?.status === 503 ||
        error.code === 'ECONNRESET' ||
        error.code === 'ETIMEDOUT';

      if (!shouldRetry || attempt === maxRetries - 1) {
        throw error;
      }

      const backoffDelay = delayMs * Math.pow(2, attempt);
      console.log(`Retry attempt ${attempt + 1}/${maxRetries} after ${backoffDelay}ms`);
      await new Promise((resolve) => setTimeout(resolve, backoffDelay));
    }
  }

  throw lastError;
}

/**
 * Calls Gemini API with retry mechanism
 * @param {Array} parts - Content parts (text and/or images)
 * @param {string|null} systemInstruction - Optional system instruction for better results
 */
async function callGeminiAPI(parts, systemInstruction = null) {
  const AI_API_KEY = getApiKey(); // ✅ Her çağrıda kontrol et
  console.log(`🔵 Gemini API çağrılıyor, API key uzunluğu: ${AI_API_KEY.length}`);
  
  const url = `https://generativelanguage.googleapis.com/v1beta/models/${GEMINI_MODEL}:generateContent?key=${AI_API_KEY}`;

  // Request body with optional system instruction
  const requestBody = {
    contents: [{ parts }],
  };
  
  // Add system instruction if provided (Gemini 2.0+ feature)
  if (systemInstruction) {
    requestBody.systemInstruction = {
      parts: [{ text: systemInstruction }]
    };
  }

  return await retryWithBackoff(async () => {
    const response = await axios.post(
      url,
      requestBody,
      {
        timeout: REQUEST_TIMEOUT_MS,
        headers: { 'Content-Type': 'application/json' },
      }
    );

    const aiResponse =
      response.data?.candidates?.[0]?.content?.parts?.[0]?.text;

    if (!aiResponse || aiResponse.trim().length === 0) {
      throw new Error('Gemini API boş yanıt döndü');
    }

    return aiResponse.trim();
  });
}

/**
 * Analyzes text using Gemini API (for general text analysis screen)
 */
export async function analyzeText(text, attachments = []) {
  const systemInstruction = `Sen çok kapsamlı bilgiye sahip, birkaç deneyimli profesörün bilgi birikimine sahip bir uzmansın. Aşağıdaki alanlarda derin bilgiye sahipsin:

BİLİM ALANLARIN:
1. PSİKOLOJİ: Klinik psikoloji, sosyal psikoloji, gelişim psikolojisi, bilişsel psikoloji, nöropsikoloji, endüstriyel psikoloji
2. PSİKİYATRİ: Ruh sağlığı bozuklukları, nöroloji, psikofarmakoloji (ama sen ilaç önermezsin, sadece bilirsin)
3. SOSYOLOJİ: Toplumsal yapılar, sosyal ilişkiler, kültürel dinamikler, sosyal değişim, toplumsal sorunlar
4. İNSAN İLİŞKİLERİ: İletişim, aile dinamikleri, romantik ilişkiler, arkadaşlık, iş ilişkileri, çatışma çözümü
5. TIP : Anatomi, fizyoloji, sağlık bilgisi, hastalık mekanizmaları (ama sen teşhis koymazsın)
6. BU ALANLARIN TÜMÜNDE VE BU ALANLARIN BENİM UNUTMUŞ DA OLABİLECEĞİM BRANŞLARINDA (ALT ALANLARINDA) EN PROFESYONEL PROFESÖRLERİNİN TOPLAMI BİLGİDESİN. O DERECEDE İŞ ORTAYA KOYMALISIN.
ROLÜN:
- Kullanıcının metnini ve eklerini (varsa) derinlemesine analiz et
- Gerekli olduğu çerçevede Duygusal, bilişsel, davranışsal, sosyal ve fiziksel boyutları değerlendir
- Empatik geri bildirim ver. Ama asla dalkavuk olma. Ne ise o. 
- Uygun uzman önerileri yap (eğer gerekirse)
- Danışılan konuya göre gerekli olduğu çerçevedePsikoloji, tıp, sosyoloji ve insan ilişkileri perspektiflerinden değerlendir. 
Değerlendirirken olumlama yapmak zorunda değilsin, açıklayıcı ve anlaşılır ol. Yasal çerçevede bir uzman geribildirimi ver.

YASAL VE ETİK KURALLAR (ÇOK ÖNEMLİ):
1. ASLA tıbbi teşhis koyma
2. ASLA "hastasın", "hastası", "hastalığın var" gibi ifadeler kullanma
3. ASLA ilaç önerme veya ilaç ismi verme
4.Anlattığına göre gerekirse uygun alanları belirle ve o konuda uzmanla görüşmesini öner.
6. Her zaman "uzmanla görüş", "uzman desteği al", "profesyonel yardım" gibi ifadeler kullan

UZMAN ÖNERİSİ TALİMATLARI:
Analizinde MUTLAKA şunları açıkça belirt (eğer gerekirse):
- Hangi mesleklerle görüşülebileceği:
  * Psikoloji: Psikolog, klinik psikolog, terapist, psikolojik danışman
  * Psikiyatri: Psikiyatr (tıbbi değerlendirme için)
  * Tıp: İlgili tıp uzmanları (dahiliye, nöroloji, endokrinoloji, vb. - fiziksel belirtiler varsa)
  * İnsan İlişkileri: İlişki terapisti, aile terapisti, çift terapisti, iletişim uzmanı
- Hangi uzmanlık alanlarında uzmanlaşmış kişilerle görüşülebileceği:
  * Psikoloji: Depresyon, anksiyete, travma, stres, özgüven, dikkat eksikliği, vb.
  * Tıp: Fiziksel belirtiler, ağrı, uyku bozuklukları, hormonal sorunlar, vb.
  * İnsan İlişkileri: İletişim sorunları, aile dinamikleri, romantik ilişkiler, çatışma çözümü, vb.

Örnek ifadeler:
- "Bir psikolog veya psikiyatr ile görüşmenizi öneririm"
- "Fiziksel belirtiler varsa bir dahiliye uzmanı ile görüşmeniz de faydalı olabilir"
- "Sosyal izolasyon konusunda bir sosyal hizmet uzmanı veya sosyolog ile görüşebilirsiniz"
- "İlişki sorunları için bir çift terapisti veya aile terapisti ile çalışmanızı tavsiye ederim"
- "Depresyon konusunda uzmanlaşmış bir psikolog ile görüşebilirsiniz"

ÇIKTI FORMATI:
1. Kısa Özet (4-5 cümle)
3. Gelişim Alanları veya Dikkat Edilmesi Gerekenler (zayıf yönler veya iyileştirilebilecek noktalar)
4. Detaylı Değerlendirme (kapsamlı analiz)
5. Öneriler (uzman önerileri dahil, eğer gerekirse)

DİL:
- Karşı tarafın dilini kullan(Türkçe, İngilizce, vb.)
- Profesyonel
- Anlaşılır ve net
- Empatik ve destekleyici
- Uzun paragraflardan kaçın (maksimum 3-4 cümle)
- Olumlama yapmak zorunda değilsin, açıklayıcı ve anlaşılır ol.
- Güçlendirici ol`;

  // ✅ Metin varsa ekle, yoksa sadece eklentileri analiz et
  const textContent = text.trim();
  const promptText = textContent.length > 0
    ? `Aşağıdaki metni yukarıdaki kurallara göre analiz et. Net, şeffaf ve anlaşılır bir şekilde durumu açıkla. Anlattığına göre gerekirse uygun alanları belirle ve o konuda uzmanla görüşmesini öner. Eğer gerekirse, hangi mesleklerle (psikolog, psikiyatr, tıp uzmanı, sosyolog, ilişki terapisti, vb.) ve hangi uzmanlık alanlarında uzmanlaşmış kişilerle görüşülebileceğini açıkça belirt.

Metin:
${textContent}`
    : `Yukarıdaki kurallara göre ekli görseli/dosyayı analiz et. Net, şeffaf ve anlaşılır bir şekilde durumu açıkla. Anlattığına göre gerekirse uygun alanları belirle ve o konuda uzmanla görüşmesini öner. Eğer gerekirse, hangi mesleklerle (psikolog, psikiyatr, tıp uzmanı, sosyolog, ilişki terapisti, vb.) ve hangi uzmanlık alanlarında uzmanlaşmış kişilerle görüşülebileceğini açıkça belirt.`;

  const parts = [{ text: promptText }];
  
  // ✅ Eklentileri (attachments) işle - görsel/dosya ekleme özelliği
  if (attachments && attachments.length > 0) {
    for (const attachmentUrl of attachments) {
      // Firebase Storage URL'lerini direkt kullanabiliriz
      // Gemini API görsel URL'lerini destekliyor, ancak Base64 daha güvenilir
      try {
        const base64Image = await downloadImageAsBase64(attachmentUrl);
        if (base64Image) {
          parts.push({
            inlineData: {
              mimeType: 'image/jpeg', // Varsayılan olarak JPEG, gerçek MIME type'ı tespit edilebilir
              data: base64Image,
            },
          });
          parts.push({ text: '\n(Ekli görsel)\n' });
        }
      } catch (error) {
        console.error('Eklenti işleme hatası:', error);
        // Hata durumunda devam et, sadece metin analiz et
      }
    }
  }

  return await callGeminiAPI(parts, systemInstruction);
}

/**
 * Downloads image from URL and converts to Base64
 */
export async function downloadImageAsBase64(url) {
  try {
    const response = await axios.get(url, {
      responseType: 'arraybuffer',
      timeout: 30000,
    });
    return Buffer.from(response.data, 'binary').toString('base64');
  } catch (error) {
    console.error('Resim indirme hatası:', error);
    return null;
  }
}

/**
 * Analyzes test answers (for test solving)
 */
export async function analyzeTestAnswers(docId, testId, data) {
  const db = getDb();

  try {
    console.log(`🔵 [${docId}] Analiz başlatılıyor...`);
    console.log(`📋 Test ID: ${testId}, Soru sayısı: ${data.questions?.length || 0}`);
    
    // ✅ Cache kontrolü (cevaplar aynıysa cache'den al)
    const cachedAnalysis = await getCachedAnalysis(testId, data.answers);
    if (cachedAnalysis) {
      // Cache'den bulundu, direkt kaydet
      await db.collection('solvedTests').doc(docId).update({
        aiAnalysis: cachedAnalysis,
        status: 'completed',
        completedAt: new Date(),
        fromCache: true,
      });
      console.log(`✅ [${docId}] Analiz cache'den tamamlandı`);
      return;
    }
    
    // Get test document (with retry for connection issues)
    let testDoc;
    let retries = 3;
    while (retries > 0) {
      try {
        testDoc = await db.collection('tests').doc(testId).get();
        break;
      } catch (error) {
        retries--;
        if (retries === 0) {
          throw error;
        }
        console.log(`⚠️ Firestore get() failed, retrying... (${retries} left)`);
        await new Promise(resolve => setTimeout(resolve, 1000));
      }
    }
    
    if (!testDoc || !testDoc.exists) {
      throw new Error(`Test document not found: ${testId}`);
    }
    
    const testData = testDoc.data();
    
    // ✅ Geliştirilmiş System Instruction (test'e özel varsa onu kullan, yoksa default)
    const customSystemInstruction = testData?.aiSystemInstruction;
    
    const defaultSystemInstruction = `Sen psikoloji alanında birkaç deneyimli profesörün bilgi birikimine sahip, çok kapsamlı bilgili bir uzmansın. Psikoloji, psikiyatri, nöroloji, sosyal psikoloji, gelişim psikolojisi, klinik psikoloji ve ilgili tüm alanlarda derin bilgiye sahipsin.

ROLÜN:
- Test her şeyini cevaplarıyla beraber derinlemesine analiz et
- Güçlü ve zayıf yönleri belirle ve vurgula
- Duygusal, bilişsel ve davranışsal boyutları değerlendir
- Yapıcı, destekleyici ve empatik geri bildirim ver
- Uygun uzman önerileri yap (eğer gerekirse)

YASAL VE ETİK KURALLAR (ÇOK ÖNEMLİ):
1. ASLA tıbbi teşhis koyma
2. ASLA "hastasın", "hastası", "hastalığın var" gibi ifadeler kullanma
3. ASLA ilaç önerme veya ilaç ismi verme
4. TANI KONUSUNDA ÖRNEK OLARAK BUNU YAP; mesela depresyon hastası olduğunu düşünüyorsan "depresyon hastasısın" demek yerine "depresyon konusunda uzmanlaşmış bir uzmanla görüşmenizi öneririm" de
5. TANI KONUSUNDA ÖRNEK OLARAK BUNU YAP; mesela anksiyete bozukluğu olduğunu düşünüyorsan "anksiyete bozukluğun var" demek yerine "anksiyete konusunda deneyimli bir terapist ile görüşebilirsiniz" de
6. Uzman önerisi konusunda dikkatli ol: Her zaman bir uzmanla görüşmesi söylenmesin. Genel olarak "hayatında her zaman her konuda bir uzman desteği iyi olur" gibi genel bir yaklaşım benimse. Ancak gerçekten ihtiyaç varsa (ciddi belirtiler, sürekli sorunlar, vb.) o zaman destekleyici ve teşvik edici ol. Kullanıcıyı manipüle etme, sadece objektif ve yapıcı önerilerde bulun.

GÜÇLÜ-ZAYIF YÖNLER VURGUSU (ÇOK ÖNEMLİ):
Analizinde MUTLAKA şunları belirt:
- Güçlü Yönler: Kullanıcının güçlü olduğu alanlar, başarılı olduğu noktalar, olumlu özellikler, iyi giden şeyler
- Zayıf Yönler veya Gelişim Alanları: İyileştirilebilecek noktalar, desteklenmesi gereken alanlar, dikkat edilmesi gereken konular
- Her ikisini de dengeli ve yapıcı bir şekilde sun

UZMAN ÖNERİSİ TALİMATLARI:
Analizinde MUTLAKA şunları açıkça belirt (eğer gerekirse):
- Hangi mesleklerle görüşülebileceği (psikolog, psikiyatr, terapist, sosyal hizmet uzmanı, aile danışmanı, vb.)
- Hangi uzmanlık alanlarında uzmanlaşmış kişilerle görüşülebileceği (depresyon, anksiyete, travma, ilişki, aile, çocuk, ergen, dikkat, vb.)

Örnek ifadeler:
- "Bir psikolog veya psikiyatr ile görüşmenizi öneririm"
- "Depresyon konusunda uzmanlaşmış bir uzmanla görüşebilirsiniz"
- "Anksiyete ile ilgili deneyimli bir terapist ile çalışmanızı tavsiye ederim"
- "İlişki terapisi konusunda uzmanlaşmış bir aile terapisti ile görüşmeniz faydalı olabilir"
- "Çocuk psikolojisi konusunda uzmanlaşmış bir çocuk psikologu ile görüşebilirsiniz"

TEST TİPLERİ:
Test cevapları farklı formatlarda olabilir:
- Skala cevapları (1-5 arası sayılar)
- Metin cevapları (açık uçlu yazılı cevaplar)
- Çoktan seçmeli cevaplar (seçeneklerden biri)
- Görsel cevaplar (kullanıcının yüklediği görseller)
- Görsel sorular (soruda görsel olabilir)

Tüm bu formatları dikkate al ve uygun şekilde analiz et.

ÇIKTI FORMATI:
1. Kısa Özet (2-3 cümle)
2. Güçlü Yönler (belirgin güçlü noktalar, başarılı alanlar)
3. Gelişim Alanları veya Dikkat Edilmesi Gerekenler (zayıf yönler veya iyileştirilebilecek noktalar)
4. Detaylı Değerlendirme (kapsamlı analiz, tüm cevapları değerlendir)
5. Öneriler (uzman önerileri dahil, eğer gerekirse)
6. Destekleyici Mesaj (umut verici ve güçlendirici kapanış)

DİL:
- Kullanıcının cevaplarının diline uygun yanıt ver (Türkçe, İngilizce, vb.)
- Eğer kullanıcı Türkçe cevap veriyorsa Türkçe, İngilizce cevap veriyorsa İngilizce yanıt ver
- Samimi ama profesyonel
- Anlaşılır ve net
- Empatik ve destekleyici
- Uzun paragraflardan kaçın (maksimum 5-6 cümle)
- Yargılayıcı veya suçlayıcı olma
- Umut verici ve güçlendirici ol`;

    const systemInstruction = customSystemInstruction || defaultSystemInstruction;

    // Prepare prompt
    const parts = [];
    parts.push({
      text: 'Kullanıcı Cevapları:\n',
    });

    const questions = data.questions;
    const answers = data.answers;

    if (questions && answers) {
      for (let i = 0; i < questions.length; i++) {
        const question = questions[i];
        const ans = answers[i];
        
        // ✅ Soru formatını handle et (string veya Map)
        let questionText = '';
        let questionImageUrl = null;
        
        if (typeof question === 'string') {
          questionText = question;
        } else if (question && typeof question === 'object') {
          questionText = question.text || question.question || '';
          questionImageUrl = question.imageUrl || null;
        }
        
        parts.push({ text: `\nSoru ${i + 1}: ${questionText}\n` });
        
        // ✅ Soruda görsel varsa ekle
        if (questionImageUrl) {
          const questionImage = await downloadImageAsBase64(questionImageUrl);
          if (questionImage) {
            parts.push({
              inlineData: {
                mimeType: 'image/jpeg',
                data: questionImage,
              },
            });
            parts.push({ text: '\n(Soruda görsel var)\n' });
          }
        }

        // ✅ Cevap formatını handle et
        // Cevap tipi: string (metin), number (skala), string (IMAGE_URL:...)
        if (typeof ans === 'string' && ans.startsWith('IMAGE_URL:')) {
          // Görsel cevap
          const url = ans.replace('IMAGE_URL:', '');
          const base64Image = await downloadImageAsBase64(url);

          if (base64Image) {
            parts.push({
              inlineData: {
                mimeType: 'image/jpeg',
                data: base64Image,
              },
            });
            parts.push({ text: '\nCevap: (Kullanıcı görsel yükledi)\n' });
          } else {
            parts.push({ text: '\nCevap: (Görsel indirilemedi)\n' });
          }
        } else if (typeof ans === 'number') {
          // Skala cevabı (1-5 arası)
          parts.push({ text: `Cevap: ${ans} (1-5 skala)\n` });
        } else if (ans && typeof ans === 'object') {
          // Obje formatında cevap
          const answerText = ans.text || ans.answer || ans.toString();
          parts.push({ text: `Cevap: ${answerText}\n` });
        } else {
          // Metin cevabı
          parts.push({ text: `Cevap: ${ans}\n` });
        }
      }
    }

    parts.push({
      text: '\n\nYukarıdaki test cevaplarını yukarıdaki kurallara göre analiz et. Özellikle güçlü ve zayıf yönleri vurgula. Eğer gerekirse, hangi mesleklerle ve hangi uzmanlık alanlarında uzmanlaşmış kişilerle görüşülebileceğini açıkça belirt.',
    });

    // Call Gemini API with system instruction
    logger.info(`[${docId}] Gemini API çağrılıyor`, { testId });
    const aiResponse = await callGeminiAPI(parts, systemInstruction);
    logger.info(`[${docId}] Gemini API yanıt aldı`, { 
      testId, 
      responseLength: aiResponse.length 
    });

    // ✅ Cache'e kaydet
    await setCachedAnalysis(testId, data.answers, aiResponse);

    // Save result
    await db.collection('solvedTests').doc(docId).update({
      aiAnalysis: aiResponse,
      status: 'completed',
      completedAt: new Date(),
      fromCache: false,
    });
    logger.info(`[${docId}] Analiz tamamlandı ve Firestore'a kaydedildi`, { testId });
  } catch (error) {
    logger.error(`[${docId}] AI Hatası`, error);

    let errorMessage = 'Teknik bir hata oluştu.';

    if (error.response) {
      const status = error.response.status;
      if (status === 429) {
        errorMessage =
          'Çok fazla istek gönderildi. Lütfen birkaç dakika sonra tekrar deneyin.';
      } else if (status === 400) {
        errorMessage = 'Geçersiz istek formatı. Lütfen testi tekrar çözün.';
      } else if (status === 401 || status === 403) {
        errorMessage =
          'API anahtarı geçersiz. Sistem yöneticisi ile iletişime geçin.';
      } else if (status >= 500) {
        errorMessage = 'Sunucu hatası. Lütfen daha sonra tekrar deneyin.';
      } else {
        errorMessage = `API hatası (${status}). Lütfen tekrar deneyin.`;
      }
    } else if (error.code === 'ETIMEDOUT' || error.code === 'ECONNABORTED') {
      errorMessage = 'İstek zaman aşımına uğradı. Lütfen tekrar deneyin.';
    } else if (error.message) {
      errorMessage = error.message;
    }

    const db = getDb();
    await db.collection('solvedTests').doc(docId).update({
      status: 'failed',
      aiAnalysis: errorMessage,
      failedAt: new Date(),
      errorDetails: error.toString().substring(0, 500),
    });
  }
}

