import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shimmer/shimmer.dart';
import 'package:intl/intl.dart';
import '../services/analytics_service.dart';
import '../widgets/empty_state_widget.dart';
import 'ai_consultation_detail_screen.dart';

class AIConsultationsScreen extends StatefulWidget {
  final bool hideAppBar;
  
  const AIConsultationsScreen({super.key, this.hideAppBar = false});

  @override
  State<AIConsultationsScreen> createState() => _AIConsultationsScreenState();
}

class _AIConsultationsScreenState extends State<AIConsultationsScreen> {
  String _searchQuery = '';
  String _displaySearchQuery = ''; // ✅ PERFORMANCE: Debounced search query
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    // ✅ Analytics: Screen view tracking
    AnalyticsService.logScreenView('ai_consultations');
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      if (mounted) {
        setState(() {
          _displaySearchQuery = value.toLowerCase().trim();
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scaffoldBg = isDark ? const Color(0xFF121212) : Colors.grey.shade50;

    if (userId == null) {
      final content = Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.lock_outline,
              size: 64,
              color: isDark ? Colors.grey.shade600 : Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              'Giriş yapmalısınız',
              style: TextStyle(
                fontSize: 16,
                color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
              ),
            ),
          ],
        ),
      );
      
      if (widget.hideAppBar) {
        return content;
      }
      
      return Scaffold(
        appBar: AppBar(
          title: const Text('AI Danışmalarım'),
          elevation: 0,
        ),
        backgroundColor: scaffoldBg,
        body: content,
      );
    }

    final body = RefreshIndicator(
      onRefresh: () async {
        // StreamBuilder otomatik yenilenecek
        await Future.delayed(const Duration(milliseconds: 500));
      },
      child: Column(
        children: [
          // Arama Barı
          if (!widget.hideAppBar)
            Padding(
              padding: const EdgeInsets.all(12),
              child: TextField(
                onChanged: (value) {
                  setState(() => _searchQuery = value);
                  _onSearchChanged(value);
                },
                decoration: InputDecoration(
                  hintText: 'Danışma ara...',
                  prefixIcon: const Icon(Icons.search),
                  filled: true,
                  fillColor: isDark ? Colors.grey.shade900 : Colors.grey.shade100,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
              ),
            ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('aiConsultations')
                    .where('userId', isEqualTo: userId)
                    .orderBy('createdAt', descending: true)
                    .snapshots(),
                builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return _buildSkeletonLoading(isDark);
            }

            if (snapshot.hasError) {
              return EmptyStates.error(
                message: snapshot.error.toString(),
                onRetry: () => setState(() {}),
              );
            }

            final allConsultations = snapshot.data?.docs ?? [];
            
            // ✅ PERFORMANCE: Arama filtresi (debounced)
            final consultations = _displaySearchQuery.isEmpty
                ? allConsultations
                : allConsultations.where((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    final text = (data['text'] ?? '').toString().toLowerCase();
                    final analysis = (data['analysis'] ?? '').toString().toLowerCase();
                    return text.contains(_displaySearchQuery) || analysis.contains(_displaySearchQuery);
                  }).toList();

            if (consultations.isEmpty) {
              return EmptyStateWidget(
                icon: Icons.psychology_outlined,
                title: _displaySearchQuery.isEmpty 
                    ? 'Henüz AI danışmanız yok'
                    : 'Arama sonucu bulunamadı',
                subtitle: _displaySearchQuery.isEmpty
                    ? 'AI analiz ekranından danışma başlatabilirsiniz'
                    : 'Arama kriterlerinizi değiştirmeyi deneyin',
                iconColor: isDark ? Colors.deepPurple.shade300 : Colors.deepPurple.shade700,
                actionLabel: _displaySearchQuery.isEmpty ? 'AI Analiz' : null,
                onAction: _displaySearchQuery.isEmpty
                    ? () => Navigator.pushNamed(context, '/analysis')
                    : null,
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: consultations.length,
              itemBuilder: (context, index) {
                final doc = consultations[index];
                final data = doc.data() as Map<String, dynamic>;
                final text = (data['text'] ?? '').toString();
                final analysis = (data['analysis'] ?? '').toString();
                final createdAt = data['createdAt'] as Timestamp?;
                final attachments = data['attachments'] as List?;

                // Metin önizlemesi (ilk 80 karakter)
                final preview = text.length > 80 ? '${text.substring(0, 80)}...' : text;

                return _buildConsultationCard(
                  context,
                  isDark,
                  doc.id,
                  preview,
                  text,
                  analysis,
                  createdAt?.toDate(),
                  attachments?.length ?? 0,
                );
              },
            );
                },
              ),
            ),
          ],
        ),
      );
    
    if (widget.hideAppBar) {
      return body;
    }
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('AI Danışmalarım'),
        elevation: 0,
        backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
      ),
      backgroundColor: scaffoldBg,
      body: body,
    );
  }

  Widget _buildSkeletonLoading(bool isDark) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: 5,
      itemBuilder: (context, index) {
        return Shimmer.fromColors(
          baseColor: isDark ? Colors.grey.shade800 : Colors.grey.shade300,
          highlightColor: isDark ? Colors.grey.shade700 : Colors.grey.shade100,
          child: Card(
            margin: const EdgeInsets.only(bottom: 12),
            elevation: 0,
            color: isDark ? Colors.grey.shade900 : Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(
                color: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
              ),
            ),
            child: ListTile(
              contentPadding: const EdgeInsets.all(16),
              leading: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: isDark ? Colors.grey.shade800 : Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              title: Container(
                height: 16,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: isDark ? Colors.grey.shade800 : Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Container(
                  height: 12,
                  width: 120,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.grey.shade800 : Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildConsultationCard(
    BuildContext context,
    bool isDark,
    String consultationId,
    String preview,
    String text,
    String analysis,
    DateTime? createdAt,
    int attachmentsCount,
  ) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
          width: 1,
        ),
      ),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => AIConsultationDetailScreen(
                consultationId: consultationId,
                text: text,
                analysis: analysis,
                createdAt: createdAt,
              ),
            ),
          );
        },
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Icon container with gradient
              Container(
                width: 56,
                height: 56,
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
                      color: Colors.deepPurple.withOpacity(0.3),
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
              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      preview.isEmpty ? '(Eklenti analizi)' : preview,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white : Colors.black87,
                        height: 1.4,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        if (createdAt != null) ...[
                          Icon(
                            Icons.access_time,
                            size: 14,
                            color: isDark ? Colors.grey.shade500 : Colors.grey.shade600,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _formatDate(createdAt!),
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                            ),
                          ),
                        ],
                        if (attachmentsCount > 0) ...[
                          const SizedBox(width: 12),
                          Icon(
                            Icons.attach_file,
                            size: 14,
                            color: isDark ? Colors.grey.shade500 : Colors.grey.shade600,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '$attachmentsCount eklenti',
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.chevron_right,
                color: isDark ? Colors.grey.shade600 : Colors.grey.shade400,
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inDays == 0) {
      if (diff.inHours == 0) {
        if (diff.inMinutes == 0) {
          return 'Az önce';
        }
        return '${diff.inMinutes} dk önce';
      }
      return '${diff.inHours} saat önce';
    } else if (diff.inDays == 1) {
      return 'Dün';
    } else if (diff.inDays < 7) {
      return '${diff.inDays} gün önce';
    } else {
      return DateFormat('dd MMM yyyy', 'tr').format(date);
    }
  }
}

