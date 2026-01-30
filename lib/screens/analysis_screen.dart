import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:file_picker/file_picker.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:path/path.dart' as path;
import '../services/analysis_service.dart';
import '../services/analytics_service.dart';
import '../widgets/friendly_error_widget.dart';
import 'ai_consultation_detail_screen.dart';

class AnalysisScreen extends StatefulWidget {
  const AnalysisScreen({super.key});

  @override
  State<AnalysisScreen> createState() => _AnalysisScreenState();
}

class _AnalysisScreenState extends State<AnalysisScreen> {
  final _textCtrl = TextEditingController();

  bool _loading = false;
  String? _result;
  String? _error;
  
  // ✅ Eklenti durumu
  File? _selectedFile; // Mobil için
  Uint8List? _selectedFileBytes; // Web için
  String? _selectedFileName; // Web için dosya adı
  String? _fileType; // 'image', 'video', 'file'
  String? _uploadedFileUrl;
  bool _uploading = false;
  
  @override
  void initState() {
    super.initState();
    // ✅ Analytics: Screen view tracking
    AnalyticsService.logScreenView('analysis');
    _textCtrl.addListener(() {
      setState(() {}); // Karakter sayacı için
    });
  }

  // ✅ Cooldown
  static const Duration _cooldown = Duration(seconds: 8);
  DateTime? _lastRunAt;

  bool get _inCooldown {
    if (_lastRunAt == null) return false;
    return DateTime.now().difference(_lastRunAt!) < _cooldown;
  }

  int get _cooldownRemaining {
    if (_lastRunAt == null) return 0;
    final diff = DateTime.now().difference(_lastRunAt!);
    final remain = _cooldown.inSeconds - diff.inSeconds;
    return remain.clamp(0, _cooldown.inSeconds);
  }

  @override
  void dispose() {
    _textCtrl.dispose();
    super.dispose();
  }

  // ✅ Dosya seçme fonksiyonu (Web ve Mobil desteği)
  Future<void> _pickFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        allowMultiple: false,
      );

      if (result != null && result.files.single != null) {
        final pickedFile = result.files.single;
        
        // ✅ Web platformu için özel işleme
        if (kIsWeb) {
          if (pickedFile.bytes != null) {
            // Web'de dosya bytes olarak gelir
            final bytes = pickedFile.bytes!;
            final fileName = pickedFile.name;
            final ext = path.extension(fileName).toLowerCase();
            
            // Geçici dosya oluştur (web için)
            // Web'de File sınıfı çalışmaz, bu yüzden bytes'ı direkt kullanacağız
            setState(() {
              _fileType = ['.jpg', '.jpeg', '.png', '.heic', '.webp'].contains(ext)
                  ? 'image'
                  : (['.mp4', '.mov', '.avi'].contains(ext) ? 'video' : 'file');
              _uploadedFileUrl = null;
              // Web için bytes'ı sakla (File yerine)
              _selectedFileBytes = bytes;
              _selectedFileName = fileName;
            });
          } else {
            throw Exception('Dosya bytes alınamadı');
          }
        } else {
          // ✅ Mobil platform (Android/iOS)
          if (pickedFile.path != null) {
            File originalFile = File(pickedFile.path!);
            String ext = path.extension(originalFile.path).toLowerCase();

            // Eğer Resimse -> SIKIŞTIR
            if (['.jpg', '.jpeg', '.png', '.heic', '.webp'].contains(ext)) {
              final compressed = await FlutterImageCompress.compressAndGetFile(
                originalFile.path,
                originalFile.path.replaceFirst(ext, '_compressed.jpg'),
                quality: 60,
                minWidth: 1024,
              );
              setState(() {
                _selectedFile = compressed != null ? File(compressed.path) : originalFile;
                _fileType = 'image';
                _uploadedFileUrl = null;
                _selectedFileBytes = null;
                _selectedFileName = null;
              });
            }
            // Video
            else if (['.mp4', '.mov', '.avi'].contains(ext)) {
              setState(() {
                _selectedFile = originalFile;
                _fileType = 'video';
                _uploadedFileUrl = null;
                _selectedFileBytes = null;
                _selectedFileName = null;
              });
            }
            // Diğer (PDF, Doc vs.)
            else {
              setState(() {
                _selectedFile = originalFile;
                _fileType = 'file';
                _uploadedFileUrl = null;
                _selectedFileBytes = null;
                _selectedFileName = null;
              });
            }
          }
        }
      }
    } catch (e) {
      debugPrint("Dosya seçme hatası: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Dosya seçilemedi: $e")),
        );
      }
    }
  }

  // ✅ Firebase Storage'a yükleme (Web ve Mobil desteği)
  Future<String?> _uploadFileToStorage(String userId) async {
    try {
      setState(() => _uploading = true);
      
      String fileName;
      UploadTask task;
      
      if (kIsWeb) {
        // ✅ Web platformu: bytes kullan
        if (_selectedFileBytes == null || _selectedFileName == null) {
          throw Exception('Dosya bytes veya adı bulunamadı');
        }
        fileName = '${DateTime.now().millisecondsSinceEpoch}_${_selectedFileName}';
        final ref = FirebaseStorage.instance.ref().child('ai_consultations/$userId/$fileName');
        task = ref.putData(_selectedFileBytes!);
      } else {
        // ✅ Mobil platform: File kullan
        if (_selectedFile == null) {
          throw Exception('Dosya bulunamadı');
        }
        fileName = '${DateTime.now().millisecondsSinceEpoch}_${path.basename(_selectedFile!.path)}';
        final ref = FirebaseStorage.instance.ref().child('ai_consultations/$userId/$fileName');
        task = ref.putFile(_selectedFile!);
      }
      
      final snapshot = await task;
      final url = await snapshot.ref.getDownloadURL();
      
      setState(() {
        _uploading = false;
        _uploadedFileUrl = url;
      });
      
      return url;
    } catch (e) {
      debugPrint("Dosya yükleme hatası: $e");
      setState(() => _uploading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Dosya yüklenemedi: $e")),
        );
      }
      return null;
    }
  }

  // ✅ Seçili dosyayı kaldır
  void _removeFile() {
    setState(() {
      _selectedFile = null;
      _selectedFileBytes = null;
      _selectedFileName = null;
      _fileType = null;
      _uploadedFileUrl = null;
    });
  }

  // ✅ Analiz sonucunu parse et ve güçlü-zayıf yönleri ayır
  List<Widget> _parseAnalysisResult(String result, bool isDark) {
    final widgets = <Widget>[];
    
    // Güçlü yönler ve zayıf yönler için pattern'ler
    final strongPointsPattern = RegExp(
      r'(?:güçlü\s+yön|güçlü\s+nokta|başarılı|olumlu|iyi\s+giden|güçlü\s+olan)[\s\S]{0,500}?(?=\n\n|\n[^\n]*?:|$)',
      caseSensitive: false,
    );
    
    final weakPointsPattern = RegExp(
      r'(?:zayıf\s+yön|gelişim\s+alan|dikkat\s+edilmesi\s+gereken|iyileştirilebilecek|desteklenmesi\s+gereken)[\s\S]{0,500}?(?=\n\n|\n[^\n]*?:|$)',
      caseSensitive: false,
    );
    
    // Eğer pattern'ler bulunursa ayrı göster
    final strongMatch = strongPointsPattern.firstMatch(result);
    final weakMatch = weakPointsPattern.firstMatch(result);
    
    if (strongMatch != null || weakMatch != null) {
      // Güçlü yönler
      if (strongMatch != null) {
        final strongText = strongMatch.group(0)?.trim() ?? '';
        if (strongText.isNotEmpty) {
          widgets.add(
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.green.shade900.withOpacity(0.2)
                    : Colors.green.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isDark
                      ? Colors.green.shade800
                      : Colors.green.shade200,
                  width: 1.5,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.trending_up,
                        color: isDark ? Colors.green.shade300 : Colors.green.shade700,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Güçlü Yönleriniz',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.green.shade300 : Colors.green.shade700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SelectableText(
                    strongText,
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.6,
                      color: isDark ? Colors.grey.shade200 : Colors.black87,
                    ),
                  ),
                ],
              ),
            ),
          );
          widgets.add(const SizedBox(height: 16));
        }
      }
      
      // Zayıf yönler / Gelişim alanları
      if (weakMatch != null) {
        final weakText = weakMatch.group(0)?.trim() ?? '';
        if (weakText.isNotEmpty) {
          widgets.add(
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.orange.shade900.withOpacity(0.2)
                    : Colors.orange.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isDark
                      ? Colors.orange.shade800
                      : Colors.orange.shade200,
                  width: 1.5,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.trending_up,
                        color: isDark ? Colors.orange.shade300 : Colors.orange.shade700,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Gelişim Alanları',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.orange.shade300 : Colors.orange.shade700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SelectableText(
                    weakText,
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.6,
                      color: isDark ? Colors.grey.shade200 : Colors.black87,
                    ),
                  ),
                ],
              ),
            ),
          );
          widgets.add(const SizedBox(height: 16));
        }
      }
    }
    
    // Tüm analiz metni
    widgets.add(
      Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark
              ? Colors.deepPurple.shade900.withOpacity(0.3)
              : Colors.deepPurple.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDark
                ? Colors.deepPurple.shade700
                : Colors.deepPurple.shade100,
            width: 1,
          ),
        ),
        child: SelectableText(
          result,
          style: TextStyle(
            fontSize: 15,
            height: 1.6,
            color: isDark ? Colors.grey.shade200 : Colors.black87,
          ),
        ),
      ),
    );
    
    return widgets;
  }

  Future<void> _runAnalysis() async {
    if (_loading || _inCooldown) return;

    final input = _textCtrl.text.trim();
    
    // ✅ Metin veya dosya olmalı (ikisi de boş olamaz)
    if (input.isEmpty && _selectedFile == null && _selectedFileBytes == null) {
      setState(() {
        _error = 'Lütfen analiz için bir metin girin veya bir dosya ekleyin.';
        _result = null;
      });
      return;
    }
    
    // ✅ Metin varsa uzunluk kontrolü yap
    if (input.isNotEmpty) {
      if (input.length > 5000) {
        setState(() {
          _error = 'Metin en fazla 5000 karakter olabilir.';
          _result = null;
        });
        return;
      }
      
      if (input.length < 10) {
        setState(() {
          _error = 'Analiz için en az 10 karakter girmelisiniz.';
          _result = null;
        });
        return;
      }
    }

    setState(() {
      _loading = true;
      _error = null;
      _lastRunAt = DateTime.now();
    });

    try {
      // ✅ Eğer dosya seçildiyse önce Storage'a yükle
      List<String> attachments = [];
      if (_selectedFile != null || _selectedFileBytes != null) {
        final user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          final url = await _uploadFileToStorage(user.uid);
          if (url != null) {
            attachments.add(url);
          } else {
            // Dosya yüklenemedi, devam et ama kullanıcıyı bilgilendir
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Dosya yüklenemedi, sadece metin analiz edilecek.")),
              );
            }
          }
        }
      }

      final response = await AnalysisService.generateAnalysis(
        input.isEmpty ? '(Sadece eklenti analizi)' : input, 
        attachments: attachments.isNotEmpty ? attachments : null
      );
      if (!mounted) return;

      if (response['error'] != null) {
        setState(() {
          _error = response['error'] as String? ?? 'Bilinmeyen bir hata oluştu.';
          _result = null;
          _loading = false;
        });
      } else {
        final analysis = response['analysis'] as String?;
        if (analysis == null || analysis.trim().isEmpty) {
          setState(() {
            _error = 'AI\'dan anlamlı bir yanıt alınamadı.';
            _result = null;
            _loading = false;
          });
        } else {
          setState(() {
            _result = analysis;
            _loading = false;
          });
          
          // ✅ Sonuç ekranına yönlendir (diyalog yerine)
          if (mounted && _result != null) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => AIConsultationDetailScreen(
                  consultationId: response['consultationId'] as String? ?? '',
                  text: input.isEmpty ? '(Sadece eklenti analizi)' : input,
                  analysis: _result!,
                  createdAt: DateTime.now(),
                ),
              ),
            );
            // Ekrandan çıktıktan sonra state'i temizle
            Future.delayed(const Duration(milliseconds: 300), () {
              if (mounted) {
                setState(() {
                  _result = null;
                  _textCtrl.clear();
                  _selectedFile = null;
                  _selectedFileBytes = null;
                  _selectedFileName = null;
                  _fileType = null;
                  _uploadedFileUrl = null;
                });
              }
            });
          }
        }
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _result = null;
      });
    } finally {
      if (!mounted) return;
      setState(() {
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final buttonText = _loading
        ? 'AI analiz ediyor...'
        : _inCooldown
        ? 'Lütfen bekle ($_cooldownRemaining sn)'
        : 'AI\'ye Danış';

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scaffoldBg = isDark ? const Color(0xFF121212) : Colors.grey.shade50;

    return Scaffold(
      appBar: AppBar(
        title: const Text('AI Danışmanlığı'),
        elevation: 0,
        backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
      ),
      backgroundColor: scaffoldBg,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Section with gradient
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: isDark
                      ? [
                          Colors.deepPurple.shade900.withOpacity(0.5),
                          Colors.deepPurple.shade800.withOpacity(0.3),
                        ]
                      : [
                          Colors.deepPurple.shade50,
                          Colors.deepPurple.shade100.withOpacity(0.5),
                        ],
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isDark
                      ? Colors.deepPurple.shade700
                      : Colors.deepPurple.shade200,
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.deepPurple.withOpacity(0.2),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.deepPurple.shade400,
                          Colors.deepPurple.shade600,
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.deepPurple.withOpacity(0.4),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.psychology,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Buyrun, dinliyorum...?',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'AI ile profesyonel destek',
                          style: TextStyle(
                            fontSize: 14,
                            color: isDark
                                ? Colors.grey.shade400
                                : Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Input Section
            Card(
              elevation: 0,
              color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(
                  color: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
                  width: 1,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 16),
                    TextField(
                      controller: _textCtrl,
                      maxLines: 10,
                      minLines: 6,
                      style: TextStyle(
                        color: isDark ? Colors.white : Colors.black87,
                        fontSize: 15,
                        height: 1.5,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Duygularınızı, düşüncelerinizi veya yaşadığınız durumu buraya yazın...\n\nÖrnek: "Son zamanlarda kendimi çok yorgun hissediyorum. Uyku düzenim bozuldu ve hiçbir şeye odaklanamıyorum."',
                        hintStyle: TextStyle(
                          color: isDark ? Colors.grey.shade500 : Colors.grey.shade400,
                          fontSize: 14,
                          height: 1.4,
                        ),
                        filled: true,
                        fillColor: isDark ? Colors.grey.shade900 : Colors.grey.shade50,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: isDark ? Colors.grey.shade800 : Colors.grey.shade300,
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: isDark ? Colors.grey.shade800 : Colors.grey.shade300,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: Colors.deepPurple.shade400,
                            width: 2,
                          ),
                        ),
                        contentPadding: const EdgeInsets.all(16),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '${_textCtrl.text.length} karakter',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? Colors.grey.shade500 : Colors.grey.shade600,
                          ),
                        ),
                        if (_textCtrl.text.length > 5000)
                          Text(
                            'Maksimum 5000 karakter',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.red.shade600,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.blue.shade900.withOpacity(0.2)
                            : Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isDark
                              ? Colors.blue.shade800
                              : Colors.blue.shade200,
                          width: 1,
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.info_outline,
                            size: 18,
                            color: isDark ? Colors.blue.shade300 : Colors.blue.shade700,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'AI Analizi; Tıp, Psikoloji, Sosyoloji\'den insan ilişkilerine kadar ruhsal ve bedensel sağlığınız için size profesyonel bir destek için burada. Ancak bu uygulamanın tamamı gibi burada da yasal olarak hiçbir sorumluluk kabul edilmemektedir. O zaman buyurun önce yaş ve cinsiyet belirterek danışmanız önerilir..',
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark ? Colors.blue.shade300 : Colors.blue.shade700,
                                height: 1.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    // ✅ Eklenti ekleme bölümü
                    Card(
                      elevation: 0,
                      color: isDark ? Colors.grey.shade900 : Colors.grey.shade50,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(
                          color: isDark ? Colors.grey.shade800 : Colors.grey.shade300,
                          width: 1,
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.attach_file,
                                  color: isDark ? Colors.deepPurple.shade300 : Colors.deepPurple,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Eklentiler (İsteğe Bağlı)',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                      color: isDark ? Colors.white : Colors.black87,
                                    ),
                                  ),
                                ),
                                if (_selectedFile != null || _selectedFileBytes != null)
                                  IconButton(
                                    icon: const Icon(Icons.close, size: 20),
                                    color: Colors.red,
                                    onPressed: _removeFile,
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            if (_selectedFile == null && _selectedFileBytes == null)
                              ElevatedButton.icon(
                                onPressed: _uploading ? null : _pickFile,
                                icon: const Icon(Icons.add, size: 18),
                                label: const Text('Dosya Ekle'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: isDark ? Colors.deepPurple.shade800 : Colors.deepPurple.shade100,
                                  foregroundColor: isDark ? Colors.deepPurple.shade200 : Colors.deepPurple,
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                              )
                            else ...[
                              Row(
                                children: [
                                  Icon(
                                    _fileType == 'image' 
                                        ? Icons.image 
                                        : _fileType == 'video' 
                                            ? Icons.video_file 
                                            : Icons.insert_drive_file,
                                    size: 20,
                                    color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      kIsWeb 
                                          ? (_selectedFileName ?? 'Dosya')
                                          : path.basename(_selectedFile!.path),
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: isDark ? Colors.grey.shade300 : Colors.grey.shade700,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  if (_uploading)
                                    const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(strokeWidth: 2),
                                    )
                                  else if (_uploadedFileUrl != null)
                                    Icon(
                                      Icons.check_circle,
                                      size: 20,
                                      color: Colors.green,
                                    ),
                                ],
                              ),
                              if (_fileType == 'image') ...[
                                const SizedBox(height: 8),
                                if (kIsWeb && _selectedFileBytes != null)
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: Image.memory(
                                      _selectedFileBytes!,
                                      height: 150,
                                      fit: BoxFit.cover,
                                    ),
                                  )
                                else if (!kIsWeb && _selectedFile != null)
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: Image.file(
                                      _selectedFile!,
                                      height: 150,
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                              ],
                            ],
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: (_loading || _inCooldown)
                                ? [
                                    Colors.grey.shade400,
                                    Colors.grey.shade500,
                                  ]
                                : [
                                    Colors.deepPurple.shade400,
                                    Colors.deepPurple.shade600,
                                  ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: (_loading || _inCooldown)
                              ? null
                              : [
                                  BoxShadow(
                                    color: Colors.deepPurple.withOpacity(0.4),
                                    blurRadius: 12,
                                    offset: const Offset(0, 6),
                                  ),
                                ],
                        ),
                        child: ElevatedButton(
                          onPressed: (_loading || _inCooldown) ? null : _runAnalysis,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 18),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 0,
                          ),
                        child: _loading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                ),
                              )
                            : Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.auto_awesome, size: 20),
                                  const SizedBox(width: 8),
                                  Text(
                                    buttonText,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Error Section
            if (_error != null)
              FriendlyErrorWidget(
                error: _error!,
                isDark: isDark,
                onRetry: _runAnalysis,
              ),
          ],
        ),
      ),
    );
  }
}
