import 'package:cloud_firestore/cloud_firestore.dart';
import '../utils/logger.dart';

/// AI öneri servisi - Kişiselleştirilmiş içerik önerileri
class AIRecommendationService {
  AIRecommendationService._(); // Private constructor

  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Kullanıcı için kişiselleştirilmiş post önerileri
  static Future<List<String>> getPersonalizedPostRecommendations(String userId) async {
    try {
      // Kullanıcının beğendiği postları analiz et
      final likedPosts = await _db
          .collection('posts')
          .where('likedBy', arrayContains: userId)
          .limit(50)
          .get();

      // Kullanıcının takip ettiği uzmanları al
      final followingSnapshot = await _db
          .collection('users')
          .doc(userId)
          .collection('following')
          .get();

      final followingIds = followingSnapshot.docs.map((doc) => doc.id).toList();

      // Beğenilen postların yazarlarını analiz et
      final authorIds = <String, int>{};
      for (var post in likedPosts.docs) {
        final authorId = post.data()['authorId'] as String?;
        if (authorId != null) {
          authorIds[authorId] = (authorIds[authorId] ?? 0) + 1;
        }
      }

      // En çok beğenilen yazarları öner
      final sortedAuthors = authorIds.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));

      // Takip edilmeyen yazarları öner
      final recommendations = sortedAuthors
          .where((entry) => !followingIds.contains(entry.key))
          .take(10)
          .map((entry) => entry.key)
          .toList();

      AppLogger.debug('Personalized recommendations generated', context: {
        'userId': userId,
        'count': recommendations.length,
      });

      return recommendations;
    } catch (e) {
      AppLogger.error('Failed to generate recommendations', error: e);
      return [];
    }
  }

  /// Kullanıcı için kişiselleştirilmiş test önerileri
  static Future<List<String>> getPersonalizedTestRecommendations(String userId) async {
    try {
      // Kullanıcının çözdüğü testleri analiz et
      final solvedTests = await _db
          .collection('solvedTests')
          .where('userId', isEqualTo: userId)
          .limit(50)
          .get();

      // Çözülen testlerin uzmanlarını analiz et
      final expertIds = <String, int>{};
      for (var test in solvedTests.docs) {
        final testId = test.data()['testId'] as String?;
        if (testId != null) {
          final testDoc = await _db.collection('tests').doc(testId).get();
          final expertId = testDoc.data()?['createdBy'] as String?;
          if (expertId != null) {
            expertIds[expertId] = (expertIds[expertId] ?? 0) + 1;
          }
        }
      }

      // En çok çözülen testlerin uzmanlarını öner
      final sortedExperts = expertIds.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));

      // Bu uzmanların diğer testlerini öner
      final recommendations = <String>[];
      for (var expert in sortedExperts.take(5)) {
        final expertTests = await _db
            .collection('tests')
            .where('createdBy', isEqualTo: expert.key)
            .limit(5)
            .get();

        recommendations.addAll(expertTests.docs.map((doc) => doc.id));
      }

      AppLogger.debug('Personalized test recommendations generated', context: {
        'userId': userId,
        'count': recommendations.length,
      });

      return recommendations.take(10).toList();
    } catch (e) {
      AppLogger.error('Failed to generate test recommendations', error: e);
      return [];
    }
  }

  /// Duygu analizi (basit keyword-based)
  static Map<String, double> analyzeSentiment(String text) {
    final textLower = text.toLowerCase();
    
    // Pozitif kelimeler
    final positiveWords = ['mutlu', 'iyi', 'güzel', 'harika', 'mükemmel', 'sevinç', 'neşe'];
    // Negatif kelimeler
    final negativeWords = ['üzgün', 'kötü', 'korku', 'endişe', 'stres', 'depresyon', 'kaygı'];
    
    int positiveCount = 0;
    int negativeCount = 0;
    
    for (var word in positiveWords) {
      if (textLower.contains(word)) positiveCount++;
    }
    
    for (var word in negativeWords) {
      if (textLower.contains(word)) negativeCount++;
    }
    
    final total = positiveCount + negativeCount;
    if (total == 0) {
      return {'neutral': 1.0};
    }
    
    return {
      'positive': positiveCount / total,
      'negative': negativeCount / total,
      'neutral': 1.0 - (positiveCount / total) - (negativeCount / total),
    };
  }
}
