import express from 'express';
import { getDb } from '../config/firebase.js';
import { logger } from '../utils/logger.js';

const router = express.Router();

/**
 * POST /api/search/posts
 * Gönderi araması yapar
 * 
 * Body:
 * - query: string (arama metni)
 * - limit: number (varsayılan: 20, maksimum: 50)
 * - lastDocId: string (pagination için)
 */
router.post('/posts', async (req, res) => {
  try {
    const { query, limit = 20, lastDocId } = req.body;
    const userId = req.user?.uid;

    if (!query || typeof query !== 'string' || query.trim().length === 0) {
      return res.status(400).json({ error: 'Query is required' });
    }

    const searchLimit = Math.min(Math.max(parseInt(limit, 10) || 20, 1), 50);
    const searchQuery = query.trim().toLowerCase();
    const searchTerms = searchQuery.split(/\s+/).filter(term => term.length >= 2);

    if (searchTerms.length === 0) {
      return res.json({ posts: [], hasMore: false });
    }

    const db = getDb();
    let queryRef = db.collection('posts')
      .where('isComment', '==', false)
      .where('deleted', '==', false);

    // Pagination için lastDocId varsa o noktadan devam et
    if (lastDocId) {
      const lastDoc = await db.collection('posts').doc(lastDocId).get();
      if (lastDoc.exists) {
        queryRef = queryRef.startAfter(lastDoc);
      }
    }

    // Tarihe göre sırala ve limit uygula
    queryRef = queryRef.orderBy('createdAt', 'desc').limit(searchLimit + 1);

    const snapshot = await queryRef.get();
    const allDocs = snapshot.docs;
    const hasMore = allDocs.length > searchLimit;
    const docs = hasMore ? allDocs.slice(0, searchLimit) : allDocs;

    // Client-side filtreleme (keywords array veya content içinde arama)
    const filteredPosts = docs
      .map(doc => {
        const data = doc.data();
        const content = (data.content || '').toLowerCase();
        const keywords = (data.keywords || []).map(k => k.toLowerCase());
        
        // Arama terimlerinden en az biri içerikte veya keywords'te var mı?
        const matches = searchTerms.some(term => 
          content.includes(term) || 
          keywords.some(k => k.includes(term))
        );

        if (!matches) return null;

        return {
          id: doc.id,
          authorId: data.authorId,
          content: data.content,
          mediaUrl: data.mediaUrl,
          mediaType: data.mediaType,
          stats: data.stats || { likes: 0, comments: 0, reposts: 0 },
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
      })
      .filter(post => post !== null);

    logger.info('Post search completed', {
      query: searchQuery,
      resultsCount: filteredPosts.length,
      hasMore,
      userId,
    });

    res.json({
      posts: filteredPosts,
      hasMore,
      totalResults: filteredPosts.length,
    });
  } catch (error) {
    logger.error('Post search error', { error: error.message, stack: error.stack });
    res.status(500).json({ error: 'Internal server error' });
  }
});

/**
 * POST /api/search/users
 * Kullanıcı araması yapar
 * 
 * Body:
 * - query: string (arama metni)
 * - role: string ('expert' | 'client' | null)
 * - profession: string (meslek filtresi)
 * - expertise: string (uzmanlık alanı)
 * - limit: number (varsayılan: 20, maksimum: 50)
 * - lastDocId: string (pagination için)
 */
router.post('/users', async (req, res) => {
  try {
    const { query, role, profession, expertise, limit = 20, lastDocId } = req.body;
    const userId = req.user?.uid;

    const searchLimit = Math.min(Math.max(parseInt(limit, 10) || 20, 1), 50);
    const searchQuery = query ? query.trim().toLowerCase() : '';
    const searchTerms = searchQuery ? searchQuery.split(/\s+/).filter(term => term.length >= 2) : [];

    const db = getDb();
    let queryRef = db.collection('users');

    // Role filtresi
    if (role && (role === 'expert' || role === 'client')) {
      queryRef = queryRef.where('role', '==', role);
    }

    // Meslek filtresi (sadece expert için)
    if (profession && profession !== 'all' && role === 'expert') {
      queryRef = queryRef.where('profession', '==', profession);
    }

    // Pagination için lastDocId varsa o noktadan devam et
    if (lastDocId) {
      const lastDoc = await db.collection('users').doc(lastDocId).get();
      if (lastDoc.exists) {
        queryRef = queryRef.startAfter(lastDoc);
      }
    }

    // Limit uygula
    queryRef = queryRef.limit(searchLimit + 1);

    const snapshot = await queryRef.get();
    const allDocs = snapshot.docs;
    const hasMore = allDocs.length > searchLimit;
    const docs = hasMore ? allDocs.slice(0, searchLimit) : allDocs;

    // Client-side filtreleme (isim, username, specialties, expertise)
    const filteredUsers = docs
      .map(doc => {
        const data = doc.data();
        const name = (data.name || '').toLowerCase();
        const username = (data.username || '').toLowerCase();
        const specialties = (data.specialties || '').toLowerCase();

        // Uzmanlık alanı filtresi
        if (expertise && expertise.trim().length > 0) {
          const expertiseLower = expertise.toLowerCase();
          if (!specialties.includes(expertiseLower)) {
            return null;
          }
        }

        // Arama sorgusu varsa filtrele
        if (searchTerms.length > 0) {
          const matches = searchTerms.some(term => 
            name.includes(term) || 
            username.includes(term) ||
            (term.length >= 3 && specialties.includes(term))
          );
          if (!matches) return null;
        }

        return {
          id: doc.id,
          name: data.name,
          username: data.username,
          role: data.role,
          profession: data.profession,
          specialties: data.specialties,
          photoUrl: data.photoUrl,
          city: data.city,
          about: data.about,
          education: data.education,
          supportsOnline: data.supportsOnline || false,
          createdAt: data.createdAt?.toDate?.()?.toISOString() || data.createdAt,
        };
      })
      .filter(user => user !== null);

    logger.info('User search completed', {
      query: searchQuery,
      role,
      profession,
      resultsCount: filteredUsers.length,
      hasMore,
      userId,
    });

    res.json({
      users: filteredUsers,
      hasMore,
      totalResults: filteredUsers.length,
    });
  } catch (error) {
    logger.error('User search error', { error: error.message, stack: error.stack });
    res.status(500).json({ error: 'Internal server error' });
  }
});

export { router as searchRoute };

