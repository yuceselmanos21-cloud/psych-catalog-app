import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../widgets/friendly_error_widget.dart';
import '../widgets/skeleton_loading.dart';
import '../services/expert_cache.dart';

class ResultDetailScreen extends StatelessWidget {
  final String testTitle;
  final String aiAnalysis;
  final DateTime? solvedAt;
  final List<dynamic>? questions;
  final List<dynamic>? answers;
  final String? testId; // Testi oluşturan uzmanı bulmak için

  const ResultDetailScreen({
    super.key,
    this.testTitle = 'Test Sonucu',
    this.aiAnalysis = '',
    this.solvedAt,
    this.questions,
    this.answers,
    this.testId,
  });

  // ✅ OPTİMİZE EDİLMİŞ: Şehir içi ve şehir dışı uzmanları ayrı query'lerle çek + Cache
  Stream<List<DocumentSnapshot>> _getOptimizedExpertStream(String? myCity) async* {
    // ✅ Cache kontrolü
    final cached = ExpertCache.get(myCity);
    if (cached != null && cached.isNotEmpty) {
      yield cached;
      // Cache'den geldi, ama yine de stream'i dinlemeye devam et (real-time updates için)
    }

    if (myCity == null || myCity.isEmpty) {
      // Şehir bilgisi yoksa, sadece online destekleyen uzmanları çek
      yield* FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: 'expert')
          .where('supportsOnline', isEqualTo: true)
          .limit(25)
          .snapshots()
          .map((snapshot) {
            final docs = snapshot.docs;
            // Cache'e kaydet
            ExpertCache.set(myCity, docs);
            return docs;
          });
      return;
    }

    // Şehir içi ve şehir dışı uzmanları birleştir
    final localQuery = FirebaseFirestore.instance
        .collection('users')
        .where('role', isEqualTo: 'expert')
        .where('city', isEqualTo: myCity)
        .limit(20);

    final remoteQuery = FirebaseFirestore.instance
        .collection('users')
        .where('role', isEqualTo: 'expert')
        .where('supportsOnline', isEqualTo: true)
        .limit(15);

    // İki query'yi birleştir
    await for (final localSnapshot in localQuery.snapshots()) {
      final remoteSnapshot = await remoteQuery.get();
      
      final localDocs = localSnapshot.docs;
      final remoteDocs = remoteSnapshot.docs;
      
      // Şehir dışı olanları filtrele (şehir bilgisi farklı olanlar)
      final filteredRemote = remoteDocs.where((doc) {
        final data = doc.data() as Map<String, dynamic>?;
        final expertCity = (data?['city'] ?? '').toString().toLowerCase().trim();
        return expertCity != myCity.toLowerCase().trim();
      }).toList();
      
      final allDocs = [...localDocs, ...filteredRemote];
      // Cache'e kaydet
      ExpertCache.set(myCity, allDocs);
      yield allDocs;
    }
  }

  @override
  Widget build(BuildContext context) {
    final myUid = FirebaseAuth.instance.currentUser?.uid;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(title: Text(testTitle)),
      body: FutureBuilder<DocumentSnapshot>(
        future: myUid != null ? FirebaseFirestore.instance.collection('users').doc(myUid).get() : null,
        builder: (context, userSnap) {
          if (userSnap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          String? myCity;
          if (userSnap.hasData && userSnap.data!.exists) {
            final uData = userSnap.data!.data() as Map<String, dynamic>;
            myCity = (uData['city'] ?? '').toString().toLowerCase().trim();
          }

          return RefreshIndicator(
            onRefresh: () async {
              // Cache'i temizle ve yeniden yükle
              ExpertCache.clearCity(myCity);
              // StreamBuilder otomatik olarak yeniden yükler
            },
            color: Colors.deepPurple,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Sorular ve Cevaplar Bölümü
                  if (questions != null && questions!.isNotEmpty && answers != null && answers!.isNotEmpty) ...[
                    Text(
                      "Sorular ve Cevapların",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 10),
                    ...List.generate(questions!.length, (index) {
                      return _buildQuestionAnswerCard(
                        context,
                        index + 1,
                        questions![index],
                        index < answers!.length ? answers![index] : null,
                        isDark,
                      );
                    }),
                    const SizedBox(height: 30),
                  ],

                  // AI Analiz Kutusu
                  Text(
                    "AI Analizi ve Değerlendirme",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.deepPurple.shade900.withOpacity(0.3) : Colors.deepPurple.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isDark ? Colors.deepPurple.shade700 : Colors.deepPurple.shade100,
                      ),
                    ),
                    child: aiAnalysis.isEmpty
                        ? Column(
                            children: [
                              const CircularProgressIndicator(),
                              const SizedBox(height: 16),
                              Text(
                                "Analiz hazırlanıyor...\nBu işlem 30-60 saniye sürebilir.",
                                style: TextStyle(
                                  fontSize: 14,
                                  color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          )
                        : Text(
                            aiAnalysis,
                            style: TextStyle(
                              fontSize: 15,
                              height: 1.5,
                              color: isDark ? Colors.grey.shade200 : Colors.black87,
                            ),
                          ),
                  ),
                  const SizedBox(height: 30),

                  // AKILLI ÖNERİ SİSTEMİ
                  Text(
                    "Sana Yardımcı Olabilecek Uzmanlar",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "AI analizine ve konumuna göre özel öneriler:",
                    style: TextStyle(
                      color: isDark ? Colors.grey.shade400 : Colors.grey,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 10),

                  // ✅ Testi oluşturan uzmanı bul
                  FutureBuilder<String?>(
                    future: testId != null && testId!.isNotEmpty
                        ? FirebaseFirestore.instance
                            .collection('tests')
                            .doc(testId)
                            .get()
                            .then((doc) {
                              if (doc.exists) {
                                final data = doc.data();
                                return data?['createdBy']?.toString();
                              }
                              return null;
                            })
                            .catchError((e) {
                              debugPrint('Test creator bulunamadı: $e');
                              return null;
                            })
                        : Future.value(null),
                    builder: (context, testCreatorSnap) {
                      final testCreatorId = testCreatorSnap.data;
                      
                      // ✅ OPTİMİZE EDİLMİŞ: Şehir içi ve şehir dışı uzmanları ayrı query'lerle çek
                      return StreamBuilder<List<DocumentSnapshot>>(
                        stream: _getOptimizedExpertStream(myCity),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState == ConnectionState.waiting) {
                            return ExpertListSkeleton(isDark: isDark, count: 5);
                          }
                          
                          if (snapshot.hasError) {
                            return FriendlyErrorWidget(
                              error: snapshot.error.toString(),
                              isDark: isDark,
                              onRetry: () {
                                // StreamBuilder otomatik yeniden yükler
                              },
                            );
                          }
                          
                          final allExperts = snapshot.data ?? [];

                          if (allExperts.isEmpty) {
                            return Center(
                              child: Padding(
                                padding: const EdgeInsets.all(24.0),
                                child: Text(
                                  "Sistemde kayıtlı uzman bulunamadı.",
                                  style: TextStyle(
                                    color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            );
                          }

                          // ✅ OPTİMİZE EDİLMİŞ UZMAN ÖNERME ALGORİTMASI
                          
                          // 1. AI Analizinden anahtar kelimeleri çıkar (Gelişmiş NLP)
                          final analysisLower = aiAnalysis.toLowerCase();
                          final keywords = _extractKeywordsAdvanced(analysisLower);
                          
                          // 1.5. AI Analizinden meslek önerilerini çıkar
                          final recommendedProfessions = _extractRecommendedProfessions(analysisLower);
                          
                          // 1.6. AI Analizinden uzmanlık alanlarını çıkar (depresyon, anksiyete, vb.)
                          final recommendedSpecialties = _extractRecommendedSpecialties(analysisLower);
                          
                          // 2. Soru ve cevaplardan da anahtar kelimeler çıkar (eğer varsa)
                          final questionKeywords = <String>[];
                          if (questions != null && answers != null) {
                            final qaText = _extractTextFromQuestionsAndAnswers(questions!, answers!);
                            questionKeywords.addAll(_extractKeywordsAdvanced(qaText));
                          }
                          
                          // 3. Tüm anahtar kelimeleri birleştir (öncelik AI analizine ver)
                          final allKeywords = <String>{...keywords};
                          allKeywords.addAll(questionKeywords);
                          final finalKeywords = allKeywords.toList();
                          
                          // 4. Uzmanları skorla (Optimize edilmiş algoritma)
                          final List<Map<String, dynamic>> scoredExperts = [];
                          
                          for (var doc in allExperts) {
                            final data = doc.data() as Map<String, dynamic>;
                            final expertId = doc.id;
                            final expertCity = (data['city'] ?? '').toString().toLowerCase().trim();
                            final specialties = (data['specialties'] ?? '').toString().toLowerCase();
                            final profession = (data['profession'] ?? '').toString().toLowerCase();
                            final about = (data['about'] ?? '').toString().toLowerCase();
                            final followersCount = _safeGetInt(data['followersCount'], 0);
                            final createdAt = data['createdAt'] as Timestamp?;
                            
                            // ✅ Online görüşme kontrolü
                            final supportsOnline = data['supportsOnline'] == true || 
                                                 data['onlineConsultation'] == true ||
                                                 (data['consultationTypes'] as List?)?.contains('online') == true ||
                                                 about.contains('online') || 
                                                 about.contains('çevrimiçi') ||
                                                 about.contains('uzaktan');
                            
                            // ✅ OPTİMİZE EDİLMİŞ SKORLAMA SİSTEMİ (En Doğru Öneriler İçin)
                            int score = 0;
                            
                            // 1. Şehir eşleşmesi (70 puan - artırıldı, en önemli faktör)
                            final isLocal = myCity != null && myCity.isNotEmpty && expertCity == myCity;
                            if (isLocal) {
                              score += 70;
                            }
                            
                            // 1.5. Online görüşme bonusu (şehir dışı uzmanlar için)
                            if (!isLocal && supportsOnline) {
                              score += 25; // Online görüşme yapabilen şehir dışı uzmanlara bonus
                            }
                            
                            // 2. Uzmanlık alanı eşleşmesi (50 puan - artırıldı, en önemli faktörlerden biri)
                            int specialtyMatches = 0;
                            int strongMatches = 0;
                            int exactMatches = 0;
                            bool aiRecommendedSpecialty = false;
                            
                            if (specialties.isNotEmpty) {
                              final specialtyWords = specialties.split(',').map((s) => s.trim().toLowerCase()).where((s) => s.isNotEmpty).toList();
                              
                              // AI'ın önerdiği uzmanlık alanlarıyla eşleşme kontrolü (yüksek öncelik)
                              for (final recommendedSpecialty in recommendedSpecialties) {
                                for (final specialtyWord in specialtyWords) {
                                  if (specialtyWord.contains(recommendedSpecialty.toLowerCase()) || 
                                      recommendedSpecialty.toLowerCase().contains(specialtyWord)) {
                                    aiRecommendedSpecialty = true;
                                    exactMatches++;
                                    strongMatches++;
                                    specialtyMatches++;
                                    break;
                                  }
                                }
                              }
                              
                              // Genel keyword eşleşmeleri
                              for (final keyword in finalKeywords) {
                                for (final specialtyWord in specialtyWords) {
                                  // Tam eşleşme (en yüksek puan)
                                  if (specialtyWord == keyword) {
                                    exactMatches++;
                                    strongMatches++;
                                    specialtyMatches++;
                                    break;
                                  }
                                  // Güçlü eşleşme (uzun keyword'ler için)
                                  else if (keyword.length > 4 && specialtyWord.contains(keyword)) {
                                    strongMatches++;
                                    specialtyMatches++;
                                    break;
                                  }
                                  // Kısmi eşleşme
                                  else if (specialtyWord.contains(keyword) || keyword.contains(specialtyWord)) {
                                    specialtyMatches++;
                                    break;
                                  }
                                }
                              }
                              
                              if (specialtyMatches > 0) {
                                score += 50; // Base puan (artırıldı)
                                // AI'ın önerdiği uzmanlık alanları için ekstra bonus
                                if (aiRecommendedSpecialty) {
                                  score += 30; // AI önerisi bonusu (çok önemli!)
                                }
                                score += exactMatches * 15; // Tam eşleşme bonusu (artırıldı)
                                score += strongMatches * 12; // Güçlü eşleşme bonusu (artırıldı)
                                score += specialtyMatches * 4; // Her eşleşme için bonus (artırıldı)
                              }
                            }
                            
                            // 3. Profesyon eşleşmesi (30 puan - artırıldı, AI önerileri dahil)
                            if (profession.isNotEmpty) {
                              int professionMatches = 0;
                              bool aiRecommendedProfession = false;
                              
                              // AI'ın önerdiği mesleklerle eşleşme kontrolü (yüksek öncelik)
                              for (final recommendedProf in recommendedProfessions) {
                                if (profession.contains(recommendedProf.toLowerCase()) || 
                                    recommendedProf.toLowerCase().contains(profession)) {
                                  aiRecommendedProfession = true;
                                  professionMatches++;
                                  break; // Bir eşleşme yeterli
                                }
                              }
                              
                              // Genel keyword eşleşmeleri
                              for (final keyword in finalKeywords) {
                                if (profession.contains(keyword) && keyword.length > 3) {
                                  professionMatches++;
                                }
                              }
                              
                              if (professionMatches > 0) {
                                score += 30; // Base puan (artırıldı)
                                // AI'ın önerdiği meslekler için ekstra bonus
                                if (aiRecommendedProfession) {
                                  score += 25; // AI önerisi bonusu (çok önemli!)
                                }
                                score += professionMatches * 4; // Her eşleşme için bonus (artırıldı)
                              }
                            }
                            
                            // 4. About/Hakkımda eşleşmesi (15 puan - artırıldı, semantic matching)
                            if (about.isNotEmpty) {
                              int aboutMatches = 0;
                              int strongAboutMatches = 0;
                              for (final keyword in finalKeywords) {
                                if (keyword.length > 4 && about.contains(keyword)) {
                                  strongAboutMatches++;
                                  aboutMatches++;
                                } else if (about.contains(keyword) && keyword.length > 3) {
                                  aboutMatches++;
                                }
                              }
                              if (aboutMatches > 0) {
                                score += 15; // Base puan
                                score += strongAboutMatches * 5; // Güçlü eşleşme bonusu
                                score += aboutMatches * 2; // Her eşleşme için bonus
                              }
                            }
                            
                            // 5. Popülerlik (followers) (12 puan max - optimize edildi)
                            if (followersCount > 0) {
                              // Logaritmik skorlama (120+ takipçi = 12 puan)
                              final popularityScore = ((followersCount / 10).clamp(0, 12)).toInt();
                              score += popularityScore;
                            }
                            
                            // 6. Deneyim (hesap yaşı) (12 puan max - optimize edildi)
                            if (createdAt != null) {
                              final accountAge = DateTime.now().difference(createdAt.toDate()).inDays;
                              // 1 yıl+ = 12 puan
                              final experienceScore = ((accountAge / 30.4).clamp(0, 12)).toInt();
                              score += experienceScore;
                            }
                            
                            // 7. Online görüşme bonusu (şehir içi uzmanlar için de)
                            if (supportsOnline) {
                              score += 5; // Online görüşme yapabilen tüm uzmanlara küçük bonus
                            }
                            
                            // 8. Testi oluşturan uzman bonusu (çok yüksek öncelik)
                            final isTestCreator = testCreatorId != null && expertId == testCreatorId;
                            if (isTestCreator) {
                              score += 100; // Testi oluşturan uzmana çok yüksek bonus
                            }
                            
                            // Sadece skoru 0'dan büyük olanları ekle
                            if (score > 0) {
                              scoredExperts.add({
                                'doc': doc,
                                'score': score,
                                'isLocal': isLocal,
                                'specialtyMatches': specialtyMatches,
                                'supportsOnline': supportsOnline,
                                'isTestCreator': isTestCreator,
                              });
                            }
                          }
                          
                          // ✅ OPTİMİZE EDİLMİŞ SIRALAMA (En Doğru Öneriler İçin)
                          scoredExperts.sort((a, b) {
                            final aLocal = a['isLocal'] as bool;
                            final bLocal = b['isLocal'] as bool;
                            final aScore = a['score'] as int;
                            final bScore = b['score'] as int;
                            final aOnline = a['supportsOnline'] as bool? ?? false;
                            final bOnline = b['supportsOnline'] as bool? ?? false;
                            final aIsCreator = a['isTestCreator'] as bool? ?? false;
                            final bIsCreator = b['isTestCreator'] as bool? ?? false;
                            
                            // 1. EN YÜKSEK ÖNCELİK: Testi oluşturan uzman (her zaman ilk sırada)
                            if (aIsCreator != bIsCreator) {
                              return aIsCreator ? -1 : 1;
                            }
                            
                            // 2. Öncelik: Şehir içi uzmanlar (local öncelikli)
                            if (aLocal != bLocal) {
                              return aLocal ? -1 : 1;
                            }
                            
                            // 3. Aynı kategorideyse (ikisi de local veya ikisi de değil):
                            //    - Önce skor (yüksekten düşüğe)
                            //    - Eşit skorlarda online görüşme yapabilen öncelikli
                            if (aScore != bScore) {
                              return bScore.compareTo(aScore);
                            }
                            
                            // 4. Eşit skorlarda online görüşme yapabilen öncelikli
                            if (aOnline != bOnline) {
                              return aOnline ? -1 : 1;
                            }
                            
                            // 5. Her şey eşitse specialty matches'e bak
                            final aSpecialty = a['specialtyMatches'] as int;
                            final bSpecialty = b['specialtyMatches'] as int;
                            return bSpecialty.compareTo(aSpecialty);
                          });
                          
                          // ✅ Limit uygula (15 şehir içi, 10 şehir dışı - optimize edilmiş)
                          final localExperts = scoredExperts
                              .where((e) => e['isLocal'] == true)
                              .take(15)
                              .map((e) => e['doc'] as DocumentSnapshot)
                              .toList();
                          
                          final otherExperts = scoredExperts
                              .where((e) => e['isLocal'] == false)
                              .take(10)
                              .map((e) => e['doc'] as DocumentSnapshot)
                              .toList();

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Şehrindeki Uzmanlar
                              if (localExperts.isNotEmpty) ...[
                                Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                                  child: Text(
                                    "📍 Şehrindeki Uzmanlar",
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      color: isDark ? Colors.deepPurple.shade300 : Colors.deepPurple.shade700,
                                      fontSize: 16,
                                    ),
                                  ),
                                ),
                                ...localExperts.map((doc) {
                                  final expertData = scoredExperts.firstWhere((e) => e['doc'] == doc);
                                  return _buildExpertCard(
                                    context, 
                                    doc, 
                                    true, 
                                    isDark,
                                    supportsOnline: expertData['supportsOnline'] as bool? ?? false,
                                    isTestCreator: expertData['isTestCreator'] as bool? ?? false,
                                    specialtyMatches: expertData['specialtyMatches'] as int?,
                                  );
                                }),
                              ],

                              // Diğer Uzmanlar (Online görüşme yapabilenler dahil)
                              if (otherExperts.isNotEmpty) ...[
                                Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                                  child: Text(
                                    "🌍 Diğer Önerilenler (Online görüşme mümkün)",
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      color: isDark ? Colors.blue.shade300 : Colors.blue.shade700,
                                      fontSize: 16,
                                    ),
                                  ),
                                ),
                                ...otherExperts.map((doc) {
                                  final data = doc.data() as Map<String, dynamic>;
                                  final supportsOnline = data['supportsOnline'] == true || 
                                                       data['onlineConsultation'] == true ||
                                                       (data['consultationTypes'] as List?)?.contains('online') == true;
                                  final isTestCreator = testCreatorId != null && doc.id == testCreatorId;
                                  final expertData = scoredExperts.firstWhere((e) => e['doc'] == doc);
                                  return _buildExpertCard(
                                    context, 
                                    doc, 
                                    false, 
                                    isDark, 
                                    supportsOnline: supportsOnline, 
                                    isTestCreator: isTestCreator,
                                    specialtyMatches: expertData['specialtyMatches'] as int?,
                                  );
                                }),
                              ],
                            ],
                          );
                        },
                      );
                    },
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ✅ AI Analizinden meslek önerilerini çıkar
  List<String> _extractRecommendedProfessions(String text) {
    if (text.isEmpty) return [];
    
    // Türkçe psikoloji meslekleri listesi (önem sırasına göre)
    final professions = [
      'psikiyatr', 'psikiyatrist', // En spesifik olanlar önce
      'klinik psikolog',
      'nöropsikolog',
      'psikolog',
      'psikoterapist',
      'terapist',
      'aile terapisti',
      'çift terapisti',
      'evlilik terapisti',
      'bilişsel davranışçı terapist',
      'cbt terapist',
      'dbt terapist',
      'çocuk psikologu',
      'ergen psikologu',
      'çocuk psikiyatrı',
      'okul psikologu',
      'eğitim psikologu',
      'gelişim psikologu',
      'endüstri psikologu',
      'organizasyon psikologu',
      'psikolojik danışman',
      'pdr',
      'sosyal hizmet uzmanı',
      'sosyal çalışmacı',
      'aile danışmanı',
      'diyetisyen',
      'beslenme uzmanı',
      'diyet danışmanı',
      'yaşam koçu',
      'kişisel gelişim uzmanı',
      'koç',
      'nörolog',
      'nöroloji uzmanı',
    ];
    
    final foundProfessions = <String>[];
    final textLower = text.toLowerCase();
    
    // 1. Direkt meslek isimlerini kontrol et (tam kelime eşleşmesi)
    for (final prof in professions) {
      // Word boundary ile tam kelime eşleşmesi
      final regex = RegExp(r'\b' + RegExp.escape(prof) + r'\b', caseSensitive: false);
      if (regex.hasMatch(textLower)) {
        foundProfessions.add(prof);
      }
    }
    
    // 2. Öneri kalıpları ile meslekleri bul
    // "psikolog ile görüşebilirsin", "bir psikiyatr öneririm" gibi kalıplar
    final recommendationKeywords = ['öner', 'tavsiye', 'görüş', 'danış', 'başvur', 'iletişim', 'konuş'];
    
    for (final keyword in recommendationKeywords) {
      // Keyword'den önce veya sonra meslek ismi arama
      for (final prof in professions) {
        // Pattern: "keyword ... meslek" veya "meslek ... keyword"
        final patterns = [
          RegExp(r'\b' + RegExp.escape(keyword) + r'\s+[^\n]{0,100}?\b' + RegExp.escape(prof) + r'\b', caseSensitive: false),
          RegExp(r'\b' + RegExp.escape(prof) + r'\b[^\n]{0,100}?' + RegExp.escape(keyword), caseSensitive: false),
        ];
        
        for (final pattern in patterns) {
          if (pattern.hasMatch(textLower)) {
            if (!foundProfessions.contains(prof)) {
              foundProfessions.add(prof);
            }
          }
        }
      }
    }
    
    // 3. "ile görüş", "ile danış" gibi kalıplar
    final consultationPatterns = [
      RegExp(r'\b([a-zğüşıöç\s]{3,30}?)\s+(?:ile|ile)\s+(?:görüş|konuş|danış|başvur)', caseSensitive: false),
      RegExp(r'(?:ile|ile)\s+(?:görüş|konuş|danış|başvur)\s+(?:edebileceğin|edebilirsin|edebilir)\s+[^\n]{0,50}?\b([a-zğüşıöç\s]{3,30}?)', caseSensitive: false),
    ];
    
    for (final pattern in consultationPatterns) {
      final matches = pattern.allMatches(textLower);
      for (final match in matches) {
        if (match.groupCount > 0) {
          final matchedText = match.group(1)?.trim() ?? '';
          if (matchedText.length >= 3 && matchedText.length <= 30) {
            // Eşleşen metnin meslek listesinde olup olmadığını kontrol et
            for (final prof in professions) {
              if (matchedText.contains(prof) || prof.contains(matchedText)) {
                if (!foundProfessions.contains(prof)) {
                  foundProfessions.add(prof);
                }
              }
            }
          }
        }
      }
    }
    
    return foundProfessions;
  }
  
  // ✅ AI Analizinden uzmanlık alanlarını çıkar (depresyon, anksiyete, vb.)
  List<String> _extractRecommendedSpecialties(String text) {
    if (text.isEmpty) return [];
    
    // Türkçe psikoloji uzmanlık alanları listesi
    final specialties = [
      'depresyon', 'depression',
      'anksiyete', 'anxiety', 'kaygı',
      'panik', 'panic', 'panik atak',
      'fobi', 'phobia', 'korku',
      'obsesif', 'obsessive', 'obsesif kompulsif', 'okb', 'ocd',
      'travma', 'trauma', 'ptsd', 'travma sonrası',
      'stres', 'stress', 'stres yönetimi',
      'yeme bozukluğu', 'eating disorder', 'anoreksiya', 'bulimia',
      'bağımlılık', 'addiction', 'alkol bağımlılığı', 'madde bağımlılığı',
      'ilişki', 'relationship', 'çift terapisi', 'evlilik terapisi',
      'aile', 'family', 'aile terapisi',
      'çocuk', 'child', 'ergen', 'adolescent',
      'dikkat', 'attention', 'adhd', 'hiperaktivite',
      'otizm', 'autism', 'asperger',
      'kişilik', 'personality', 'borderline', 'narsisistik',
      'şizofreni', 'schizophrenia', 'bipolar', 'manik',
      'uyku', 'sleep', 'uyku bozukluğu', 'insomnia',
      'cinsel', 'sexual', 'cinsellik',
      'yas', 'grief', 'kayıp',
      'öfke', 'anger', 'öfke yönetimi',
      'düşük özgüven', 'low self-esteem', 'özgüven',
      'sosyal', 'social', 'sosyal anksiyete',
      'performans', 'performance', 'sınav kaygısı',
    ];
    
    final foundSpecialties = <String>[];
    final textLower = text.toLowerCase();
    
    // 1. Direkt uzmanlık alanı isimlerini kontrol et (tam kelime eşleşmesi)
    for (final specialty in specialties) {
      final regex = RegExp(r'\b' + RegExp.escape(specialty) + r'\b', caseSensitive: false);
      if (regex.hasMatch(textLower)) {
        foundSpecialties.add(specialty);
      }
    }
    
    // 2. "X konusunda uzman", "X alanında", "X ile ilgili" gibi kalıplar
    final specialtyPatterns = [
      RegExp(r'\b([a-zğüşıöç\s]{3,30}?)\s+(?:konusunda|alanında|ile ilgili|hakkında)\s+(?:uzman|uzmanlaşmış|deneyimli)', caseSensitive: false),
      RegExp(r'(?:uzman|uzmanlaşmış|deneyimli)\s+(?:bir\s+)?(?:psikolog|terapist|psikiyatr)\s+(?:ile|ile)\s+(?:görüş|konuş|danış)[^\n]{0,100}?\b([a-zğüşıöç\s]{3,30}?)', caseSensitive: false),
      RegExp(r'\b([a-zğüşıöç\s]{3,30}?)\s+(?:ile|ile)\s+(?:görüş|konuş|danış)[^\n]{0,50}?(?:uzman|uzmanlaşmış)', caseSensitive: false),
    ];
    
    for (final pattern in specialtyPatterns) {
      final matches = pattern.allMatches(textLower);
      for (final match in matches) {
        if (match.groupCount > 0) {
          final matchedText = match.group(1)?.trim() ?? '';
          if (matchedText.length >= 3 && matchedText.length <= 30) {
            // Eşleşen metnin uzmanlık alanı listesinde olup olmadığını kontrol et
            for (final specialty in specialties) {
              if (matchedText.contains(specialty) || specialty.contains(matchedText)) {
                if (!foundSpecialties.contains(specialty)) {
                  foundSpecialties.add(specialty);
                }
              }
            }
          }
        }
      }
    }
    
    return foundSpecialties;
  }
  
  // ✅ Gelişmiş anahtar kelime çıkarma (Optimize NLP)
  List<String> _extractKeywordsAdvanced(String text) {
    if (text.isEmpty) return [];
    
    // Türkçe psikoloji terimleri ve yaygın kelimeler (genişletilmiş)
    final commonWords = {
      've', 'ile', 'bir', 'bu', 'şu', 'o', 'için', 'gibi', 'kadar', 'daha', 'çok', 'az',
      'olan', 'oldu', 'olur', 'olmuş', 'olmak', 'olup', 'olduğu', 'olduğun', 'olduğum',
      'var', 'yok', 'ise', 'ki', 'de', 'da', 'den', 'dan',
      'ben', 'sen', 'o', 'biz', 'siz', 'onlar', 'benim', 'senin', 'onun', 'bizim', 'sizin', 'onların',
      'beni', 'seni', 'onu', 'bizi', 'sizi', 'onları', 'bana', 'sana', 'ona', 'bize', 'size', 'onlara',
      'gibi', 'kadar', 'daha', 'çok', 'az', 'en', 'bir', 'iki', 'üç', 'dört', 'beş',
      'ile', 'veya', 'ya', 'da', 'de', 'ki', 'mi', 'mı', 'mu', 'mü',
      'bu', 'şu', 'o', 'bunlar', 'şunlar', 'onlar',
      'için', 'göre', 'kadar', 'dolayı', 'nedeniyle', 'yüzünden',
      'olmak', 'olmak', 'etmek', 'yapmak', 'gelmek', 'gitmek', 'almak', 'vermek',
    };
    
    // Psikoloji terimleri (önemli kelimeler - bunlar öncelikli)
    final psychologyTerms = {
      'anxiety', 'kaygı', 'depresyon', 'depression', 'stres', 'stress',
      'panik', 'panic', 'fobi', 'phobia', 'obsesif', 'obsessive',
      'travma', 'trauma', 'ptsd', 'anksiyete', 'anxiety',
      'terapi', 'therapy', 'psikoterapi', 'psychotherapy',
      'bilişsel', 'cognitive', 'davranış', 'behavior',
      'duygu', 'emotion', 'duygusal', 'emotional',
      'ilişki', 'relationship', 'iletişim', 'communication',
      'aile', 'family', 'çocuk', 'child', 'ergen', 'adolescent',
      'cinsel', 'sexual', 'cinsellik', 'sexuality',
      'bağımlılık', 'addiction', 'alkol', 'alcohol', 'madde', 'substance',
      'yeme', 'eating', 'bozukluk', 'disorder',
      'kişilik', 'personality', 'karakter', 'character',
      'dikkat', 'attention', 'hiperaktivite', 'hyperactivity', 'adhd',
      'otizm', 'autism', 'asperger',
      'şizofreni', 'schizophrenia', 'bipolar', 'manik', 'manic',
      'borderline', 'narsisistik', 'narcissistic',
    };
    
    // Metni kelimelere ayır ve temizle
    final words = text
        .toLowerCase()
        .replaceAll(RegExp(r'[^\w\sğüşıöçĞÜŞİÖÇ]'), ' ') // Özel karakterleri kaldır
        .split(RegExp(r'\s+'))
        .where((word) => word.length > 2) // 2 karakterden uzun kelimeler
        .where((word) => !commonWords.contains(word)) // Yaygın kelimeleri filtrele
        .toList();
    
    // Kelime sayılarını hesapla
    final wordCounts = <String, int>{};
    for (final word in words) {
      wordCounts[word] = (wordCounts[word] ?? 0) + 1;
    }
    
    // Psikoloji terimlerine bonus puan ver
    final scoredWords = <String, int>{};
    for (final entry in wordCounts.entries) {
      int score = entry.value;
      // Psikoloji terimleri için bonus
      if (psychologyTerms.contains(entry.key)) {
        score += 5; // Önemli terimlere bonus
      }
      // Uzun kelimeler daha önemli olabilir
      if (entry.key.length > 5) {
        score += 1;
      }
      scoredWords[entry.key] = score;
    }
    
    // Skora göre sırala
    final sortedWords = scoredWords.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    
    // En önemli 15 kelimeyi al (artırıldı)
    return sortedWords.take(15).map((e) => e.key).toList();
  }
  
  // ✅ Soru ve cevaplardan metin çıkar
  String _extractTextFromQuestionsAndAnswers(List<dynamic> questions, List<dynamic> answers) {
    final buffer = StringBuffer();
    
    for (int i = 0; i < questions.length && i < answers.length; i++) {
      final question = questions[i];
      final answer = answers[i];
      
      // Soruyu ekle
      if (question is Map) {
        buffer.writeln(question['text']?.toString() ?? question['question']?.toString() ?? '');
      } else if (question is String) {
        buffer.writeln(question);
      }
      
      // Cevabı ekle
      if (answer is Map) {
        buffer.writeln(answer['text']?.toString() ?? answer['answer']?.toString() ?? '');
      } else if (answer is String) {
        // IMAGE_URL: prefix'ini kaldır
        if (answer.startsWith('IMAGE_URL:')) {
          buffer.writeln('Görsel yüklendi');
        } else {
          buffer.writeln(answer);
        }
      }
      
      buffer.writeln(''); // Boş satır
    }
    
    return buffer.toString().toLowerCase();
  }
  
  // ✅ Soru-Cevap kartı widget'ı
  Widget _buildQuestionAnswerCard(
    BuildContext context,
    int questionNumber,
    dynamic question,
    dynamic answer,
    bool isDark,
  ) {
    String questionText = '';
    if (question is Map) {
      questionText = question['text']?.toString() ?? question['question']?.toString() ?? '';
    } else if (question is String) {
      questionText = question;
    }
    
    String answerText = '';
    bool isImageAnswer = false;
    if (answer != null) {
      if (answer is Map) {
        answerText = answer['text']?.toString() ?? answer['answer']?.toString() ?? '';
      } else if (answer is String) {
        if (answer.startsWith('IMAGE_URL:')) {
          answerText = answer.replaceFirst('IMAGE_URL:', '');
          isImageAnswer = true;
        } else {
          answerText = answer;
        }
      }
    }
    
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      color: isDark ? Colors.grey.shade900 : Colors.grey.shade50,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isDark ? Colors.grey.shade800 : Colors.grey.shade300,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.deepPurple.shade800 : Colors.deepPurple.shade100,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      '$questionNumber',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.deepPurple.shade200 : Colors.deepPurple.shade700,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Soru',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        questionText.isNotEmpty ? questionText : 'Soru metni bulunamadı',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.check_circle_outline,
                  size: 20,
                  color: isDark ? Colors.green.shade300 : Colors.green.shade700,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Cevabın',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      if (isImageAnswer && answerText.isNotEmpty)
                        Row(
                          children: [
                            Icon(
                              Icons.image,
                              size: 16,
                              color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                'Görsel yüklendi',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: isDark ? Colors.grey.shade300 : Colors.grey.shade700,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ),
                          ],
                        )
                      else
                        Text(
                          answerText.isNotEmpty ? answerText : 'Cevap verilmedi',
                          style: TextStyle(
                            fontSize: 14,
                            color: isDark ? Colors.grey.shade300 : Colors.grey.shade700,
                            fontStyle: answerText.isEmpty ? FontStyle.italic : FontStyle.normal,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
  
  // ✅ Güvenli int değer alma
  int _safeGetInt(dynamic value, int defaultValue) {
    if (value == null) return defaultValue;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is num) return value.toInt();
    if (value is String) {
      final parsed = int.tryParse(value);
      return parsed ?? defaultValue;
    }
    return defaultValue;
  }

  Widget _buildExpertCard(BuildContext context, DocumentSnapshot doc, bool isLocal, bool isDark, {bool supportsOnline = false, bool isTestCreator = false, int? matchScore, int? specialtyMatches}) {
    final data = doc.data() as Map<String, dynamic>;
    final followersCount = _safeGetInt(data['followersCount'], 0);
    final specialties = (data['specialties'] ?? '').toString();
    
    // Online görüşme kontrolü (eğer parametre olarak gelmediyse)
    if (!supportsOnline) {
      final about = (data['about'] ?? '').toString().toLowerCase();
      supportsOnline = data['supportsOnline'] == true || 
                      data['onlineConsultation'] == true ||
                      (data['consultationTypes'] as List?)?.contains('online') == true ||
                      about.contains('online') || 
                      about.contains('çevrimiçi') ||
                      about.contains('uzaktan');
    }
    
    // Specialty tags oluştur
    final specialtyList = specialties.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).take(3).toList();
    
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      color: isDark ? Colors.grey.shade900 : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isTestCreator
              ? (isDark ? Colors.orange.shade700 : Colors.orange.shade400)
              : (isLocal
                  ? (isDark ? Colors.deepPurple.shade700 : Colors.deepPurple.shade300)
                  : (isDark ? Colors.grey.shade800 : Colors.grey.shade300)),
          width: isTestCreator ? 3 : (isLocal ? 2 : 1),
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Stack(
          children: [
            CircleAvatar(
              backgroundColor: isTestCreator
                  ? (isDark ? Colors.orange.shade900 : Colors.orange.shade100)
                  : (isLocal
                      ? (isDark ? Colors.deepPurple.shade900 : Colors.deepPurple.shade100)
                      : (isDark ? Colors.blue.shade900 : Colors.blue.shade100)),
              child: Text(
                (data['name'] ?? 'U')[0].toUpperCase(),
                style: TextStyle(
                  color: isTestCreator
                      ? (isDark ? Colors.orange.shade200 : Colors.orange.shade700)
                      : (isLocal
                          ? (isDark ? Colors.deepPurple.shade200 : Colors.deepPurple.shade700)
                          : (isDark ? Colors.blue.shade200 : Colors.blue.shade700)),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            if (isTestCreator)
              Positioned(
                right: 0,
                bottom: 0,
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.orange.shade700 : Colors.orange.shade400,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isDark ? Colors.grey.shade900 : Colors.white,
                      width: 1.5,
                    ),
                  ),
                  child: Icon(
                    Icons.star,
                    size: 12,
                    color: Colors.white,
                  ),
                ),
              ),
          ],
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                data['name'] ?? 'İsimsiz Uzman',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
            ),
            if (isTestCreator)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: isDark ? Colors.orange.shade800 : Colors.orange.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.star,
                      size: 12,
                      color: isDark ? Colors.orange.shade200 : Colors.orange.shade700,
                    ),
                    const SizedBox(width: 2),
                    Text(
                      'Test Oluşturan',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.orange.shade200 : Colors.orange.shade700,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              "${data['profession'] ?? 'Uzman'} • ${data['city'] ?? 'Şehir Yok'}",
              style: TextStyle(
                fontSize: 13,
                color: isDark ? Colors.grey.shade400 : Colors.grey.shade700,
              ),
            ),
            if (specialtyList.isNotEmpty) ...[
              const SizedBox(height: 6),
              Wrap(
                spacing: 4,
                runSpacing: 4,
                children: specialtyList.map((specialty) {
                  return Chip(
                    label: Text(
                      specialty,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    padding: EdgeInsets.zero,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    visualDensity: VisualDensity.compact,
                    backgroundColor: isDark 
                        ? Colors.deepPurple.shade800.withOpacity(0.5)
                        : Colors.deepPurple.shade100,
                    labelStyle: TextStyle(
                      color: isDark ? Colors.deepPurple.shade200 : Colors.deepPurple.shade700,
                    ),
                  );
                }).toList(),
              ),
            ],
            if (supportsOnline) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(
                    Icons.video_call,
                    size: 12,
                    color: isDark ? Colors.blue.shade300 : Colors.blue.shade600,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Online görüşme',
                    style: TextStyle(
                      fontSize: 10,
                      color: isDark ? Colors.blue.shade300 : Colors.blue.shade600,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ],
            if (followersCount > 0) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(
                    Icons.people_outline,
                    size: 12,
                    color: isDark ? Colors.grey.shade500 : Colors.grey.shade600,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '$followersCount takipçi',
                    style: TextStyle(
                      fontSize: 10,
                      color: isDark ? Colors.grey.shade500 : Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
        trailing: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: isLocal
                ? (isDark ? Colors.deepPurple.shade700 : Colors.deepPurple)
                : (isDark ? Colors.deepPurple.shade700 : Colors.deepPurple),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          ),
          onPressed: () {
            Navigator.pushNamed(context, '/publicExpertProfile', arguments: doc.id);
          },
          child: const Text("Profil", style: TextStyle(fontSize: 12)),
        ),
      ),
    );
  }
}