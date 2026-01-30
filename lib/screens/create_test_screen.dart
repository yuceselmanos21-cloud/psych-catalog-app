import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:path/path.dart' as path;

import '../repositories/firestore_test_repository.dart';
import '../repositories/firestore_subscription_repository.dart';
import '../utils/rate_limiter.dart';
import '../services/analytics_service.dart';
import '../utils/error_handler.dart';

// ✅ Soru modeli
class QuestionItem {
  final String text;
  final String type; // 'scale', 'text', 'multiple_choice', 'image_question'
  final List<String> options; // multiple_choice için seçenekler
  final String? imageUrl; // ✅ Görsel sorular için görsel

  QuestionItem({
    required this.text,
    this.type = 'scale',
    this.options = const [],
    this.imageUrl,
  });

  Map<String, dynamic> toMap() {
    return {
      'text': text,
      'type': type,
      if (type == 'multiple_choice' && options.isNotEmpty) 'options': options,
      // ✅ Görsel URL'i sadece görsel soru tipinde ekle
      if (type == 'image_question' && imageUrl != null && imageUrl!.isNotEmpty) 'imageUrl': imageUrl,
    };
  }

  factory QuestionItem.fromMap(Map<String, dynamic> map) {
    return QuestionItem(
      text: map['text']?.toString() ?? '',
      type: map['type']?.toString() ?? 'scale',
      options: map['options'] is List
          ? (map['options'] as List).map((e) => e.toString()).toList()
          : [],
      imageUrl: map['imageUrl']?.toString(),
    );
  }
}

class CreateTestScreen extends ConsumerStatefulWidget {
  const CreateTestScreen({super.key});

  @override
  ConsumerState<CreateTestScreen> createState() => _CreateTestScreenState();
}

class _CreateTestScreenState extends ConsumerState<CreateTestScreen> {
  final _testRepo = FirestoreTestRepository();

  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();

  // ✅ Her soru için ayrı yapı
  final List<QuestionItem> _questions = [];

  bool _loading = false;
  String? _error;
  String? _success;

  // ✅ sadece expert/admin test oluşturabilsin
  bool _roleLoading = true;
  bool _isExpert = false;
  bool _isAdmin = false;
  String? _expertName;

  User? get _user => FirebaseAuth.instance.currentUser;

  @override
  void initState() {
    super.initState();
    // ✅ Analytics: Screen view tracking
    AnalyticsService.logScreenView('create_test');
    _loadRoleAndName();
    // ✅ İlk soruyu ekle
    _questions.add(QuestionItem(text: '', type: 'scale'));
  }

  Future<void> _loadRoleAndName() async {
    final user = _user;
    if (user == null) {
      if (!mounted) return;
      setState(() {
        _roleLoading = false;
        _isExpert = false;
        _expertName = null;
      });
      return;
    }

    try {
      final snap = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      final data = snap.data() ?? <String, dynamic>{};
      final role = (data['role'] ?? 'client').toString();
      final name = (data['name'] ?? '').toString().trim();

      // Admin kontrolü
      final adminDoc = await FirebaseFirestore.instance
          .collection('admins')
          .doc(user.uid)
          .get();
      final isAdminUser = adminDoc.exists || role == 'admin';

      if (!mounted) return;
      setState(() {
        _isExpert = role == 'expert' || role == 'admin' || isAdminUser;
        _isAdmin = isAdminUser;
        _expertName = name.isNotEmpty ? name : null;
        _roleLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isExpert = false;
        _expertName = null;
        _roleLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    for (final q in _questions) {
      // TextEditingController'ları temizle (eğer varsa)
    }
    super.dispose();
  }

  void _addQuestion() {
    setState(() {
      _questions.add(QuestionItem(text: '', type: 'scale'));
    });
  }

  void _removeQuestion(int index) {
    if (_questions.length <= 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('En az bir soru olmalı')),
      );
      return;
    }
    setState(() {
      _questions.removeAt(index);
    });
  }

  void _updateQuestion(int index, QuestionItem question) {
    setState(() {
      _questions[index] = question;
    });
  }

  Future<void> _saveTest() async {
    setState(() {
      _loading = true;
      _error = null;
      _success = null;
    });

    try {
      final user = _user;
      if (user == null) {
        if (!mounted) return;
        setState(() {
          _error = 'Oturum bulunamadı. Lütfen tekrar giriş yapın.';
        });
        return;
      }

      if (!_isExpert && !_isAdmin) {
        if (!mounted) return;
        setState(() {
          _error = 'Sadece uzmanlar ve adminler test oluşturabilir.';
          _loading = false;
        });
        return;
      }

      // ✅ ABONELİK KONTROLÜ: Expert ise aktif abonelik gerekli (Admin hariç)
      if (_isExpert && !_isAdmin) {
        final subscriptionRepo = FirestoreSubscriptionRepository();
        final hasActiveSubscription = await subscriptionRepo.hasActiveSubscription(user.uid);
        
        if (!hasActiveSubscription) {
          if (!mounted) return;
          setState(() {
            _error = 'Test oluşturmak için aktif bir aboneliğiniz olmalıdır. Lütfen abonelik planınızı yenileyin.';
            _loading = false;
          });
          return;
        }
      }

      // ✅ GÜVENLİK: Input sanitization ve validation
      final title = _titleCtrl.text.trim();
      final description = _descCtrl.text.trim();

      // ✅ XSS koruması: HTML tag'lerini kaldır
      final sanitizedTitle = title.replaceAll(RegExp(r'<[^>]*>'), '').trim();
      final sanitizedDescription = description.replaceAll(RegExp(r'<[^>]*>'), '').trim();

      if (sanitizedTitle.isEmpty) {
        if (!mounted) return;
        setState(() {
          _error = 'Test başlığı boş olamaz.';
          _loading = false;
        });
        return;
      }

      if (sanitizedTitle.length < 3) {
        if (!mounted) return;
        setState(() {
          _error = 'Test başlığı en az 3 karakter olmalı.';
          _loading = false;
        });
        return;
      }

      if (sanitizedTitle.length > 200) {
        if (!mounted) return;
        setState(() {
          _error = 'Test başlığı en fazla 200 karakter olabilir.';
          _loading = false;
        });
        return;
      }

      if (sanitizedDescription.length > 1000) {
        if (!mounted) return;
        setState(() {
          _error = 'Test açıklaması en fazla 1000 karakter olabilir.';
          _loading = false;
        });
        return;
      }

      // ✅ Geçerli soruları filtrele ve sanitize et
      final validQuestions = <Map<String, dynamic>>[];
      for (int i = 0; i < _questions.length; i++) {
        final q = _questions[i];
        
        // ✅ Soru metnini sanitize et
        final sanitizedText = q.text.replaceAll(RegExp(r'<[^>]*>'), '').trim();
        if (sanitizedText.isEmpty) continue; // Boş soruları atla
        
        // ✅ Soru metni uzunluk kontrolü
        if (sanitizedText.length > 500) {
          if (!mounted) return;
          setState(() {
            _error = '${i + 1}. soru metni en fazla 500 karakter olabilir.';
            _loading = false;
          });
          return;
        }
        
        // ✅ Soru tipine göre map oluştur
        final questionMap = <String, dynamic>{
          'text': sanitizedText,
          'type': q.type, // ✅ Tip her zaman eklenmeli
        };
        
        // ✅ Çoktan seçmeli için seçenekler
        if (q.type == 'multiple_choice') {
          final options = q.options
              .map((opt) => opt.replaceAll(RegExp(r'<[^>]*>'), '').trim())
              .where((opt) => opt.isNotEmpty)
              .where((opt) => opt.length <= 200)
              .toList();
          
          if (options.length < 2) {
            if (!mounted) return;
            setState(() {
              _error = '${i + 1}. soru (çoktan seçmeli) için en az 2 seçenek girmelisin.';
              _loading = false;
            });
            return;
          }
          questionMap['options'] = options;
        }
        
        // ✅ Görsel soru için görsel URL
        if (q.type == 'image_question') {
          if (q.imageUrl == null || q.imageUrl!.isEmpty) {
            if (!mounted) return;
            setState(() {
              _error = '${i + 1}. soru (görsel soru) için görsel eklemelisin.';
              _loading = false;
            });
            return;
          }
          questionMap['imageUrl'] = q.imageUrl;
        }
        
        // ✅ Scale ve text tipleri için ekstra alan yok (sadece text ve type)
        
        validQuestions.add(questionMap);
      }

      if (validQuestions.isEmpty) {
        if (!mounted) return;
        setState(() {
          _error = 'En az bir soru girmelisin.';
        });
        return;
      }

      // ✅ Soru tipi bazlı validasyon (zaten yukarıda yapıldı, burada sadece kontrol)
      for (int i = 0; i < validQuestions.length; i++) {
        final q = validQuestions[i];
        final type = q['type']?.toString() ?? '';
        
        // ✅ Tip kontrolü
        if (!['scale', 'text', 'multiple_choice', 'image_question'].contains(type)) {
          if (!mounted) return;
          setState(() {
            _error = '${i + 1}. soru için geçersiz tip: $type';
            _loading = false;
          });
          return;
        }
      }

      if (validQuestions.length > 50) {
        if (!mounted) return;
        setState(() {
          _error = 'Şimdilik en fazla 50 soru ekleyebilirsin.';
        });
        return;
      }

      // ✅ Eski yapıyla uyumluluk için: answerType'ı belirle (çoğunluk hangisiyse)
      final typeCounts = <String, int>{};
      for (final q in validQuestions) {
        final type = q['type']?.toString() ?? 'scale';
        typeCounts[type] = (typeCounts[type] ?? 0) + 1;
      }
      final dominantType = typeCounts.entries
          .reduce((a, b) => a.value > b.value ? a : b)
          .key;

      // ✅ RATE LIMITING: Test oluşturma için rate limit
      final canCreate = RateLimiter.canPerformAction(
        'test_creation_${user.uid}',
        cooldown: const Duration(minutes: 5),
        maxAttempts: 5,
        resetWindow: const Duration(minutes: 10),
      );
      
      if (!canCreate) {
        if (!mounted) return;
        setState(() {
          _error = 'Çok fazla test oluşturma denemesi yaptınız. Lütfen birkaç dakika bekleyin.';
          _loading = false;
        });
        return;
      }
      
      RateLimiter.recordAction(
        'test_creation_${user.uid}',
        resetWindow: const Duration(minutes: 10),
      );
      
      await _testRepo.createTest(
        title: sanitizedTitle,
        description: sanitizedDescription,
        createdBy: user.uid,
        questions: validQuestions, // ✅ Yeni yapı: List<Map<String, dynamic>>
        answerType: dominantType, // ✅ Geriye dönük uyumluluk için
        expertName: _expertName,
      );

      // ✅ ANALYTICS: Test oluşturuldu event'i
      await AnalyticsService.logEvent('test_created', parameters: {
        'test_id': 'new',
        'question_count': validQuestions.length,
      });

      if (!mounted) return;
      setState(() {
        _success = 'Test kaydedildi 🎉';
        _titleCtrl.clear();
        _descCtrl.clear();
        _questions.clear();
        _questions.add(QuestionItem(text: '', type: 'scale'));
      });
    } on RateLimitException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    } catch (e, stackTrace) {
      if (!mounted) return;
      
      // ✅ ERROR HANDLING: AppErrorHandler kullan
      AppErrorHandler.handleError(
        context,
        e,
        stackTrace: stackTrace,
        customMessage: 'Test kaydedilemedi',
      );
      
      // ✅ Kullanıcı dostu hata mesajları (fallback)
      String errorMessage = 'Test kaydedilemedi';
      final errorStr = e.toString();
      
      if (errorStr.contains('permission') || errorStr.contains('PERMISSION_DENIED')) {
        errorMessage = 'Bu işlem için yetkiniz yok';
      } else if (errorStr.contains('network') || errorStr.contains('NETWORK')) {
        errorMessage = 'Ağ bağlantısı hatası. Lütfen internet bağlantınızı kontrol edin.';
      } else if (errorStr.contains('Sadece uzmanlar')) {
        errorMessage = errorStr; // Backend'den gelen mesajı göster
      } else if (errorStr.contains('Soru metni') || errorStr.contains('seçenek')) {
        errorMessage = errorStr; // Validation mesajını göster
      } else if (errorStr.isNotEmpty) {
        // ✅ Hata mesajını kısalt (ilk 100 karakter)
        errorMessage = errorStr.length > 100 
            ? 'Hata: ${errorStr.substring(0, 100)}...' 
            : 'Hata: $errorStr';
      }
      
      setState(() {
        _error = errorMessage;
        _loading = false;
      });
    } finally {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (_roleLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Test Oluştur')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (!_isExpert && !_isAdmin) {
      return Scaffold(
        appBar: AppBar(title: const Text('Test Oluştur')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'Bu sayfa sadece uzmanlara açıktır.',
              textAlign: TextAlign.center,
              style: TextStyle(color: isDark ? Colors.grey.shade300 : Colors.grey.shade700),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Test Oluştur'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _titleCtrl,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'Test Başlığı',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _descCtrl,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Açıklama (isteğe bağlı)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Sorular',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            // ✅ Her soru için ayrı widget
            ...List.generate(_questions.length, (index) {
              return _QuestionCard(
                key: ValueKey(index),
                question: _questions[index],
                index: index,
                onUpdate: (q) => _updateQuestion(index, q),
                onRemove: () => _removeQuestion(index),
                canRemove: _questions.length > 1,
              );
            }),
            // ✅ Soru Ekle butonu en son sorunun altında
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _addQuestion,
                icon: const Icon(Icons.add, size: 20),
                label: const Text('Yeni Soru Ekle'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
            const SizedBox(height: 16),
            if (_error != null)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.shade300),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error_outline, color: Colors.red.shade700),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _error!,
                        style: TextStyle(color: Colors.red.shade700),
                      ),
                    ),
                  ],
                ),
              ),
            if (_success != null)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green.shade300),
                ),
                child: Row(
                  children: [
                    Icon(Icons.check_circle, color: Colors.green.shade700),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _success!,
                        style: TextStyle(color: Colors.green.shade700),
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _loading ? null : _saveTest,
                icon: _loading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save),
                label: Text(_loading ? 'Kaydediliyor...' : 'Kaydet'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ✅ Soru kartı widget'ı
class _QuestionCard extends StatefulWidget {
  final QuestionItem question;
  final int index;
  final Function(QuestionItem) onUpdate;
  final VoidCallback onRemove;
  final bool canRemove;

  const _QuestionCard({
    super.key,
    required this.question,
    required this.index,
    required this.onUpdate,
    required this.onRemove,
    required this.canRemove,
  });

  @override
  State<_QuestionCard> createState() => _QuestionCardState();
}

class _QuestionCardState extends State<_QuestionCard> {
  late TextEditingController _textController;
  late String _selectedType;
  late List<TextEditingController> _optionControllers;
  String? _imageUrl; // ✅ Çoktan seçmeli sorular için görsel URL
  File? _selectedImageFile; // ✅ Yüklenecek görsel dosyası
  bool _uploadingImage = false; // ✅ Görsel yükleme durumu

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController(text: widget.question.text);
    _selectedType = widget.question.type;
    _imageUrl = widget.question.imageUrl;
    _optionControllers = widget.question.options
        .map((opt) => TextEditingController(text: opt))
        .toList();
    if (_selectedType == 'multiple_choice' && _optionControllers.isEmpty) {
      _optionControllers.add(TextEditingController());
      _optionControllers.add(TextEditingController());
    }
  }

  @override
  void dispose() {
    _textController.dispose();
    for (final ctrl in _optionControllers) {
      ctrl.dispose();
    }
    super.dispose();
  }

  void _updateQuestion() {
    widget.onUpdate(QuestionItem(
      text: _textController.text.trim(),
      type: _selectedType,
      options: _selectedType == 'multiple_choice'
          ? _optionControllers
              .map((c) => c.text.trim())
              .where((s) => s.isNotEmpty)
              .toList()
          : [],
      // ✅ Görsel URL'i sadece görsel soru tipinde ekle
      imageUrl: _selectedType == 'image_question' ? _imageUrl : null,
    ));
  }

  // ✅ Görsel seçme ve yükleme
  Future<void> _pickAndUploadImage() async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(source: ImageSource.gallery);
      if (picked == null) return;

      setState(() {
        _uploadingImage = true;
        _selectedImageFile = File(picked.path);
      });

      // ✅ PERFORMANCE: Görseli optimize et (boyut ve kalite dengesi)
      File fileToUpload;
      try {
        final originalPath = picked.path;
        final extension = path.extension(originalPath).toLowerCase();
        final compressedPath = originalPath.replaceAll(RegExp(r'\.(jpg|jpeg|png|heic)$', caseSensitive: false), '_compressed.jpg');
        
        final compressedFile = await FlutterImageCompress.compressAndGetFile(
          originalPath,
          compressedPath,
          quality: 75, // ✅ Kalite/performans dengesi
          minWidth: 1920, // ✅ Yüksek çözünürlük için
          minHeight: 1080,
          keepExif: false, // ✅ EXIF verilerini kaldır (gizlilik + boyut)
        );
        fileToUpload = compressedFile != null ? File(compressedFile.path) : File(originalPath);
      } catch (e) {
        // ✅ Sıkıştırma başarısız olursa orijinal dosyayı kullan
        fileToUpload = File(picked.path);
      }

      // ✅ Firebase Storage'a yükle
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Oturum bulunamadı')),
          );
        }
        return;
      }

      // ✅ Firebase Storage'a yükle
      try {
        final fileName = '${DateTime.now().millisecondsSinceEpoch}_${path.basename(fileToUpload.path)}';
        final ref = FirebaseStorage.instance.ref().child('test_questions/${user.uid}/$fileName');
        
        // ✅ Dosya boyutu kontrolü (max 10MB)
        final fileSize = await fileToUpload.length();
        if (fileSize > 10 * 1024 * 1024) {
          throw Exception('Görsel boyutu 10MB\'dan büyük olamaz.');
        }
        
        final task = await ref.putFile(fileToUpload);
        final downloadUrl = await task.ref.getDownloadURL();
        
        if (downloadUrl.isEmpty) {
          throw Exception('Görsel yüklendi ancak URL alınamadı.');
        }
        
        if (mounted) {
          setState(() {
            _imageUrl = downloadUrl;
            _uploadingImage = false;
          });
          _updateQuestion();
        }
      } catch (storageError) {
        // ✅ Storage hatası - dış catch bloğuna fırlat
        if (mounted) {
          setState(() {
            _uploadingImage = false;
          });
        }
        rethrow; // Dış catch bloğuna fırlat
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _uploadingImage = false;
        });
        // ✅ Kullanıcı dostu hata mesajları
        String errorMessage = 'Görsel yüklenemedi';
        final errorStr = e.toString();
        
        if (errorStr.contains('permission') || errorStr.contains('PERMISSION_DENIED')) {
          errorMessage = 'Görsel yükleme izni reddedildi';
        } else if (errorStr.contains('network') || errorStr.contains('NETWORK')) {
          errorMessage = 'Ağ bağlantısı hatası. Lütfen tekrar deneyin.';
        } else if (errorStr.contains('cancel')) {
          return; // Kullanıcı iptal etti, mesaj gösterme
        } else if (errorStr.isNotEmpty) {
          errorMessage = errorStr.length > 80 
              ? 'Görsel yükleme hatası: ${errorStr.substring(0, 80)}...' 
              : 'Görsel yükleme hatası: $errorStr';
        }
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red.shade700,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  void _removeImage() {
    setState(() {
      _imageUrl = null;
      _selectedImageFile = null;
    });
    _updateQuestion();
  }

  // ✅ Soru tipi etiketi
  String _getTypeLabel(String type) {
    switch (type) {
      case 'scale':
        return '1-5 Arası Puan';
      case 'text':
        return 'Yazılı Cevap';
      case 'multiple_choice':
        return 'Çoktan Seçmeli';
      case 'image_question':
        return 'Görsel Soru';
      default:
        return 'Bilinmeyen Tip';
    }
  }

  // ✅ Soru tipi açıklaması
  String _getTypeDescription(String type) {
    switch (type) {
      case 'scale':
        return 'Kullanıcılar 1-5 arası bir puan seçecek';
      case 'text':
        return 'Kullanıcılar metin cevabı yazacak';
      case 'multiple_choice':
        return 'Kullanıcılar verdiğiniz seçeneklerden birini seçecek';
      case 'image_question':
        return 'Kullanıcılar görseli görüp metin cevabı yazacak';
      default:
        return '';
    }
  }

  void _addOption() {
    setState(() {
      _optionControllers.add(TextEditingController());
    });
    _updateQuestion(); // ✅ Seçenek eklendiğinde soruyu güncelle
  }

  void _removeOption(int index) {
    if (_optionControllers.length <= 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('En az 2 seçenek olmalı')),
      );
      return;
    }
    setState(() {
      _optionControllers[index].dispose();
      _optionControllers.removeAt(index);
    });
    _updateQuestion();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Soru ${widget.index + 1}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      // ✅ Soru tipini göster
                      Text(
                        _getTypeLabel(_selectedType),
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                if (widget.canRemove)
                  IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                    onPressed: widget.onRemove,
                    tooltip: 'Soruyu Sil',
                  ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _textController,
              decoration: const InputDecoration(
                labelText: 'Soru metni',
                border: OutlineInputBorder(),
                hintText: 'Örn: İyi hissediyor muyum?',
              ),
              onChanged: (_) => _updateQuestion(),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark ? Colors.grey.shade800 : Colors.grey.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: isDark ? Colors.grey.shade700 : Colors.grey.shade300),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Cevap Tipi',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _getTypeDescription(_selectedType),
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ChoiceChip(
                  label: const Text('1-5 Arası Puan'),
                  selected: _selectedType == 'scale',
                  onSelected: (selected) {
                    if (selected) {
                      setState(() {
                        _selectedType = 'scale';
                        _optionControllers.clear();
                        _imageUrl = null; // ✅ Scale tipinde görsel kaldır
                      });
                      _updateQuestion();
                    }
                  },
                ),
                ChoiceChip(
                  label: const Text('Yazılı Cevap'),
                  selected: _selectedType == 'text',
                  onSelected: (selected) {
                    if (selected) {
                      setState(() {
                        _selectedType = 'text';
                        _optionControllers.clear();
                        _imageUrl = null; // ✅ Text tipinde görsel kaldır
                      });
                      _updateQuestion();
                    }
                  },
                ),
                ChoiceChip(
                  label: const Text('Çoktan Seçmeli'),
                  selected: _selectedType == 'multiple_choice',
                  onSelected: (selected) {
                    if (selected) {
                      setState(() {
                        _selectedType = 'multiple_choice';
                        _imageUrl = null; // ✅ Çoktan seçmeli için görsel kaldır
                        if (_optionControllers.isEmpty) {
                          _optionControllers.add(TextEditingController());
                          _optionControllers.add(TextEditingController());
                        }
                      });
                      _updateQuestion();
                    }
                  },
                ),
                ChoiceChip(
                  label: const Text('Görsel Soru'),
                  selected: _selectedType == 'image_question',
                  onSelected: (selected) {
                    if (selected) {
                      setState(() {
                        _selectedType = 'image_question';
                        _optionControllers.clear(); // ✅ Görsel soru için seçenekler kaldır
                        // ✅ Görsel URL'i koru (eğer varsa)
                      });
                      _updateQuestion();
                    }
                  },
                ),
              ],
            ),
            if (_selectedType == 'multiple_choice') ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.radio_button_checked, size: 18, color: Colors.blue.shade700),
                            const SizedBox(width: 8),
                            const Text(
                              'Seçenekler',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        TextButton.icon(
                          onPressed: _addOption,
                          icon: const Icon(Icons.add, size: 18),
                          label: const Text('Seçenek Ekle'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'En az 2 seçenek eklemelisiniz',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              ...List.generate(_optionControllers.length, (optIndex) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _optionControllers[optIndex],
                          decoration: InputDecoration(
                            labelText: 'Seçenek ${optIndex + 1}',
                            border: const OutlineInputBorder(),
                            hintText: 'Örn: Evet',
                          ),
                          onChanged: (_) => _updateQuestion(),
                        ),
                      ),
                      if (_optionControllers.length > 2)
                        IconButton(
                          icon: const Icon(Icons.remove_circle_outline, color: Colors.red),
                          onPressed: () => _removeOption(optIndex),
                          tooltip: 'Seçeneği Sil',
                        ),
                    ],
                  ),
                );
              }),
            ],
            if (_selectedType == 'image_question') ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.purple.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.purple.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.image, size: 18, color: Colors.purple.shade700),
                        const SizedBox(width: 8),
                        const Text(
                          'Görsel (Zorunlu)',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Bu soru için bir görsel eklemelisiniz. Kullanıcılar bu görseli görüp metin cevabı verecekler.',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              if (_imageUrl != null)
                Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        _imageUrl!,
                        height: 200,
                        width: double.infinity,
                        fit: BoxFit.contain,
                        loadingBuilder: (context, child, loadingProgress) {
                          if (loadingProgress == null) return child;
                          return Container(
                            height: 200,
                            color: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
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
                            height: 200,
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.broken_image, size: 48, color: isDark ? Colors.grey.shade400 : Colors.grey.shade600),
                                const SizedBox(height: 8),
                                Text(
                                  'Görsel yüklenemedi',
                                  style: TextStyle(color: isDark ? Colors.grey.shade400 : Colors.grey.shade600),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                    Positioned(
                      right: 8,
                      top: 8,
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: _removeImage,
                          borderRadius: BorderRadius.circular(20),
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: Colors.red.shade600,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.2),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: const Icon(Icons.close, color: Colors.white, size: 18),
                          ),
                        ),
                      ),
                    ),
                  ],
                )
              else
                OutlinedButton.icon(
                  onPressed: _uploadingImage ? null : _pickAndUploadImage,
                  icon: _uploadingImage
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.image),
                  label: Text(_uploadingImage ? 'Yükleniyor...' : 'Görsel Ekle'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}
