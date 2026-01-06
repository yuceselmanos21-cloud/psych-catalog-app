import express from 'express';
import { getDb } from '../config/firebase.js';
import { analyzeTestAnswers } from '../services/gemini.js';
import { validateTestAnalysis } from '../middleware/validation.js';
import { logger } from '../utils/logger.js';

const router = express.Router();

/**
 * POST /api/test/analyze
 * Analyzes test answers (triggered when test is solved)
 * This replaces the Firebase Function onTestSolved
 */
router.post('/analyze', validateTestAnalysis, async (req, res, next) => {
  try {
    const { testId, docId } = req.body;
    logger.info('Test analiz isteği alındı', { testId, docId });

    // Get Firestore instance (ensures Firebase is initialized)
    const db = getDb();

    // Get solved test document
    const solvedTestDoc = await db.collection('solvedTests').doc(docId).get();
    
    if (!solvedTestDoc.exists) {
      logger.warn('Test dokümanı bulunamadı', { docId });
      return res.status(404).json({ error: 'Test bulunamadı' });
    }

    const data = solvedTestDoc.data();
    logger.debug('Test dokümanı bulundu', { docId, status: data.status });
    
    if (data.status !== 'pending') {
      logger.warn('Test zaten işlenmiş', { docId, status: data.status });
      return res.status(400).json({ error: 'Test zaten işlenmiş' });
    }

    // Update status to processing
    await db.collection('solvedTests').doc(docId).update({
      status: 'processing',
      processingStartedAt: new Date(),
    });
    logger.debug('Status processing olarak güncellendi', { docId });

    // Analyze in background (don't wait for response)
    analyzeTestAnswers(docId, testId, data).catch((error) => {
      logger.error(`Test analysis error [${docId}]`, error);
    });

    res.json({
      success: true,
      message: 'Analiz başlatıldı',
    });
    logger.info('Analiz başlatıldı, yanıt gönderildi', { docId, testId });
  } catch (error) {
    logger.error('Route error', error);
    next(error);
  }
});

export { router as testAnalysisRoute };

