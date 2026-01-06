import * as functions from "firebase-functions/v1";
import * as admin from "firebase-admin";
import axios from "axios";

admin.initializeApp();
const db = admin.firestore();

// --- AYARLAR ---
// Terminalden: firebase functions:config:set ai.key="API_KEY"
// Note: functions.config() is deprecated, using process.env as fallback
// eslint-disable-next-line @typescript-eslint/no-explicit-any
const AI_API_KEY = process.env.AI_API_KEY ||
    (process.env.FIREBASE_CONFIG ?
      JSON.parse(process.env.FIREBASE_CONFIG).ai?.key :
      undefined);
const GEMINI_MODEL = "gemini-2.0-flash-lite-001";
const MAX_RETRIES = 3;
const RETRY_DELAY_MS = 2000; // 2 saniye
const REQUEST_TIMEOUT_MS = 120000; // 120 saniye (2 dakika)

// --- SOSYAL MEDYA PUANLARI ---
const POINTS_REPLY = 2;
const POINTS_LIKE = 1;

// ==========================================
// 1. SOSYAL MEDYA (ENGAGEMENT)
// ==========================================

export const onReplyCreated = functions.firestore
  .document("replies/{replyId}")
  .onCreate(async (snap) => {
    const data = snap.data();
    const batch = db.batch();

    // Post sayaçlarını güncelle
    batch.update(db.collection("posts").doc(data.rootPostId), {
      "stats.replyCount": admin.firestore.FieldValue.increment(1),
      "stats.engagement": admin.firestore.FieldValue.increment(POINTS_REPLY),
    });

    // Eğer bir yanıta cevapsa, üst yanıtın puanını artır
    if (data.parentReplyId) {
      batch.update(db.collection("replies").doc(data.parentReplyId), {
        engagement: admin.firestore.FieldValue.increment(POINTS_REPLY),
      });
    }
    await batch.commit();
  });

export const onReplyUpdated = functions.firestore
  .document("replies/{replyId}")
  .onUpdate(async (change) => {
    const newData = change.after.data();
    const oldData = change.before.data();
    // Silindiyse sayaç düş
    if (!oldData.deleted && newData.deleted) {
      await db.collection("posts").doc(newData.rootPostId).update({
        "stats.replyCount": admin.firestore.FieldValue.increment(-1),
      });
    }
  });

export const onReplyLiked = functions.firestore
  .document("replies/{replyId}/likes/{userId}")
  .onCreate(async (snap, context) => {
    await db.collection("replies").doc(context.params.replyId).update({
      engagement: admin.firestore.FieldValue.increment(POINTS_LIKE),
    });
  });

export const onReplyUnliked = functions.firestore
  .document("replies/{replyId}/likes/{userId}")
  .onDelete(async (snap, context) => {
    await db.collection("replies").doc(context.params.replyId).update({
      engagement: admin.firestore.FieldValue.increment(-POINTS_LIKE),
    });
  });

// ==========================================
// 2. AI TEST ANALİZİ & RESİM İŞLEME
// ==========================================

/**
 * Downloads image from URL and converts to Base64.
 * @param {string} url - Image URL
 * @return {Promise<string|null>} Base64 string or null if failed
 */
async function downloadImageAsBase64(url: string): Promise<string | null> {
  try {
    const response = await axios.get(url, {
      responseType: "arraybuffer",
      timeout: 30000, // 30 saniye timeout
    });
    return Buffer.from(response.data, "binary").toString("base64");
  } catch (e) {
    console.error("Resim indirme hatası:", e);
    return null;
  }
}

/**
 * Retry helper with exponential backoff.
 * @param {Function} fn - Function to retry
 * @param {number} maxRetries - Maximum retry attempts
 * @param {number} delayMs - Initial delay in milliseconds
 * @return {Promise} Result of function
 */
async function retryWithBackoff<T>(
  fn: () => Promise<T>,
  maxRetries: number = MAX_RETRIES,
  delayMs: number = RETRY_DELAY_MS
): Promise<T> {
  let lastError: any;

  for (let attempt = 0; attempt < maxRetries; attempt++) {
    try {
      return await fn();
    } catch (error: any) {
      lastError = error;

      // ✅ 429 (Rate Limit) veya 503 (Service Unavailable) için retry
      const shouldRetry = error.response?.status === 429 ||
                               error.response?.status === 503 ||
                               error.code === "ECONNRESET" ||
                               error.code === "ETIMEDOUT";

      if (!shouldRetry || attempt === maxRetries - 1) {
        throw error;
      }

      // Exponential backoff: 2s, 4s, 8s
      const backoffDelay = delayMs * Math.pow(2, attempt);
      console.log(
        `Retry attempt ${attempt + 1}/${maxRetries} after ${backoffDelay}ms`
      );
      await new Promise((resolve) => setTimeout(resolve, backoffDelay));
    }
  }

  throw lastError;
}

/**
 * Calls Gemini API with retry mechanism.
 * @param {Array} parts - Content parts
 * @return {Promise<string>} AI response text
 */
async function callGeminiAPI(
  parts: Array<{text?: string; inlineData?: unknown}>
): Promise<string> {
  const url = "https://generativelanguage.googleapis.com/v1beta/models/" +
      `${GEMINI_MODEL}:generateContent?key=${AI_API_KEY}`;

  return await retryWithBackoff(async () => {
    const response = await axios.post(
      url,
      {contents: [{parts: parts}]},
      {
        timeout: REQUEST_TIMEOUT_MS,
        headers: {"Content-Type": "application/json"},
      }
    );

    const aiResponse =
        response.data?.candidates?.[0]?.content?.parts?.[0]?.text;

    if (!aiResponse || aiResponse.trim().length === 0) {
      throw new Error("Gemini API boş yanıt döndü");
    }

    return aiResponse.trim();
  });
}

export const onTestSolved = functions.firestore
  .document("solvedTests/{docId}")
  .onCreate(async (snap, context) => {
    const docId = context.params.docId;
    const data = snap.data();

    // Sadece 'pending' ise çalış
    if (data.status !== "pending") return;

    if (!AI_API_KEY) {
      await db.collection("solvedTests").doc(docId).update({
        status: "failed",
        aiAnalysis: "Sistem yapılandırma hatası (API Key eksik).",
      });
      return;
    }

    // "Processing" moduna al
    await db.collection("solvedTests").doc(docId).update({
      status: "processing",
    });

    try {
      // Test Talimatını Al
      const testDoc = await db.collection("tests").doc(data.testId).get();
      const testData = testDoc.data();
      const systemInstruction = testData?.aiSystemInstruction ||
          "Sen uzman bir psikologsun. Analiz et.";

      // Prompt Hazırla (Metin + Resim)
      const parts: any[] = [];
      parts.push({text: systemInstruction + "\n\nKullanıcı Cevapları:\n"});

      const questions = data.questions;
      const answers = data.answers;

      if (questions && answers) {
        for (let i = 0; i < questions.length; i++) {
          const ans = answers[i];
          parts.push({text: `\nSoru ${i + 1}: ${questions[i]}\n`});

          // Eğer cevap bir resim URL'i ise
          if (typeof ans === "string" &&
              ans.startsWith("IMAGE_URL:")) {
            const url = ans.replace("IMAGE_URL:", "");
            const base64Image = await downloadImageAsBase64(url);

            if (base64Image) {
              parts.push({
                inlineData: {
                  mimeType: "image/jpeg",
                  data: base64Image,
                },
              });
              parts.push({text: "\n(Kullanıcı görsel yükledi)\n"});
            } else {
              parts.push({text: "\n(Görsel indirilemedi)\n"});
            }
          } else {
            parts.push({text: `Cevap: ${ans}\n`});
          }
        }
      }

      parts.push({text: "\nBu verilere göre analiz yap. Tıbbi teşhis koyma."});

      // ✅ Progress update: API çağrısı başladı
      await db.collection("solvedTests").doc(docId).update({
        status: "processing",
        processingStartedAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      // Gemini API Çağrısı (retry ile)
      const aiResponse = await callGeminiAPI(parts);

      // ✅ Sonucu Kaydet
      await db.collection("solvedTests").doc(docId).update({
        aiAnalysis: aiResponse,
        status: "completed",
        completedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    } catch (error: any) {
      console.error("AI Hatası:", error);

      // ✅ Detaylı hata mesajı
      let errorMessage = "Teknik bir hata oluştu.";

      if (error.response) {
        // HTTP hata kodu
        const status = error.response.status;
        if (status === 429) {
          errorMessage = "Çok fazla istek gönderildi. " +
              "Lütfen birkaç dakika sonra tekrar deneyin.";
        } else if (status === 400) {
          errorMessage = "Geçersiz istek formatı. Lütfen testi tekrar çözün.";
        } else if (status === 401 || status === 403) {
          errorMessage = "API anahtarı geçersiz. " +
              "Sistem yöneticisi ile iletişime geçin.";
        } else if (status >= 500) {
          errorMessage = "Sunucu hatası. Lütfen daha sonra tekrar deneyin.";
        } else {
          errorMessage = `API hatası (${status}). Lütfen tekrar deneyin.`;
        }
      } else if (error.code === "ETIMEDOUT" || error.code === "ECONNABORTED") {
        errorMessage = "İstek zaman aşımına uğradı. Lütfen tekrar deneyin.";
      } else if (error.message) {
        errorMessage = error.message;
      }

      await db.collection("solvedTests").doc(docId).update({
        status: "failed",
        aiAnalysis: errorMessage,
        failedAt: admin.firestore.FieldValue.serverTimestamp(),
        errorDetails: error.toString().substring(0, 500), // İlk 500 karakter
      });
    }
  });

// ==========================================
// 3. TEXT ANALYSIS (Callable Function)
// ==========================================

/**
 * Text analysis callable function.
 * Analyzes user-provided text using Gemini API.
 */
export const analyzeText = functions.https.onCall(async (data, context) => {
  // Authentication kontrolü
  if (!context || !context.auth) {
    throw new functions.https.HttpsError(
      "unauthenticated",
      "Analiz yapmak için giriş yapmalısınız."
    );
  }

  const text = data?.text;

  if (!text || typeof text !== "string" || text.trim().length === 0) {
    throw new functions.https.HttpsError(
      "invalid-argument",
      "Analiz için geçerli bir metin gerekli."
    );
  }

  // Input validation: Max 5000 karakter
  if (text.length > 5000) {
    throw new functions.https.HttpsError(
      "invalid-argument",
      "Metin en fazla 5000 karakter olabilir."
    );
  }

  if (!AI_API_KEY) {
    throw new functions.https.HttpsError(
      "internal",
      "Sistem yapılandırma hatası (API Key eksik)."
    );
  }

  try {
    // Rate limiting için kullanıcı ID'sini logla (ileride eklenebilir)
    // const userId = context.auth.uid;

    // Prompt hazırla
    const promptText = "Sen uzman bir psikologsun. Aşağıdaki metni analiz " +
        "et ve yapıcı geri bildirim ver. Tıbbi teşhis koyma.\n\nMetin:\n" +
        text.trim();
    const parts: Array<{text: string}> = [
      {
        text: promptText,
      },
    ];

    // Gemini API çağrısı (retry ile)
    const aiResponse = await callGeminiAPI(parts);

    return {
      success: true,
      analysis: aiResponse,
    };
  } catch (error: unknown) {
    console.error("Text Analysis Hatası:", error);

    // Detaylı hata mesajı
    let errorMessage = "Teknik bir hata oluştu.";

    if (error && typeof error === "object" && "response" in error) {
      const httpError = error as {response?: {status?: number}};
      const status = httpError.response?.status;
      if (status === 429) {
        errorMessage = "Çok fazla istek gönderildi. " +
            "Lütfen birkaç dakika sonra tekrar deneyin.";
      } else if (status === 400) {
        errorMessage = "Geçersiz istek formatı.";
      } else if (status === 401 || status === 403) {
        errorMessage = "API anahtarı geçersiz.";
      } else if (status && status >= 500) {
        errorMessage = "Sunucu hatası. Lütfen daha sonra tekrar deneyin.";
      } else {
        errorMessage = `API hatası (${status}).`;
      }
    } else if (error && typeof error === "object" && "code" in error) {
      const networkError = error as {code?: string};
      if (networkError.code === "ETIMEDOUT" ||
          networkError.code === "ECONNABORTED") {
        errorMessage = "İstek zaman aşımına uğradı. Lütfen tekrar deneyin.";
      }
    } else if (error && typeof error === "object" && "message" in error) {
      const messageError = error as {message?: string};
      if (messageError.message) {
        errorMessage = messageError.message;
      }
    }

    throw new functions.https.HttpsError(
      "internal",
      errorMessage
    );
  }
});
