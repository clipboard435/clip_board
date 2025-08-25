// lib/screens/favorites_screen.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../widgets/post_card.dart';

class FavoritesScreen extends StatelessWidget {
  const FavoritesScreen({super.key, this.columns = 3});

  final int columns; // 2 or 3 を渡せます

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      return const Scaffold(body: Center(child: Text('ログインしてください')));
    }

    return Scaffold(
      appBar: AppBar(title: const Text('お気に入り（クリップ）')),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('posts')
            .where('clippedBy', arrayContains: uid)
            .orderBy('createdAt', descending: true) // インデックス必要
            .snapshots(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final docs = snap.data?.docs ?? [];
          if (docs.isEmpty) {
            return const Center(child: Text('まだクリップした投稿がありません'));
          }

          return GridView.builder(
            padding: const EdgeInsets.all(8),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: columns,     // 2 or 3
              crossAxisSpacing: 6,
              mainAxisSpacing: 6,
              childAspectRatio: 1,         // 正方形
            ),
            itemCount: docs.length,
            itemBuilder: (context, i) {
              final doc  = docs[i];
              final data = doc.data() as Map<String, dynamic>;

              final images = (data['images'] as List?)
                      ?.whereType<String>()
                      .map((s) => s.trim())
                      .toList() ??
                  <String>[];
              if (images.isEmpty && (data['imageUrl'] ?? '').toString().isNotEmpty) {
                images.add((data['imageUrl'] as String).trim());
              }
              final thumb = images.isNotEmpty ? images.first : null;

              return _ThumbTile(
                imageUrl: thumb,
                onTap: () {
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (_) {
                      return DraggableScrollableSheet(
                        initialChildSize: 0.9,
                        minChildSize: 0.5,
                        maxChildSize: 0.95,
                        builder: (context, controller) {
                          return Container(
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                            ),
                            padding: const EdgeInsets.only(top: 8),
                            child: ListView(
                              controller: controller,
                              children: [
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                  child: Text('投稿詳細', style: Theme.of(context).textTheme.titleMedium),
                                ),
                                const Divider(height: 1),
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 24),
                                  child: PostCard(
                                    key: ValueKey(doc.id),
                                    postId: doc.id,
                                    images: images,
                                    userName: (data['userName'] ?? 'ユーザー').toString(),
                                    text: (data['text'] ?? '').toString(),
                                    likedBy: (data['likedBy'] as List?)?.whereType<String>().toList() ?? <String>[],
                                    likeCount: (data['likeCount'] ?? 0) as int,
                                    clippedBy: (data['clippedBy'] as List?)?.whereType<String>().toList() ?? <String>[],
                                    clipCount: (data['clipCount'] ?? 0) as int,
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      );
                    },
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}

class _ThumbTile extends StatelessWidget {
  const _ThumbTile({required this.imageUrl, required this.onTap});
  final String? imageUrl;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final child = (imageUrl == null || imageUrl!.isEmpty)
        ? const Center(child: Icon(Icons.image_not_supported))
        : Image.network(
            imageUrl!,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => const Center(child: Icon(Icons.broken_image)),
            loadingBuilder: (c, w, p) =>
                p == null ? w : const Center(child: CircularProgressIndicator()),
          );

    return InkWell(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: AspectRatio(aspectRatio: 1, child: child),
      ),
    );
  }
}