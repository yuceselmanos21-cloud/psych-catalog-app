import express from 'express';
import { getDb } from '../config/firebase.js';
import { logger } from '../utils/logger.js';

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
 * Keşfet feed'i – tarihe göre sıralı (en yeni en üstte).
 *
 * Body:
 * - limit: number (varsayılan: 20, maksimum: 50)
 * - lastDocId: string (pagination için)
 */
router.post('/feed', async (req, res) => {
  try {
    const { limit = 20, lastDocId, skipCache = false } = req.body;
    const userId = req.user?.uid;

    // Console kopyalama: [FEED_DEBUG] ile başlayan satırları topla
    const ts = new Date().toISOString();
    console.log(`[FEED_DEBUG] ${ts} | DISCOVER_REQUEST | limit=${limit} lastDocId=${lastDocId ?? 'null'} skipCache=${skipCache} userId=${userId ?? 'null'}`);

    // İlk sayfa (lastDocId yok): Cache KULLANMA – her zaman Firestore'dan taze veri
    // Böylece yeni atılan postlar hemen görünür; client skipCache göndermese de çalışır
    const isFirstPage = !lastDocId;
    if (isFirstPage) {
      // İlk sayfa için cache okuma/yazma yok – doğrudan DB'ye git
    } else if (!skipCache) {
      const cacheKey = getCacheKey(userId, lastDocId);
      const cached = getCachedFeed(cacheKey);
      if (cached) {
        const cachedCount = (cached.posts || []).length;
        console.log(`[FEED_DEBUG] ${new Date().toISOString()} | DISCOVER_CACHE_HIT | postsCount=${cachedCount}`);
        logger.info('Discover feed served from cache', { userId });
        return res.json(cached);
      }
    }

    const searchLimit = Math.min(Math.max(parseInt(limit, 10) || 20, 1), 50);
    const db = getDb();

    // Tarihe göre sırala: en yeni en üstte (createdAt desc)
    let queryRef = db.collection('posts')
      .where('isComment', '==', false)
      .where('deleted', '==', false)
      .orderBy('createdAt', 'desc')
      .limit(searchLimit + 1); // pagination için +1

    // Pagination için lastDocId varsa o noktadan devam et
    if (lastDocId) {
      const lastDoc = await db.collection('posts').doc(lastDocId).get();
      if (lastDoc.exists) {
        queryRef = queryRef.startAfter(lastDoc);
      }
    }

    const snapshot = await queryRef.get();
    const allDocs = snapshot.docs;
    const hasMore = allDocs.length > searchLimit;
    const docsToReturn = hasMore ? allDocs.slice(0, searchLimit) : allDocs;
    const finalPosts = docsToReturn.map((doc) => _formatPost(doc, doc.data()));

    logger.info('Discover feed generated', {
      resultsCount: finalPosts.length,
      hasMore,
      userId,
    });

    const response = {
      posts: finalPosts,
      hasMore,
      totalResults: finalPosts.length,
    };

    const postIds = (finalPosts || []).map((p) => p.id).join(',');
    console.log(`[FEED_DEBUG] ${new Date().toISOString()} | DISCOVER_RESPONSE | postsCount=${finalPosts.length} hasMore=${response.hasMore} postIds=${postIds}`);

    // İlk sayfa cache'e yazma (ilk sayfa her zaman taze; cache sadece pagination için kalsın)
    if (lastDocId && !skipCache) {
      const cacheKey = getCacheKey(userId, lastDocId);
      setCachedFeed(cacheKey, response);
    }

    res.json(response);
  } catch (error) {
    logger.error('Discover feed error', { error: error.message, stack: error.stack });
    res.status(500).json({ error: 'Internal server error' });
  }
});

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

