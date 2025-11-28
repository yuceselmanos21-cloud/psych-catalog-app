import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class FeedScreen extends StatefulWidget {
  const FeedScreen({super.key});

  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> {
  String? _role;
  String? _name;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (mounted) {
        Navigator.pushReplacementNamed(context, '/login');
      }
      return;
    }

    try {
      final snap = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      final data = snap.data();
      setState(() {
        _role = data?['role'] ?? 'client';
        _name = data?['name'] ?? 'Kullanıcı';
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _role = 'client';
        _name = 'Kullanıcı';
        _loading = false;
      });
    }
  }

  Future<void> _logout() async {
    await FirebaseAuth.instance.signOut();
    if (!mounted) return;
    Navigator.pushReplacementNamed(context, '/login');
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final isExpert = _role == 'expert';

    return Scaffold(
      appBar: AppBar(
        title: Text('Hoş geldin, ${_name ?? ''}'),
        actions: [
          IconButton(
            onPressed: () {
              Navigator.pushNamed(context, '/profile');
            },
            icon: const Icon(Icons.person),
            tooltip: 'Profilim',
          ),
          IconButton(
            onPressed: _logout,
            icon: const Icon(Icons.logout),
            tooltip: 'Çıkış yap',
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: isExpert ? _buildExpertView() : _buildClientView(),
      ),
    );
  }

  // ------------------ UZMAN PANELİ ------------------
  Widget _buildExpertView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Uzman Paneli",
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        const Text(
          "Buradan test oluşturabilir, danışanlara yönelik içerik paylaşabilir "
              "ve oluşturduğunuz testleri yönetebilirsiniz.",
        ),
        const SizedBox(height: 24),

        // Test Oluştur
        ElevatedButton.icon(
          onPressed: () {
            Navigator.pushNamed(context, '/createTest');
          },
          icon: const Icon(Icons.note_add),
          label: const Text("Test Oluştur"),
          style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 48)),
        ),
        const SizedBox(height: 12),

        // OLUŞTURDUĞUM TESTLER – YENİ BUTON
        ElevatedButton.icon(
          onPressed: () {
            Navigator.pushNamed(context, '/expertTests');
          },
          icon: const Icon(Icons.folder_open),
          label: const Text("Oluşturduğum Testler"),
          style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 48)),
        ),
      ],
    );
  }

  // ------------------ DANIŞAN PANELİ ------------------
  Widget _buildClientView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Danışan Paneli",
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        const Text(
          "Buradan uzmanların oluşturduğu testleri çözebilir ve yapay zeka "
              "analizlerinizi görüntüleyebilirsiniz.",
        ),
        const SizedBox(height: 24),

        // Testleri Gör
        ElevatedButton.icon(
          onPressed: () {
            Navigator.pushNamed(context, '/tests');
          },
          icon: const Icon(Icons.list),
          label: const Text("Tüm Testleri Gör"),
          style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 48)),
        ),
      ],
    );
  }
}
