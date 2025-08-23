// lib/screens/post_list_screen.dart
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;

import 'post_editor_screen.dart';

/// URLをHTTPで直接ダウンロードして表示（SDKを通さない）
class HttpImage extends StatefulWidget {
  final String url;
  final double? width, height;
  final BoxFit fit;
  const HttpImage(this.url, {this.width, this.height, this.fit = BoxFit.cover, super.key});

  @override
  State<HttpImage> createState() => _HttpImageState();
}

class _HttpImageState extends State<HttpImage> {
  Uint8List? _bytes;
  Object? _err;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final uri = Uri.parse(widget.url.trim());
      final res = await http.get(uri);
      if (!mounted) return;
      if (res.statusCode == 200) {
        setState(() => _bytes = res.bodyBytes);
      } else {
        setState(() => _err = 'HTTP ${res.statusCode}');
        debugPrint('HttpImage error: ${res.statusCode} ${widget.url}');
      }
    } catch (e) {
      if (!mounted) return;
      _err = e;
      setState(() {});
      debugPrint('HttpImage exception: $e url=${widget.url}');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_err != null) {
      return const ColoredBox(
        color: Color(0x11000000),
        child: Center(child: Icon(Icons.broken_image)),
      );
    }
    if (_bytes == null) {
      return const Center(child: CircularProgressIndicator());
    }
    return Image.memory(_bytes!, width: widget.width, height: widget.height, fit: widget.fit);
  }
}

class PostListScreen extends StatelessWidget {
  const PostListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('CLiP Board'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => FirebaseAuth.instance.signOut(),
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('posts')
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snap.hasData || snap.data!.docs.isEmpty) {
            return const Center(child: Text('まだ投稿がありません'));
          }

          final docs = snap.data!.docs;
          return ListView.separated(
            padding: const EdgeInsets.only(bottom: 88),
            itemCount: docs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 16),
            itemBuilder: (context, i) {
              final data = docs[i].data() as Map<String, dynamic>;

              // images(List<String>) or 旧imageUrl(String)に対応
              final images = (data['images'] as List?)
                      ?.whereType<String>()
                      .map((s) => s.trim())
                      .toList() ??
                  <String>[];
              if (images.isEmpty && (data['imageUrl'] ?? '').toString().isNotEmpty) {
                images.add((data['imageUrl'] as String).trim());
              }

              final userName = (data['userName'] ?? 'ユーザー').toString();
              final text = (data['text'] ?? '').toString();

              return PostCard(images: images, userName: userName, text: text);
            },
          );
        },
      ),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'ホーム'),
          BottomNavigationBarItem(icon: Icon(Icons.search), label: '検索'),
          BottomNavigationBarItem(icon: Icon(Icons.add_box_outlined), label: '投稿'),
          BottomNavigationBarItem(icon: Icon(Icons.bookmark_border), label: 'お気に入り'),
          BottomNavigationBarItem(icon: Icon(Icons.person_outline), label: 'アカウント'),
        ],
        currentIndex: 0,
        onTap: (index) {
          if (index == 2) {
            Navigator.push(context, MaterialPageRoute(builder: (_) => const PostEditorScreen()));
          }
        },
      ),
    );
  }
}

/// 1件分の投稿カード（先頭1枚、固定高さ）
class PostCard extends StatelessWidget {
  const PostCard({
    super.key,
    required this.images,
    required this.userName,
    required this.text,
  });

  final List<String> images;
  final String userName;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final safeImages =
        (images as List?)?.whereType<String>().map((s) => s.trim()).toList() ?? <String>[];
    final firstUrl = safeImages.isNotEmpty ? safeImages.first : null;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(
              height: 240,
              width: double.infinity,
              child: firstUrl == null
                  ? Container(
                      color: Colors.black12,
                      alignment: Alignment.center,
                      child: const Text('画像なし'),
                    )
                  : HttpImage(firstUrl, height: 240, fit: BoxFit.cover),
            ),
          ),
          const SizedBox(height: 8),

          Row(
            children: [
              const CircleAvatar(radius: 12, child: Icon(Icons.person, size: 14)),
              const SizedBox(width: 8),
              Expanded(child: Text(userName, style: theme.textTheme.bodyMedium)),
              IconButton(onPressed: () {}, icon: const Icon(Icons.shopping_cart_outlined)),
              IconButton(onPressed: () {}, icon: const Icon(Icons.favorite_border)),
              IconButton(onPressed: () {}, icon: const Icon(Icons.attach_file)),
            ],
          ),

          if (text.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              text,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyMedium,
            ),
            TextButton(
              style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: Size.zero),
              onPressed: () {},
              child: const Text('続きを読む', style: TextStyle(decoration: TextDecoration.underline)),
            ),
          ],
        ],
      ),
    );
  }
}