import 'package:flutter/material.dart';

class PostCreateScreen extends StatefulWidget {
  const PostCreateScreen({super.key});

  @override
  State<PostCreateScreen> createState() => _PostCreateScreenState();
}

class _PostCreateScreenState extends State<PostCreateScreen> {
  final _textCtrl = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _textCtrl.dispose();
    super.dispose();
  }

  Future<void> _fakeSend() async {
    if (_textCtrl.text.trim().isEmpty) return;

    setState(() => _sending = true);
    await Future.delayed(const Duration(seconds: 1)); // sadece efekt
    setState(() => _sending = false);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Paylaşım taslak olarak kaydedilmiş varsayalım 🙂 (gerçek kayıt daha sonra eklenecek).',
        ),
      ),
    );

    _textCtrl.clear();
    Navigator.pop(context); // geri dön
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Paylaşım Oluştur'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Metin',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _textCtrl,
              maxLines: 5,
              decoration: const InputDecoration(
                hintText: 'Danışanlar / uzmanlar için metin paylaş...',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),

            // Şimdilik sadece görünüş için
            const Text(
              'Medya (şimdilik pasif)',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                OutlinedButton.icon(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Fotoğraf ekleme özelliği daha sonra eklenecek.',
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.photo),
                  label: const Text('Fotoğraf'),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Video ekleme özelliği daha sonra eklenecek.',
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.videocam),
                  label: const Text('Video'),
                ),
              ],
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _sending ? null : _fakeSend,
                child: _sending
                    ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
                    : const Text('Paylaş'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
