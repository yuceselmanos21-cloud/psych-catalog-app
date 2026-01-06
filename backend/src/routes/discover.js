import express from 'express';
import { getDb } from '../config/firebase.js';
import { logger } from '../utils/logger.js';
import { Timestamp } from 'firebase-admin/firestore';

// ✅ OPTIMIZED: Simple in-memory cache (5 dakika TTL)
const cache = new Map();
const CACHE_TTL = 5 * 60 * 1000; // 5 dakika

function getCacheKey(userId, lastDocId) {
  return `discover_${userId}_${lastDocId || 'first'}`;
}

function getCachedFeed(key) {
  const cached = cache.get(key);
  if (!cached) return null;
  if (Date.now() - cached.timestamp > CACHE_TTL) {
    cache.delete(key);
    return null;
  }
  return cached.data;
}

function setCachedFeed(key, data) {
  cache.set(key, {
    data,
    timestamp: Date.now(),
  });
  // Cache size limit (max 50 entries)
  if (cache.size > 50) {
    const firstKey = cache.keys().next().value;
    cache.delete(firstKey);
  }
}

const router = express.Router();

/**
 * POST /api/discover/feed
 * Akıllı keşfet feed'i döndürür
 * 
 * Algoritma:
 * 1. Admin boost (yüksek öncelik)
 * 2. Engagement score (like, comment, repost)
 * 3. Recency (yeni içerikler)
 * 4. Diversity (aynı kullanıcıdan çok fazla post gösterme)
 * 5. Herkesin şansı olmalı (randomization)
 * 
 * Body:
 * - limit: number (varsayılan: 20, maksimum: 50)
 * - lastDocId: string (pagination için)
 */
router.post('/feed', async (req, res) => {
  try {
    const { limit = 20, lastDocId } = req.body;
    const userId = req.user?.uid;

    // ✅ OPTIMIZED: Cache kontrolü (sadece ilk sayfa için)
    if (!lastDocId) {
      const cacheKey = getCacheKey(userId, null);
      const cached = getCachedFeed(cacheKey);
      if (cached) {
        logger.info('Discover feed served from cache', { userId });
        return res.json(cached);
      }
    }

    const searchLimit = Math.min(Math.max(parseInt(limit, 10) || 20, 1), 50);
    const db = getDb();

    // 1. Son 7 günün postlarını çek (recency için)
    const sevenDaysAgo = new Date();
    sevenDaysAgo.setDate(sevenDaysAgo.getDate() - 7);
    const sevenDaysAgoTimestamp = Timestamp.fromDate(sevenDaysAgo);
    
    let queryRef = db.collection('posts')
      .where('isComment', '==', false)
      .where('deleted', '==', false)
      .where('createdAt', '>=', sevenDaysAgoTimestamp)
      .orderBy('createdAt', 'desc')
      .limit(200); // Daha fazla çek, sonra score'a göre sırala

    // Pagination için lastDocId varsa o noktadan devam et
    if (lastDocId) {
      const lastDoc = await db.collection('posts').doc(lastDocId).get();
      if (lastDoc.exists) {
        queryRef = queryRef.startAfter(lastDoc);
      }
    }

    const snapshot = await queryRef.get();
    const allDocs = snapshot.docs;

    if (allDocs.length === 0) {
      // Son 7 günde post yoksa, tüm postları çek
      let fallbackQuery = db.collection('posts')
        .where('isComment', '==', false)
        .where('deleted', '==', false)
        .orderBy('createdAt', 'desc')
        .limit(200);

      if (lastDocId) {
        const lastDoc = await db.collection('posts').doc(lastDocId).get();
        if (lastDoc.exists) {
          fallbackQuery = fallbackQuery.startAfter(lastDoc);
        }
      }

      const fallbackSnapshot = await fallbackQuery.get();
      const fallbackDocs = fallbackSnapshot.docs;
      
      // Score hesapla ve sırala
      const scoredPosts = await _scoreAndSortPosts(fallbackDocs, userId, db);
      const finalPosts = _applyDiversity(scoredPosts, searchLimit);
      
      return res.json({
        posts: finalPosts,
        hasMore: fallbackDocs.length >= 200,
        totalResults: finalPosts.length,
      });
    }

    // Score hesapla ve sırala
    const scoredPosts = await _scoreAndSortPosts(allDocs, userId, db);
    const finalPosts = _applyDiversity(scoredPosts, searchLimit);

    logger.info('Discover feed generated', {
      resultsCount: finalPosts.length,
      hasMore: allDocs.length >= 200,
      userId,
    });

    const response = {
      posts: finalPosts,
      hasMore: allDocs.length >= 200,
      totalResults: finalPosts.length,
    };

    // ✅ OPTIMIZED: Cache'e kaydet (sadece ilk sayfa için)
    if (!lastDocId) {
      const cacheKey = getCacheKey(userId, null);
      setCachedFeed(cacheKey, response);
    }

    res.json(response);
  } catch (error) {
    logger.error('Discover feed error', { error: error.message, stack: error.stack });
    res.status(500).json({ error: 'Internal server error' });
  }
});

/**
 * Post'ları score'a göre sıralar
 */
async function _scoreAndSortPosts(docs, userId, db) {
  const scoredPosts = [];

  for (const doc of docs) {
    const data = doc.data();
    const authorId = data.authorId;
    const authorRole = data.authorRole;

    // 1. Admin Boost (yüksek öncelik)
    let adminBoost = 0;
    if (authorRole === 'admin') {
      adminBoost = 1000; // Admin postları en üstte
    }

    // 2. Engagement Score
    const stats = data.stats || {};
    const likeCount = stats.likeCount || 0;
    const replyCount = stats.replyCount || 0;
    const repostCount = stats.repostCount || 0;
    const quoteCount = stats.quoteCount || 0;
    
    // Engagement hesaplama (ağırlıklı)
    const engagementScore = 
      (likeCount * 1) +           // Like: 1 puan
      (replyCount * 3) +          // Yorum: 3 puan (daha değerli)
      (repostCount * 2) +         // Repost: 2 puan
      (quoteCount * 4);           // Quote: 4 puan (en değerli)

    // 3. Recency Score (yeni içerikler daha yüksek)
    const createdAt = data.createdAt?.toDate?.() || new Date(data.createdAt);
    const now = new Date();
    const hoursAgo = (now - createdAt) / (1000 * 60 * 60);
    
    // Son 24 saat: 100 puan, son 7 gün: 50 puan, daha eski: 10 puan
    let recencyScore = 10;
    if (hoursAgo < 24) {
      recencyScore = 100;
    } else if (hoursAgo < 168) { // 7 gün
      recencyScore = 50;
    }

    // 4. Expert Boost (hafif öncelik)
    let expertBoost = 0;
    if (authorRole === 'expert') {
      expertBoost = 20;
    }

    // 5. Toplam Score
    const totalScore = adminBoost + engagementScore + recencyScore + expertBoost;

    // 6. Randomization (herkesin şansı olsun)
    // Score'a %10-20 arası random ekle (düşük score'lu postların da şansı olsun)
    const randomFactor = Math.random() * (totalScore * 0.2);
    const finalScore = totalScore + randomFactor;

    scoredPosts.push({
      doc,
      data,
      score: finalScore,
      authorId,
      authorRole,
      engagementScore,
      recencyScore,
      adminBoost,
      expertBoost,
    });
  }

  // Score'a göre sırala (yüksekten düşüğe)
  scoredPosts.sort((a, b) => b.score - a.score);

  return scoredPosts;
}

/**
 * Diversity uygula: Aynı kullanıcıdan çok fazla post gösterme
 */
function _applyDiversity(scoredPosts, limit) {
  const authorCounts = new Map();
  const finalPosts = [];
  const maxPostsPerAuthor = Math.ceil(limit * 0.3); // Her kullanıcıdan maksimum %30

  for (const item of scoredPosts) {
    const authorId = item.authorId;
    const currentCount = authorCounts.get(authorId) || 0;

    // Admin postları her zaman dahil et
    if (item.authorRole === 'admin') {
      finalPosts.push(_formatPost(item.doc, item.data));
      continue;
    }

    // Diğer kullanıcılar için diversity uygula
    if (currentCount < maxPostsPerAuthor) {
      finalPosts.push(_formatPost(item.doc, item.data));
      authorCounts.set(authorId, currentCount + 1);
    }

    if (finalPosts.length >= limit) {
      break;
    }
  }

  return finalPosts;
}

/**
 * Post'u API formatına çevir
 */
function _formatPost(doc, data) {
  return {
    id: doc.id,
    authorId: data.authorId,
    content: data.content,
    mediaUrl: data.mediaUrl,
    mediaType: data.mediaType,
    mediaName: data.mediaName,
    stats: data.stats || { likeCount: 0, replyCount: 0, repostCount: 0, quoteCount: 0 },
    createdAt: data.createdAt?.toDate?.()?.toISOString() || data.createdAt,
    editedAt: data.editedAt?.toDate?.()?.toISOString() || data.editedAt,
    authorName: data.authorName,
    authorUsername: data.authorUsername,
    authorRole: data.authorRole,
    authorProfession: data.authorProfession,
    isComment: data.isComment || false,
    rootPostId: data.rootPostId,
    repostOfPostId: data.repostOfPostId,
    isQuoteRepost: data.isQuoteRepost || false,
    repostedByUserId: data.repostedByUserId,
    repostedByName: data.repostedByName,
    repostedByUsername: data.repostedByUsername,
    repostedByRole: data.repostedByRole,
    mentionedUserIds: data.mentionedUserIds || [],
  };
}

export { router as discoverRoute };

