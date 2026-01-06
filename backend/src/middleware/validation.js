/**
 * Input validation middleware
 */

/**
 * Validates test analysis request
 */
export function validateTestAnalysis(req, res, next) {
  const { testId, docId } = req.body;

  // Check if required fields exist
  if (!testId || typeof testId !== 'string' || testId.trim().length === 0) {
    return res.status(400).json({
      error: 'testId gerekli ve geçerli bir string olmalı',
    });
  }

  if (testId.length > 100) {
    return res.status(400).json({
      error: 'testId çok uzun (maksimum 100 karakter)',
    });
  }

  if (!docId || typeof docId !== 'string' || docId.trim().length === 0) {
    return res.status(400).json({
      error: 'docId gerekli ve geçerli bir string olmalı',
    });
  }

  if (docId.length > 100) {
    return res.status(400).json({
      error: 'docId çok uzun (maksimum 100 karakter)',
    });
  }

  // Sanitize inputs
  req.body.testId = testId.trim();
  req.body.docId = docId.trim();

  next();
}

/**
 * Validates AI text analysis request
 */
export function validateTextAnalysis(req, res, next) {
  const { text, attachments } = req.body;

  // ✅ Metin veya eklenti olmalı (ikisi de boş olamaz)
  const hasAttachments = attachments && Array.isArray(attachments) && attachments.length > 0;

  if (!text || typeof text !== 'string') {
    // Eğer eklenti varsa, metin opsiyonel olabilir
    if (!hasAttachments) {
      return res.status(400).json({
        error: 'text gerekli ve geçerli bir string olmalı (veya eklenti eklemelisiniz)',
      });
    }
    // Eklenti varsa, boş string olarak kabul et
    req.body.text = '';
  }

  const trimmedText = (text || '').trim();

  // ✅ Eğer eklenti yoksa, metin zorunlu ve en az 10 karakter olmalı
  if (!hasAttachments) {
    if (trimmedText.length === 0) {
      return res.status(400).json({
        error: 'text boş olamaz (veya eklenti eklemelisiniz)',
      });
    }

    if (trimmedText.length < 10) {
      return res.status(400).json({
        error: 'text en az 10 karakter olmalı (veya eklenti eklemelisiniz)',
      });
    }
  }

  if (trimmedText.length > 5000) {
    return res.status(400).json({
      error: 'text en fazla 5000 karakter olabilir',
    });
  }

  // Sanitize input
  req.body.text = trimmedText;

  next();
}

