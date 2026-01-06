import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/post_model.dart';
import '../repositories/firestore_post_repository.dart';
import '../repositories/firestore_user_repository.dart';
import '../services/search_service.dart';
import '../widgets/post_card.dart';
import 'expert_public_profile_screen.dart';
import 'public_client_profile_screen.dart';

enum SearchTarget { all, posts, people }
enum SearchPersonKind { any, expert, client }

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _searchCtrl = TextEditingController();
  final _expertiseCtrl = TextEditingController();
  final _postRepo = FirestorePostRepository.instance;
  final _userRepo = FirestoreUserRepository();
  final _auth = FirebaseAuth.instance;

  SearchTarget _searchTarget = SearchTarget.all;
  SearchPersonKind _personKind = SearchPersonKind.any;
  String _selectedProfession = 'all';
  
  String? _currentUserId;
  String? _currentUserRole;
  List<String> _myFollowingIds = [];

  // Debounce için
  String _lastSearchQuery = '';
  String _lastExpertiseQuery = '';
  Timer? _debounceTimer;
  Timer? _expertiseDebounceTimer;

  static const List<String> _professionList = [
    'Psikolog', 'Klinik Psikolog', 'Nöropsikolog', 'Psikiyatr',
    'Psikolojik Danışman (PDR)', 'Sosyal Hizmet Uzmanı', 'Aile Danışmanı',
  ];

  @override
  void initState() {
    super.initState();
    _loadCurrentUserData();
    _searchCtrl.addListener(_onSearchChanged);
    _expertiseCtrl.addListener(_onExpertiseChanged);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _expertiseCtrl.dispose();
    _debounceTimer?.cancel();
    _expertiseDebounceTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadCurrentUserData() async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      final followingSnap = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('following')
          .get();

      if (!mounted) return;

      setState(() {
        _currentUserId = user.uid;
        _currentUserRole = userDoc.data()?['role'] as String? ?? 'client';
        _myFollowingIds = followingSnap.docs.map((d) => d.id).toList();
        _myFollowingIds.add(user.uid);
      });
    } catch (_) {
      // Hata durumunda sessizce devam et
    }
  }

  void _onSearchChanged() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 500), () {
      if (mounted && _searchCtrl.text != _lastSearchQuery) {
        setState(() {
          _lastSearchQuery = _searchCtrl.text;
        });
      }
    });
  }

  void _onExpertiseChanged() {
    _expertiseDebounceTimer?.cancel();
    _expertiseDebounceTimer = Timer(const Duration(milliseconds: 500), () {
      if (mounted && _expertiseCtrl.text != _lastExpertiseQuery) {
        setState(() {
          _lastExpertiseQuery = _expertiseCtrl.text;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scaffoldBg = isDark ? const Color(0xFF121212) : Colors.grey.shade50;
    final cardBg = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final borderColor = isDark ? Colors.grey.shade800 : Colors.grey.shade200;

    return Scaffold(
      backgroundColor: scaffoldBg,
      appBar: AppBar(
        title: const Text('Arama'),
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(
            color: borderColor,
            height: 1,
          ),
        ),
      ),
      body: Column(
        children: [
          // Arama ve Filtreler
          Container(
            color: cardBg,
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // Arama Kutusu
                TextField(
                  controller: _searchCtrl,
                  autofocus: true,
                  decoration: InputDecoration(
                    hintText: 'Kullanıcı, gönderi veya içerik ara...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchCtrl.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchCtrl.clear();
                              setState(() {
                                _lastSearchQuery = '';
                              });
                            },
                          )
                        : null,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: borderColor),
                    ),
                    filled: true,
                    fillColor: isDark ? Colors.grey.shade900 : Colors.grey.shade50,
                  ),
                ),
                const SizedBox(height: 12),
                // Hedef Seçimi
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    ChoiceChip(
                      label: const Text('Genel'),
                      selected: _searchTarget == SearchTarget.all,
                      selectedColor: Colors.deepPurple,
                      labelStyle: TextStyle(
                        color: _searchTarget == SearchTarget.all ? Colors.white : (isDark ? Colors.white : Colors.black),
                      ),
                      onSelected: (_) => setState(() => _searchTarget = SearchTarget.all),
                    ),
                    ChoiceChip(
                      label: const Text('Gönderi'),
                      selected: _searchTarget == SearchTarget.posts,
                      selectedColor: Colors.deepPurple,
                      labelStyle: TextStyle(
                        color: _searchTarget == SearchTarget.posts ? Colors.white : (isDark ? Colors.white : Colors.black),
                      ),
                      onSelected: (_) => setState(() => _searchTarget = SearchTarget.posts),
                    ),
                    ChoiceChip(
                      label: const Text('Kişi'),
                      selected: _searchTarget == SearchTarget.people,
                      selectedColor: Colors.deepPurple,
                      labelStyle: TextStyle(
                        color: _searchTarget == SearchTarget.people ? Colors.white : (isDark ? Colors.white : Colors.black),
                      ),
                      onSelected: (_) {
                        setState(() {
                          _searchTarget = SearchTarget.people;
                          _personKind = SearchPersonKind.any;
                          _selectedProfession = 'all';
                        });
                      },
                    ),
                  ],
                ),
                // Kişi Filtreleri
                if (_searchTarget == SearchTarget.people) ...[
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      FilterChip(
                        label: const Text('Hepsi'),
                        selected: _personKind == SearchPersonKind.any,
                        selectedColor: Colors.deepPurple,
                        checkmarkColor: Colors.white,
                        onSelected: (_) => setState(() => _personKind = SearchPersonKind.any),
                      ),
                      FilterChip(
                        label: const Text('Uzman'),
                        selected: _personKind == SearchPersonKind.expert,
                        selectedColor: Colors.deepPurple,
                        checkmarkColor: Colors.white,
                        onSelected: (_) => setState(() => _personKind = SearchPersonKind.expert),
                      ),
                      FilterChip(
                        label: const Text('Danışan'),
                        selected: _personKind == SearchPersonKind.client,
                        selectedColor: Colors.deepPurple,
                        checkmarkColor: Colors.white,
                        onSelected: (_) => setState(() => _personKind = SearchPersonKind.client),
                      ),
                    ],
                  ),
                  if (_personKind == SearchPersonKind.expert) ...[
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: _selectedProfession,
                      decoration: InputDecoration(
                        labelText: 'Meslek',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: borderColor),
                        ),
                        filled: true,
                        fillColor: isDark ? Colors.grey.shade900 : Colors.grey.shade50,
                      ),
                      items: [
                        const DropdownMenuItem(value: 'all', child: Text('Tüm meslekler')),
                        ..._professionList.map((p) => DropdownMenuItem(value: p, child: Text(p))),
                      ],
                      onChanged: (val) {
                        if (val != null) setState(() => _selectedProfession = val);
                      },
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _expertiseCtrl,
                      decoration: InputDecoration(
                        labelText: 'Uzmanlık alanı',
                        prefixIcon: const Icon(Icons.school),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: borderColor),
                        ),
                        filled: true,
                        fillColor: isDark ? Colors.grey.shade900 : Colors.grey.shade50,
                      ),
                    ),
                  ],
                ],
              ],
            ),
          ),
          // Sonuçlar
          Expanded(
            child: _buildResults(),
          ),
        ],
      ),
    );
  }

  Widget _buildResults() {
    final query = _lastSearchQuery.trim();
    final hasFilters = _personKind != SearchPersonKind.any || 
                       _selectedProfession != 'all' || 
                       _lastExpertiseQuery.isNotEmpty;
    
    // Kişi aramasında query boş olsa bile filtreler varsa sonuç göster
    if (_searchTarget == SearchTarget.people) {
      if (query.isEmpty && !hasFilters) {
        return _buildEmptyState('Arama yapmak için yukarıdaki kutuya yazın veya filtre seçin');
      }
      return _buildPeopleResults(query);
    }
    
    // Post veya Genel aramasında query gerekli
    if (query.isEmpty) {
      return _buildEmptyState('Arama yapmak için yukarıdaki kutuya yazın');
    }

    // "Genel" modunda hem post hem kişi sonuçlarını göster
    if (_searchTarget == SearchTarget.all) {
      return SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Gönderiler',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).brightness == Brightness.dark 
                      ? Colors.white 
                      : Colors.black87,
                ),
              ),
            ),
            _buildPostResults(query, showFullHeight: false),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Kişiler',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).brightness == Brightness.dark 
                      ? Colors.white 
                      : Colors.black87,
                ),
              ),
            ),
            _buildPeopleResults(query, showFullHeight: false),
          ],
        ),
      );
    } else if (_searchTarget == SearchTarget.posts) {
      return _buildPostResults(query);
    }

    return _buildEmptyState('Sonuç bulunamadı');
  }

  Widget _buildPostResults(String query, {bool showFullHeight = true}) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('posts')
          .where('isComment', isEqualTo: false)
          .where('deleted', isEqualTo: false)
          .orderBy('createdAt', descending: true)
          .limit(50)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData) {
          return _buildEmptyState('Sonuç bulunamadı');
        }

        final posts = snapshot.data!.docs
            .map((doc) => Post.fromFirestore(doc))
            .where((post) {
              final content = post.content.toLowerCase();
              return content.contains(query.toLowerCase());
            })
            .toList();

        if (posts.isEmpty) {
          return _buildEmptyState('"$query" için gönderi bulunamadı');
        }

        final listView = ListView.builder(
          shrinkWrap: !showFullHeight,
          physics: showFullHeight ? null : const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          itemCount: posts.length > 5 && !showFullHeight ? 5 : posts.length,
          itemBuilder: (context, index) {
            return PostCard(
              post: posts[index],
              myFollowingIds: _myFollowingIds,
              currentUserRole: _currentUserRole,
            );
          },
        );

        if (showFullHeight) {
          return listView;
        } else {
          return SizedBox(height: 400, child: listView);
        }
      },
    );
  }

  Widget _buildPeopleResults(String query, {bool showFullHeight = true}) {
    // StreamBuilder'ı filtre değişikliklerine duyarlı hale getirmek için
    // key kullanarak yeniden build etmeye zorluyoruz
    return StreamBuilder<QuerySnapshot>(
      key: ValueKey('people_${_personKind}_${_selectedProfession}_${_lastExpertiseQuery}'),
      stream: _buildPeopleQuery().limit(50).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData) {
          return _buildEmptyState('Sonuç bulunamadı');
        }

        final users = snapshot.data!.docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final name = (data['name'] ?? '').toString().toLowerCase();
          final username = (data['username'] ?? '').toString().toLowerCase();
          final specialties = (data['specialties'] ?? '').toString().toLowerCase();
          final queryLower = query.toLowerCase();
          
          // Uzmanlık alanı filtresi
          if (_lastExpertiseQuery.isNotEmpty && _personKind == SearchPersonKind.expert) {
            final expertise = _lastExpertiseQuery.toLowerCase();
            if (!specialties.contains(expertise)) {
              return false;
            }
          }
          
          return name.contains(queryLower) || 
                 username.contains(queryLower) ||
                 (queryLower.length >= 3 && specialties.contains(queryLower));
        }).toList();

        if (users.isEmpty) {
          final emptyMsg = query.isNotEmpty 
              ? '"$query" için kişi bulunamadı'
              : 'Filtrelere uygun kişi bulunamadı';
          return _buildEmptyState(emptyMsg);
        }

        final isDark = Theme.of(context).brightness == Brightness.dark;
        final cardBg = isDark ? const Color(0xFF1E1E1E) : Colors.white;
        final borderColor = isDark ? Colors.grey.shade800 : Colors.grey.shade200;

        final listView = ListView.builder(
          shrinkWrap: !showFullHeight,
          physics: showFullHeight ? null : const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          itemCount: users.length > 5 && !showFullHeight ? 5 : users.length,
          itemBuilder: (context, index) {
            final userDoc = users[index];
            final data = userDoc.data() as Map<String, dynamic>;
            final name = data['name'] ?? 'Kullanıcı';
            final username = data['username'] ?? '';
            final role = data['role'] ?? 'client';
            final profession = data['profession'] ?? '';
            final photoUrl = data['photoUrl'];
            final isExpert = role == 'expert' || role == 'admin';

            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              elevation: 0,
              color: cardBg,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: borderColor, width: 1),
              ),
              child: ListTile(
                leading: CircleAvatar(
                  radius: 24,
                  backgroundColor: isExpert
                      ? (isDark ? Colors.deepPurple.shade800 : Colors.deepPurple.shade50)
                      : (isDark ? Colors.grey.shade700 : Colors.grey.shade200),
                  backgroundImage: photoUrl != null && photoUrl.isNotEmpty
                      ? NetworkImage(photoUrl)
                      : null,
                  child: photoUrl == null || photoUrl.isEmpty
                      ? Text(
                          name.isNotEmpty ? name[0].toUpperCase() : '?',
                          style: TextStyle(
                            color: isExpert
                                ? (isDark ? Colors.deepPurple.shade200 : Colors.deepPurple)
                                : (isDark ? Colors.grey.shade300 : Colors.grey.shade700),
                            fontWeight: FontWeight.bold,
                          ),
                        )
                      : null,
                ),
                title: Text(
                  name,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (username.isNotEmpty)
                      Text(
                        '@$username',
                        style: TextStyle(
                          color: Colors.deepPurple,
                          fontSize: 12,
                        ),
                      ),
                    if (profession.isNotEmpty)
                      Text(
                        profession,
                        style: TextStyle(
                          color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                          fontSize: 12,
                        ),
                      ),
                  ],
                ),
                trailing: Icon(
                  Icons.chevron_right,
                  color: isDark ? Colors.grey.shade600 : Colors.grey.shade400,
                ),
                onTap: () {
                  if (_currentUserId == userDoc.id) {
                    Navigator.pushNamed(context, '/profile');
                  } else if (isExpert) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ExpertPublicProfileScreen(expertId: userDoc.id),
                      ),
                    );
                  } else {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => PublicClientProfileScreen(clientId: userDoc.id),
                      ),
                    );
                  }
                },
              ),
            );
          },
        );

        if (showFullHeight) {
          return listView;
        } else {
          return SizedBox(height: 400, child: listView);
        }
      },
    );
  }

  Query _buildPeopleQuery() {
    Query queryRef = FirebaseFirestore.instance.collection('users');

    // Role filtresi
    if (_personKind == SearchPersonKind.expert) {
      queryRef = queryRef.where('role', isEqualTo: 'expert');
    } else if (_personKind == SearchPersonKind.client) {
      queryRef = queryRef.where('role', isEqualTo: 'client');
    }

    // Meslek filtresi (sadece expert için)
    if (_personKind == SearchPersonKind.expert && _selectedProfession != 'all') {
      queryRef = queryRef.where('profession', isEqualTo: _selectedProfession);
    }

    return queryRef;
  }

  Widget _buildEmptyState(String message) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off,
              size: 64,
              color: isDark ? Colors.grey.shade600 : Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              message,
              style: TextStyle(
                fontSize: 16,
                color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

