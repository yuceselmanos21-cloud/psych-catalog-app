import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../utils/mention_parser.dart';

/// Mention'ları mor renkte ve tıklanabilir gösteren widget
class MentionText extends StatelessWidget {
  final String text;
  final TextStyle? style;
  final Function(String userId)? onMentionTap;

  const MentionText({
    super.key,
    required this.text,
    this.style,
    this.onMentionTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final defaultStyle = style ?? TextStyle(
      fontSize: 15,
      color: isDark ? Colors.grey.shade200 : Colors.black87,
      height: 1.4,
    );

    // Mention'ları parse et
    final mentions = MentionParser.extractMentions(text);
    
    if (mentions.isEmpty) {
      // Mention yoksa normal text göster
      return Text(text, style: defaultStyle);
    }

    // TextSpan'ler oluştur
    final spans = <TextSpan>[];
    int lastIndex = 0;

    // Regex ile mention'ları bul
    final regex = RegExp(r'@(\w+)');
    final matches = regex.allMatches(text);

    for (final match in matches) {
      // Mention'dan önceki normal metin
      if (match.start > lastIndex) {
        spans.add(TextSpan(
          text: text.substring(lastIndex, match.start),
          style: defaultStyle,
        ));
      }

      // Mention (mor renkte ve tıklanabilir)
      final mentionText = match.group(0) ?? '';
      final username = match.group(1) ?? '';
      
      spans.add(TextSpan(
        text: mentionText,
        style: defaultStyle?.copyWith(
          color: Colors.deepPurple,
          fontWeight: FontWeight.w600,
        ) ?? TextStyle(
          color: Colors.deepPurple,
          fontWeight: FontWeight.w600,
        ),
        recognizer: onMentionTap != null
            ? (TapGestureRecognizer()..onTap = () => _handleMentionTap(context, username, onMentionTap!))
            : null,
      ));

      lastIndex = match.end;
    }

    // Kalan metin
    if (lastIndex < text.length) {
      spans.add(TextSpan(
        text: text.substring(lastIndex),
        style: defaultStyle,
      ));
    }

    return RichText(
      text: TextSpan(children: spans),
    );
  }

  /// Mention'a tıklandığında username'den userId'ye çevir ve callback'i çağır
  Future<void> _handleMentionTap(
    BuildContext context,
    String username,
    Function(String userId) callback,
  ) async {
    try {
      final query = await FirebaseFirestore.instance
          .collection('users')
          .where('username', isEqualTo: username)
          .limit(1)
          .get();

      if (query.docs.isNotEmpty) {
        final userId = query.docs.first.id;
        callback(userId);
      } else {
        // Kullanıcı bulunamadı
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('@$username kullanıcısı bulunamadı')),
          );
        }
      }
    } catch (e) {
      // Hata durumunda sessizce geç
      debugPrint('Mention tap error: $e');
    }
  }
}

