import rateLimit from 'express-rate-limit';

/**
 * Rate limiter for AI analysis endpoints
 * 10 requests per 15 minutes per user
 */
export const rateLimiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: 10, // 10 requests per window
  message: {
    error: 'Çok fazla istek gönderildi. Lütfen birkaç dakika sonra tekrar deneyin.',
  },
  standardHeaders: true,
  legacyHeaders: false,
});

