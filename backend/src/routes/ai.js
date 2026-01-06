import express from 'express';
import { analyzeText } from '../services/gemini.js';
import { rateLimiter } from '../middleware/rateLimit.js';
import { validateTextAnalysis } from '../middleware/validation.js';
import { getDb } from '../config/firebase.js';
import admin from 'firebase-admin';
import { logger } from '../utils/logger.js';

const router = express.Router();

/**
 * POST /api/ai/analyze
 * Analyzes text using Gemini API and saves to Firestore
 */
router.post('/analyze', rateLimiter, validateTextAnalysis, async (req, res, next) => {
  // ✅ İlk log - route'a ulaşıldı mı?
  console.log('🔵 [ROUTE] /api/ai/analyze endpoint hit!');
  console.log('🔵 [ROUTE] Request method:', req.method);
  console.log('🔵 [ROUTE] Request path:', req.path);
  console.log('🔵 [ROUTE] Request body keys:', Object.keys(req.body || {}));
  console.log('🔵 [ROUTE] Request user:', req.user ? 'exists' : 'null');
  
  try {
    const { text, attachments } = req.body;
    const userId = req.user?.uid;

    logger.info('🔵 AI analyze request received', { 
      userId, 
      hasText: !!text, 
      textLength: text?.length || 0,
      attachmentsCount: attachments?.length || 0,
    });

    if (!userId) {
      logger.error('❌ No userId in request');
      return res.status(401).json({ error: 'Unauthorized' });
    }

    // Analyze text (text is already validated and trimmed by middleware)
    logger.info('🔵 Starting AI analysis...');
    const analysis = await analyzeText(text, attachments || []);
    logger.info('✅ AI analysis completed', { 
      analysisLength: analysis?.length || 0,
    });

    // Save to Firestore (aiConsultations collection)
    let consultationId = null;
    try {
      logger.info('🔵 Starting Firestore save process', { userId });
      
      const db = getDb();
      if (!db) {
        logger.error('❌ Firestore instance is null');
        throw new Error('Firestore instance is null');
      }
      
      logger.info('✅ Firestore instance obtained');
      
      const consultationRef = db.collection('aiConsultations').doc();
      logger.info('✅ Document reference created', { docId: consultationRef.id });
      
      const consultationData = {
        userId,
        text: (text || '').trim(),
        analysis: analysis || '', // ✅ Boş olamaz kontrolü
        attachments: attachments || [],
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      };

      // ✅ Validation: analysis boş olamaz
      if (!consultationData.analysis || consultationData.analysis.trim().length === 0) {
        logger.warn('⚠️ Analysis is empty, skipping Firestore save', { userId });
        return res.json({
          success: true,
          analysis: analysis || '',
          consultationId: null,
        });
      }

      logger.info('📝 Attempting to save AI consultation', { 
        userId,
        textLength: consultationData.text.length,
        analysisLength: consultationData.analysis.length,
        attachmentsCount: consultationData.attachments.length,
        docId: consultationRef.id,
      });

      logger.info('🔵 About to call consultationRef.set()', { 
        docId: consultationRef.id,
        dataKeys: Object.keys(consultationData),
      });
      
      // ✅ Firestore'a kayıt yapmadan önce tüm veriyi log'la
      console.log('🔵 [FIRESTORE] Before set() call:');
      console.log('🔵 [FIRESTORE] docId:', consultationRef.id);
      console.log('🔵 [FIRESTORE] userId:', consultationData.userId);
      console.log('🔵 [FIRESTORE] text length:', consultationData.text.length);
      console.log('🔵 [FIRESTORE] analysis length:', consultationData.analysis.length);
      console.log('🔵 [FIRESTORE] attachments count:', consultationData.attachments.length);
      console.log('🔵 [FIRESTORE] createdAt:', consultationData.createdAt);
      console.log('🔵 [FIRESTORE] updatedAt:', consultationData.updatedAt);
      
      try {
        await consultationRef.set(consultationData);
        console.log('✅ [FIRESTORE] set() call completed successfully');
        consultationId = consultationRef.id;
        console.log('✅ [FIRESTORE] consultationId:', consultationId);
      } catch (setError) {
        console.error('❌ [FIRESTORE] set() call failed:', setError.message);
        console.error('❌ [FIRESTORE] set() error code:', setError.code);
        console.error('❌ [FIRESTORE] set() error stack:', setError.stack);
        throw setError; // Re-throw to be caught by outer catch
      }

      logger.info('✅ AI consultation saved successfully', { 
        consultationId, 
        userId 
      });

      const responseData = {
        success: true,
        analysis,
        consultationId,
      };
      
      logger.info('🔵 Sending response with consultationId', { 
        consultationId,
        hasAnalysis: !!analysis,
        responseKeys: Object.keys(responseData),
      });
      
      // ✅ Console.log ile de kontrol et
      console.log('🔵 [CONSOLE] Response data:', JSON.stringify({
        success: responseData.success,
        hasAnalysis: !!responseData.analysis,
        consultationId: responseData.consultationId,
        consultationIdType: typeof responseData.consultationId,
      }));

      return res.json(responseData);
    } catch (firestoreError) {
      // Firestore hatası analizi engellemez, sadece log'la
      console.error('❌ [CATCH] Firestore error caught!');
      console.error('❌ [CATCH] Error message:', firestoreError.message);
      console.error('❌ [CATCH] Error name:', firestoreError.name);
      console.error('❌ [CATCH] Error code:', firestoreError.code);
      console.error('❌ [CATCH] Error stack:', firestoreError.stack?.substring(0, 500));
      
      logger.error('❌ Failed to save AI consultation to Firestore', {
        error: firestoreError.message,
        errorName: firestoreError.name,
        errorCode: firestoreError.code,
        stack: firestoreError.stack?.substring(0, 500),
        userId,
        textLength: (text || '').trim().length,
        analysisLength: (analysis || '').length,
        consultationId,
      });
      
      // ✅ Hata olsa bile analizi döndür
      // NOT: consultationId: null yerine undefined kullanmayalım, null olarak gönderelim
      const errorResponse = {
        success: true,
        analysis: analysis || '',
        consultationId: null, // ✅ Explicit null
      };
      
      logger.info('🔵 Sending error response (consultationId=null)', {
        hasAnalysis: !!analysis,
        responseKeys: Object.keys(errorResponse),
        consultationIdValue: errorResponse.consultationId,
        consultationIdType: typeof errorResponse.consultationId,
      });
      
      // ✅ Console.log ile de kontrol et
      console.log('❌ [CONSOLE] Error response data:', JSON.stringify(errorResponse, null, 2));
      console.log('❌ [CONSOLE] Error response keys:', Object.keys(errorResponse));
      console.log('❌ [CONSOLE] consultationId value:', errorResponse.consultationId);
      console.log('❌ [CONSOLE] consultationId type:', typeof errorResponse.consultationId);
      console.log('❌ [CONSOLE] Firestore error:', firestoreError.message);
      
      // ✅ Response'u göndermeden önce bir kez daha kontrol et
      // NOT: JSON.parse(JSON.stringify()) null değerleri kaldırmaz, ama yine de kontrol edelim
      const finalResponse = {
        success: true,
        analysis: analysis || '',
        consultationId: null, // ✅ Explicit null - JSON.stringify null'ı korur
      };
      
      console.log('❌ [CONSOLE] Final response object:', finalResponse);
      console.log('❌ [CONSOLE] Final response keys:', Object.keys(finalResponse));
      console.log('❌ [CONSOLE] finalResponse.consultationId:', finalResponse.consultationId);
      console.log('❌ [CONSOLE] typeof finalResponse.consultationId:', typeof finalResponse.consultationId);
      console.log('❌ [CONSOLE] finalResponse.hasOwnProperty("consultationId"):', finalResponse.hasOwnProperty('consultationId'));
      console.log('❌ [CONSOLE] JSON.stringify(finalResponse):', JSON.stringify(finalResponse));
      
      // ✅ Response'u göndermeden önce bir kez daha kontrol et - explicit olarak consultationId ekle
      if (!finalResponse.hasOwnProperty('consultationId')) {
        console.error('❌ [ERROR] consultationId alani response\'da yok! Ekleniyor...');
        finalResponse.consultationId = null;
      }
      
      console.log('❌ [CONSOLE] Sending response with keys:', Object.keys(finalResponse));
      console.log('❌ [CONSOLE] Response will be:', JSON.stringify(finalResponse));
      console.log('❌ [CONSOLE] About to call res.json() with:', JSON.stringify(finalResponse));
      
      // ✅ res.json() çağrısından önce response'u bir kez daha kontrol et
      const responseToSend = res.json(finalResponse);
      console.log('❌ [CONSOLE] res.json() called, response sent');
      
      return responseToSend;
    }
  } catch (error) {
    next(error);
  }
});

export { router as analyzeTextRoute };

