import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../repositories/firestore_test_repository.dart';

// ✅ Soru modeli
class QuestionItem {
  final String text;
  final String type; // 'scale', 'text', 'multiple_choice'
  final List<String> options; // multiple_choice için seçenekler
  final String? imageUrl; // ✅ Çoktan seçmeli sorular için görsel

  QuestionItem({
    required this.text,
    this.type = 'scale',
    this.options = const [],
    this.imageUrl,
  });

  factory QuestionItem.fromMap(Map<String, dynamic> map) {
    // ✅ Tip kontrolü - geçerli tipler için default değer
    final typeStr = (map['type']?.toString() ?? '').trim();
    final validTypes = ['scale', 'text', 'multiple_choice', 'image_question'];
    final validType = validTypes.contains(typeStr) ? typeStr : 'text'; // ✅ Geçersiz tip için default: text
    
    // ✅ Options parse - multiple_choice için seçenekleri al
    List<String> parsedOptions = [];
    final optionsValue = map['options'];
    
    // ✅ Tüm soru tipleri için options parse et (ama sadece multiple_choice için kullan)
    if (optionsValue != null) {
      try {
        if (optionsValue is List) {
          // ✅ List formatında gelirse
          parsedOptions = optionsValue
              .map((e) {
                // ✅ Her elemanı string'e çevir ve temizle
                if (e == null) return '';
                final str = e.toString().trim();
                return str;
              })
              .where((e) => e.isNotEmpty)
              .toList();
        } else if (optionsValue is String) {
          // ✅ String formatında gelirse (nadir durum)
          final trimmed = optionsValue.trim();
          parsedOptions = trimmed.isNotEmpty ? [trimmed] : [];
        } else {
          // ✅ Diğer formatlar için boş liste
          parsedOptions = [];
        }
        // ✅ Eğer options geçersiz formattaysa, boş liste kalır
      } catch (e) {
        // ✅ Parse hatası durumunda boş liste
        parsedOptions = [];
      }
    }
    // ✅ Eğer options null ise, boş liste kalır
    
    return QuestionItem(
      text: map['text']?.toString() ?? '',
      type: validType,
      options: parsedOptions,
      imageUrl: map['imageUrl']?.toString(),
    );
  }
}

class SolveTestScreen extends StatefulWidget {
  final Map<String, dynamic> testData;
  const SolveTestScreen({super.key, required this.testData});

  @override
  State<SolveTestScreen> createState() => _SolveTestScreenState();
}

class _SolveTestScreenState extends State<SolveTestScreen> {
  final _testRepo = FirestoreTestRepository();

  late final List<QuestionItem> _questions;
  late final List<int?> _scaleAnswers;
  late final List<TextEditingController> _textControllers;
  late final List<String?> _multipleChoiceAnswers; // ✅ Multiple choice için (seçenek)
  late final List<TextEditingController> _imageQuestionAnswers; // ✅ Görsel soru için (metin cevabı)

  bool _submitting = false;
  String? _pendingDocId;
  
  // ✅ Progress tracking
  int _answeredCount = 0;
  
  // ✅ Helper: Cevaplanan soru sayısını hesapla
  void _updateProgress() {
    int count = 0;
    for (int i = 0; i < _questions.length; i++) {
      final question = _questions[i];
      bool answered = false;
      
      if (question.type == 'scale') {
        answered = _scaleAnswers[i] != null;
      } else if (question.type == 'multiple_choice') {
        answered = _multipleChoiceAnswers[i] != null;
      } else if (question.type == 'image_question') {
        answered = _imageQuestionAnswers[i].text.trim().isNotEmpty;
      } else {
        answered = _textControllers[i].text.trim().isNotEmpty;
      }
      
      if (answered) count++;
    }
    
    if (count != _answeredCount) {
      setState(() => _answeredCount = count);
    }
  }

  @override
  void initState() {
    super.initState();
    final rawQuestions = widget.testData['questions'];
    _questions = _normalizeQuestions(rawQuestions);

    // ✅ Her soru tipi için ayrı liste
    _scaleAnswers = List<int?>.filled(_questions.length, null);
    _textControllers = List.generate(_questions.length, (_) => TextEditingController());
    _multipleChoiceAnswers = List<String?>.filled(_questions.length, null);
    _imageQuestionAnswers = List.generate(_questions.length, (_) => TextEditingController());
  }

  @override
  void dispose() {
    for (final ctrl in _textControllers) {
      ctrl.dispose();
    }
    for (final ctrl in _imageQuestionAnswers) {
      ctrl.dispose();
    }
    super.dispose();
  }

  List<QuestionItem> _normalizeQuestions(dynamic raw) {
    if (raw is List) {
      return raw.map((e) {
        if (e is Map) {
          // ✅ Yeni format: Map - her soru kendi tipine sahip
          final map = Map<String, dynamic>.from(e);
          final typeStr = (map['type']?.toString() ?? '').trim();
          
          // ✅ Tip kontrolü - geçerli tipler
          final validTypes = ['scale', 'text', 'multiple_choice', 'image_question'];
          if (typeStr.isNotEmpty && validTypes.contains(typeStr)) {
            // ✅ Tip geçerli, olduğu gibi kullan - options alanını koru
            // ✅ ÖNEMLİ: Map'i doğrudan fromMap'e gönder, options alanı korunacak
            return QuestionItem.fromMap(map);
          } else {
            // ✅ Tip yok veya geçersiz - answerType'a bak (geriye dönük uyumluluk)
            final answerType = (widget.testData['answerType'] ?? 'text').toString().toLowerCase();
            final fallbackType = answerType.contains('scale') 
                ? 'scale' 
                : answerType.contains('multiple') || answerType.contains('choice')
                    ? 'multiple_choice'
                    : 'text';
            map['type'] = fallbackType;
            // ✅ Options alanını koru (eğer varsa)
            return QuestionItem.fromMap(map);
          }
        } else {
          // ✅ Eski format: String (geriye dönük uyumluluk)
          final answerType = (widget.testData['answerType'] ?? 'text').toString().toLowerCase();
          return QuestionItem(
            text: e.toString().trim(),
            type: answerType.contains('scale') 
                ? 'scale' 
                : answerType.contains('multiple') || answerType.contains('choice')
                    ? 'multiple_choice'
                    : 'text',
            options: const [], // ✅ Eski format için options yok
          );
        }
      }).where((q) => q.text.isNotEmpty).toList();
    }
    return [];
  }


  Future<void> _submit() async {
    if (_submitting) return;
    FocusScope.of(context).unfocus();
    setState(() { _submitting = true; });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception("Oturum açın.");

      List<dynamic> answers = [];
      List<String> questionTexts = [];

      // ✅ Her soru için tipine göre cevap al
      for (int i = 0; i < _questions.length; i++) {
        final question = _questions[i];
        questionTexts.add(question.text);

        if (question.type == 'scale') {
          if (_scaleAnswers[i] == null) {
            throw Exception("${i + 1}. soru (puanlama) için bir değer seçin.");
          }
          answers.add(_scaleAnswers[i]!);
        } else if (question.type == 'multiple_choice') {
          if (_multipleChoiceAnswers[i] == null) {
            throw Exception("${i + 1}. soru (çoktan seçmeli) için bir seçenek seçin.");
          }
          // ✅ Çoktan seçmeli: sadece seçenek
          answers.add(_multipleChoiceAnswers[i]!);
        } else if (question.type == 'image_question') {
          // ✅ Görsel soru: sadece metin cevabı
          final rawAnswer = _imageQuestionAnswers[i].text.trim();
          if (rawAnswer.isEmpty) {
            throw Exception("${i + 1}. soru (görsel soru) için metin cevabı girin.");
          }
          // ✅ GÜVENLİK: Input sanitization (XSS koruması)
          final sanitizedAnswer = rawAnswer
              .replaceAll(RegExp(r'<[^>]*>'), '') // HTML tag'lerini kaldır
              .trim();
          if (sanitizedAnswer.isEmpty) {
            throw Exception("${i + 1}. soru (görsel soru) için geçerli bir metin cevabı girin.");
          }
          if (sanitizedAnswer.length > 2000) {
            throw Exception("${i + 1}. soru (görsel soru) cevabı en fazla 2000 karakter olabilir.");
          }
          answers.add(sanitizedAnswer);
        } else {
          // ✅ text tipi: Sadece metin cevabı (görsel eklenemez)
          final rawAnswer = _textControllers[i].text.trim();
          if (rawAnswer.isEmpty) {
            throw Exception("${i + 1}. soru (yazılı) boş bırakılamaz.");
          }
          // ✅ GÜVENLİK: Input sanitization (XSS koruması)
          final sanitizedAnswer = rawAnswer
              .replaceAll(RegExp(r'<[^>]*>'), '') // HTML tag'lerini kaldır
              .trim();
          if (sanitizedAnswer.isEmpty) {
            throw Exception("${i + 1}. soru (yazılı) için geçerli bir cevap girin.");
          }
          if (sanitizedAnswer.length > 2000) {
            throw Exception("${i + 1}. soru (yazılı) cevabı en fazla 2000 karakter olabilir.");
          }
          answers.add(sanitizedAnswer);
        }
      }

      // ✅ Dominant answer mode'u belirle (geriye dönük uyumluluk için)
      final typeCounts = <String, int>{};
      for (final q in _questions) {
        typeCounts[q.type] = (typeCounts[q.type] ?? 0) + 1;
      }
      final dominantMode = typeCounts.entries
          .reduce((a, b) => a.value > b.value ? a : b)
          .key;

      // Veritabanına Yaz
      final docId = await _testRepo.submitSolvedTestRaw(
        userId: user.uid,
        testId: widget.testData['id'],
        testTitle: widget.testData['title'] ?? 'Test',
        questions: questionTexts,
        answers: answers,
        answerMode: dominantMode, // ✅ Geriye dönük uyumluluk için
      );

      // Bekleme Moduna Geç
      setState(() { _pendingDocId = docId; });

    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Hata: $e")),
        );
      }
      setState(() { _submitting = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    // BEKLEME EKRANI
    if (_pendingDocId != null) {
      return Scaffold(
        appBar: AppBar(title: const Text("Analiz Yapılıyor...")),
        body: StreamBuilder<DocumentSnapshot>(
          stream: _testRepo.watchSolvedTestResult(_pendingDocId!),
          builder: (context, snapshot) {
            if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

            final data = snapshot.data!.data() as Map<String, dynamic>?;
            final status = data?['status'] ?? 'pending';

            if (status == 'completed') {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) {
                  Navigator.pushReplacementNamed(context, '/resultDetail', arguments: {
                    'testTitle': data?['testTitle'],
                    'aiAnalysis': data?['aiAnalysis'],
                    'createdAt': data?['createdAt'],
                  });
                }
              });
              return const Center(child: Icon(Icons.check_circle, color: Colors.green, size: 60));
            }
            if (status == 'failed') {
              final errorMessage = data?['aiAnalysis']?.toString() ?? 'Bilinmeyen bir hata oluştu';
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.error_outline,
                        size: 64,
                        color: Colors.red.shade300,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Analiz Başarısız',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey.shade800,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        errorMessage,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade600,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton.icon(
                        onPressed: () {
                          setState(() => _pendingDocId = null);
                        },
                        icon: const Icon(Icons.refresh),
                        label: const Text('Tekrar Dene'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.deepPurple,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }

            // ✅ Profesyonel loading state
            final statusText = status == 'pending' 
                ? 'Test gönderiliyor...'
                : status == 'processing'
                    ? 'Yapay Zeka (Gemini) analiz ediyor...'
                    : 'İşleniyor...';
            
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const CircularProgressIndicator(
                      strokeWidth: 3,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.deepPurple),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      statusText,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      status == 'processing' 
                          ? 'Görseller işleniyor, cevaplar analiz ediliyor...'
                          : 'Lütfen bekleyin',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade600,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 32),
                    // ✅ Estimated time
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.deepPurple.shade50,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.access_time, size: 16, color: Colors.deepPurple.shade700),
                          const SizedBox(width: 8),
                          Text(
                            'Tahmini süre: 30-60 saniye',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.deepPurple.shade700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      );
    }

    // FORM EKRANI
    final progress = _questions.isEmpty ? 0.0 : (_answeredCount / _questions.length);
    
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.testData['title'] ?? 'Test'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(4),
          child: LinearProgressIndicator(
            value: progress,
            backgroundColor: Colors.grey.shade200,
            minHeight: 4,
          ),
        ),
      ),
      body: Column(
        children: [
          // ✅ Progress indicator
          if (_questions.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: Colors.deepPurple.shade50,
              child: Row(
                children: [
                  Icon(Icons.check_circle_outline, size: 16, color: Colors.deepPurple),
                  const SizedBox(width: 8),
                  Text(
                    '${_answeredCount}/${_questions.length} soru cevaplandı',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: Colors.deepPurple.shade700,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${(progress * 100).toInt()}%',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.deepPurple.shade700,
                    ),
                  ),
                ],
              ),
            ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(8),
              itemCount: _questions.length,
              itemBuilder: (context, index) {
                final question = _questions[index];

                if (question.type == 'scale') {
                  // ✅ SKALA GÖRÜNÜMÜ
                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    elevation: 2,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Soru ${index + 1}: ${question.text}",
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: List.generate(5, (i) {
                              final value = i + 1;
                              return ChoiceChip(
                                label: Text("$value"),
                                selected: _scaleAnswers[index] == value,
                                onSelected: (_) {
                                  setState(() {
                                    _scaleAnswers[index] = value;
                                    _updateProgress();
                                  });
                                },
                              );
                            }),
                          ),
                        ],
                      ),
                    ),
                  );
                } else if (question.type == 'multiple_choice') {
                  // ✅ ÇOKTAN SEÇMELİ GÖRÜNÜMÜ (Sadece seçenekler)
                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    elevation: 2,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Soru ${index + 1}: ${question.text}",
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                          const SizedBox(height: 12),
                          // ✅ Options kontrolü - boş veya yetersizse hata göster
                          if (question.options.isEmpty || question.options.length < 2)
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.orange.shade50,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.orange.shade200),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    "⚠️ Bu soru için seçenek tanımlanmamış veya yetersiz.",
                                    style: TextStyle(color: Colors.orange, fontWeight: FontWeight.w600),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    "Seçenek sayısı: ${question.options.length}",
                                    style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                                  ),
                                ],
                              ),
                            )
                          else
                            ...question.options.map((option) {
                              return RadioListTile<String>(
                                title: Text(option),
                                value: option,
                                groupValue: _multipleChoiceAnswers[index],
                                onChanged: (value) {
                                  setState(() {
                                    _multipleChoiceAnswers[index] = value;
                                    _updateProgress();
                                  });
                                },
                                dense: true,
                                contentPadding: EdgeInsets.zero,
                              );
                            }),
                        ],
                      ),
                    ),
                  );
                } else if (question.type == 'image_question') {
                  // ✅ GÖRSEL SORU GÖRÜNÜMÜ (Görsel + Metin Cevabı)
                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    elevation: 2,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Soru ${index + 1}: ${question.text}",
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                          // ✅ Görsel gösterimi (zorunlu)
                          if (question.imageUrl != null && question.imageUrl!.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.network(
                                question.imageUrl!,
                                width: double.infinity,
                                fit: BoxFit.contain,
                                loadingBuilder: (context, child, loadingProgress) {
                                  if (loadingProgress == null) return child;
                                  return Container(
                                    height: 250,
                                    color: Colors.grey.shade200,
                                    child: Center(
                                      child: CircularProgressIndicator(
                                        value: loadingProgress.expectedTotalBytes != null
                                            ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                                            : null,
                                      ),
                                    ),
                                  );
                                },
                                errorBuilder: (context, error, stackTrace) {
                                  return Container(
                                    height: 250,
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: Colors.grey.shade200,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.broken_image, size: 48, color: Colors.grey.shade600),
                                        const SizedBox(height: 8),
                                        Text(
                                          'Görsel yüklenemedi',
                                          style: TextStyle(color: Colors.grey.shade600),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'Metin cevabı:',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 8),
                            TextField(
                              controller: _imageQuestionAnswers[index],
                              maxLines: 4,
                              onChanged: (_) => _updateProgress(),
                              decoration: const InputDecoration(
                                hintText: 'Bu görselde ne görüyorsun?',
                                border: OutlineInputBorder(),
                                helperText: 'Gördüğünüz şeyi detaylı bir şekilde açıklayın',
                              ),
                            ),
                          ] else
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.orange.shade50,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.orange.shade200),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.warning_amber_rounded, color: Colors.orange.shade700, size: 20),
                                  const SizedBox(width: 8),
                                  const Expanded(
                                    child: Text(
                                      "Bu soru için görsel tanımlanmamış.",
                                      style: TextStyle(color: Colors.orange, fontWeight: FontWeight.w500),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                  );
                } else {
                  // ✅ YAZILI CEVAP GÖRÜNÜMÜ (Sadece metin, görsel eklenemez)
                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    elevation: 2,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Soru ${index + 1}: ${question.text}",
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _textControllers[index],
                            maxLines: 4,
                            onChanged: (_) => _updateProgress(),
                            decoration: const InputDecoration(
                              hintText: 'Cevabınızı yazın...',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _submitting ? null : _submit,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: Text(_submitting ? "Yükleniyor..." : "Analizi Başlat"),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
