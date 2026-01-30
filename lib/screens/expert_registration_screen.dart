import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/subscription_model.dart';
import '../core/providers/subscription_provider.dart';
import '../utils/error_handler.dart';
import '../utils/input_validator.dart';
import '../constants/app_constants.dart';
import '../widgets/empty_state_widget.dart';
import '../services/analytics_service.dart';

/// Expert registration screen with subscription
class ExpertRegistrationScreen extends ConsumerStatefulWidget {
  const ExpertRegistrationScreen({super.key});

  @override
  ConsumerState<ExpertRegistrationScreen> createState() => _ExpertRegistrationScreenState();
}

class _ExpertRegistrationScreenState extends ConsumerState<ExpertRegistrationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _professionCtrl = TextEditingController();
  final _specialtiesCtrl = TextEditingController();
  final _aboutCtrl = TextEditingController();
  final _educationCtrl = TextEditingController();
  
  SubscriptionPlan _selectedPlan = SubscriptionPlan.expert; // Tek plan: 499₺/ay
  bool _acceptTerms = false;
  bool _loading = false;

  @override
  void dispose() {
    _professionCtrl.dispose();
    _specialtiesCtrl.dispose();
    _aboutCtrl.dispose();
    _educationCtrl.dispose();
    super.dispose();
  }

  Future<void> _submitRegistration() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_acceptTerms) {
      AppErrorHandler.showInfo(context, 'Lütfen şartları kabul edin');
      return;
    }

    setState(() => _loading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('Kullanıcı giriş yapmamış');
      }

      // ✅ BAŞVURU SİSTEMİ: Expert başvurusu oluştur (Admin onayı bekleyecek)
      final applicationData = {
        'uid': user.uid,
        'name': (await FirebaseFirestore.instance.collection('users').doc(user.uid).get()).data()?['name'] ?? 'Kullanıcı',
        'username': (await FirebaseFirestore.instance.collection('users').doc(user.uid).get()).data()?['username'] ?? '',
        'email': user.email ?? '',
        'profession': InputValidator.sanitize(_professionCtrl.text),
        'specialties': InputValidator.sanitize(_specialtiesCtrl.text),
        'about': InputValidator.sanitize(_aboutCtrl.text),
        'education': InputValidator.sanitize(_educationCtrl.text),
        'selectedPlan': 'expert', // Tek plan: 499₺/ay - Admin onayladığında bu plan ile abonelik başlatılacak
        'status': 'pending', // Admin onayı bekliyor
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      // Expert başvurusu oluştur
      await FirebaseFirestore.instance.collection('expert_applications').add(applicationData);

      // Kullanıcı bilgilerini güncelle (henüz expert değil, başvuru yaptı)
      await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
        'expertStatus': 'pending', // Başvuru bekliyor
        'requestedRole': 'expert',
        'profession': InputValidator.sanitize(_professionCtrl.text),
        'specialties': InputValidator.sanitize(_specialtiesCtrl.text),
        'about': InputValidator.sanitize(_aboutCtrl.text),
        'education': InputValidator.sanitize(_educationCtrl.text),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Analytics
      await AnalyticsService.logEvent('expert_application_submitted', parameters: {
        'plan': _selectedPlan.value,
        'profession': _professionCtrl.text,
      });

      if (!mounted) return;

      AppErrorHandler.showSuccess(
        context,
        'Uzman başvurunuz başarıyla gönderildi! Admin onayından sonra uzman olarak kaydolacaksınız ve aylık abonelik başlatılacaktır.',
      );

      // Profil ekranına yönlendir
      Navigator.of(context).pop();
    } catch (e, stackTrace) {
      if (!mounted) return;
      AppErrorHandler.handleError(
        context,
        e,
        stackTrace: stackTrace,
        customMessage: 'Başvuru sırasında bir hata oluştu',
      );
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scaffoldBg = isDark ? const Color(0xFF121212) : Colors.grey.shade50;

    return Scaffold(
      backgroundColor: scaffoldBg,
      appBar: AppBar(
        title: const Text('Uzman Kaydı'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppConstants.defaultPadding),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Bilgilendirme
              Card(
                color: isDark ? Colors.deepPurple.shade900.withOpacity(0.3) : Colors.deepPurple.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.info_outline, color: Colors.deepPurple),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Uzman Başvurusu',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.deepPurple.shade200 : Colors.deepPurple.shade700,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Uzman olarak kaydolmak için başvuru yapmanız gerekmektedir. Başvurunuz admin tarafından incelendikten sonra onaylanırsa, seçtiğiniz aylık abonelik planı ile uzman olarak kaydolacaksınız.',
                        style: TextStyle(
                          fontSize: 13,
                          color: isDark ? Colors.deepPurple.shade200 : Colors.deepPurple.shade700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Abonelik Bilgisi (Tek Plan)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark ? Colors.deepPurple.shade900.withOpacity(0.3) : Colors.deepPurple.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isDark ? Colors.deepPurple.shade700 : Colors.deepPurple.shade200,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.workspace_premium,
                      color: Colors.deepPurple,
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Uzman Aboneliği',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '499₺ / ay',
                            style: TextStyle(
                              fontSize: 14,
                              color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Form alanları
              Text(
                'Uzman Bilgileri',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              const SizedBox(height: 12),

              // Meslek
              DropdownButtonFormField<String>(
                decoration: InputDecoration(
                  labelText: 'Meslek *',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppConstants.borderRadius),
                  ),
                ),
                items: AppConstants.professionList.map((prof) {
                  return DropdownMenuItem(value: prof, child: Text(prof));
                }).toList(),
                onChanged: (value) {
                  if (value != null) {
                    _professionCtrl.text = value;
                  }
                },
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Meslek seçiniz';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Uzmanlık Alanları
              TextFormField(
                controller: _specialtiesCtrl,
                decoration: InputDecoration(
                  labelText: 'Uzmanlık Alanları (virgülle ayırın)',
                  hintText: 'Örn: Depresyon, Anksiyete, Çift Terapisi',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppConstants.borderRadius),
                  ),
                ),
                maxLength: AppConstants.maxSpecialtiesLength,
                maxLines: 2,
              ),
              const SizedBox(height: 16),

              // Hakkında
              TextFormField(
                controller: _aboutCtrl,
                decoration: InputDecoration(
                  labelText: 'Hakkınızda',
                  hintText: 'Kendiniz ve uzmanlık alanınız hakkında bilgi verin',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppConstants.borderRadius),
                  ),
                ),
                maxLength: AppConstants.maxAboutLength,
                maxLines: 5,
              ),
              const SizedBox(height: 16),

              // Eğitim
              TextFormField(
                controller: _educationCtrl,
                decoration: InputDecoration(
                  labelText: 'Eğitim ve Sertifikalar',
                  hintText: 'Eğitim geçmişiniz ve sertifikalarınız',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppConstants.borderRadius),
                  ),
                ),
                maxLength: AppConstants.maxEducationLength,
                maxLines: 4,
              ),
              const SizedBox(height: 24),

              // Şartlar ve Koşullar
              Row(
                children: [
                  Checkbox(
                    value: _acceptTerms,
                    onChanged: (value) {
                      setState(() => _acceptTerms = value ?? false);
                    },
                  ),
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        // Şartlar ekranını aç
                      },
                      child: Text(
                        'Şartları ve koşulları kabul ediyorum *',
                        style: TextStyle(
                          color: isDark ? Colors.grey.shade300 : Colors.grey.shade700,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Submit Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _loading ? null : _submitRegistration,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppConstants.borderRadius),
                    ),
                  ),
                  child: _loading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text(
                          'Kayıt Ol',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPlanCard(SubscriptionPlan plan, bool isDark) {
    final isSelected = _selectedPlan == plan;
    final isTrial = false; // Trial plan artık yok, tüm planlar ücretli

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: isSelected ? 4 : 1,
      color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppConstants.borderRadius),
        side: BorderSide(
          color: isSelected
              ? Colors.deepPurple
              : (isDark ? Colors.grey.shade800 : Colors.grey.shade300),
          width: isSelected ? 2 : 1,
        ),
      ),
      child: InkWell(
        onTap: () {
          setState(() => _selectedPlan = plan);
        },
        borderRadius: BorderRadius.circular(AppConstants.borderRadius),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Radio<SubscriptionPlan>(
                value: plan,
                groupValue: _selectedPlan,
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _selectedPlan = value);
                  }
                },
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          plan.displayName,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${plan.monthlyPrice.toStringAsFixed(2)} TL / ay',
                      style: TextStyle(
                        fontSize: 14,
                        color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
