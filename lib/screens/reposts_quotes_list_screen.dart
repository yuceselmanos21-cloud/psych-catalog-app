import 'package:flutter/material.dart';
import '../repositories/firestore_post_repository.dart';
import '../models/post_model.dart';
import '../widgets/post_card.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class RepostsQuotesListScreen extends StatefulWidget {
  final String postId;
  const RepostsQuotesListScreen({super.key, required this.postId});

  @override
  State<RepostsQuotesListScreen> createState() => _RepostsQuotesListScreenState();
}

class _RepostsQuotesListScreenState extends State<RepostsQuotesListScreen> {
  final FirestorePostRepository _postRepo = FirestorePostRepository.instance;
  List<Post> _posts = [];
  bool _loading = false;
  bool _hasMore = true;
  DocumentSnapshot? _lastDoc;

  @override
  void initState() {
    super.initState();
    _loadPosts();
  }

  Future<void> _loadPosts() async {
    if (_loading || !_hasMore) return;
    setState(() => _loading = true);
    try {
      final newPosts = await _postRepo.getRepostsForPost(widget.postId, lastDoc: _lastDoc);
      if (newPosts.isEmpty) {
        setState(() => _hasMore = false);
      } else {
        setState(() {
          _posts.addAll(newPosts);
          _lastDoc = newPosts.last.docSnapshot;
        });
      }
    } catch (e) {
      print('⚠️ Repost/Quote yükleme hatası: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Repostlar ve Alıntılar'),
      ),
      body: _posts.isEmpty && !_loading
          ? const Center(child: Text('Henüz repost veya alıntı yok'))
          : ListView.builder(
              itemCount: _posts.length + (_hasMore ? 1 : 0),
              itemBuilder: (context, index) {
                if (index == _posts.length) {
                  _loadPosts();
                  return const Center(child: Padding(
                    padding: EdgeInsets.all(16.0),
                    child: CircularProgressIndicator(),
                  ));
                }
                return PostCard(
                  post: _posts[index],
                  myFollowingIds: const [], // Repost/quote listesinde following bilgisi gerekli değil
                  currentUserRole: null, // PostCard içinde kendi rolünü kontrol eder
                );
              },
            ),
    );
  }
}

