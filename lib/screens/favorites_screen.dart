// lib/screens/favorites_screen.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../widgets/post_card.dart'; // ← 詳細表示に使う（オプション）

class FavoritesScreen extends StatelessWidget {
  const FavoritesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      return const Scaffold(
        body: Center(child: Text('ログインしてください')),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('お気に入り')),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('posts')
            .where('likedBy', arrayContains: uid)
            // ↓ インデックスがまだ無ければこの行はコメントアウトし、クライアントソートに切替可
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          var docs = snap.data?.docs ?? [];

          // orderBy を外している場合はクライアント側で降順ソート
          // docs.sort((a, b) {
          //   final am = (a.data() as Map<String, dynamic>)['createdAt'];
          //   final bm = (b.data() as Map<String, dynamic>)['createdAt'];
          //   final at = (am is Timestamp) ? am.toDate() : DateTime.fromMillisecondsSinceEpoch(0);
          //   final bt = (bm is Timestamp) ? bm.toDate() : DateTime.fromMillisecondsSinceEpoch(0);
          //   return bt.compareTo(at);
          // });

          if (docs.isEmpty) {
            return const Center(child: Text('まだ「いいね」した投稿がありません'));
          }

          return GridView.builder(
            padding: const EdgeInsets.all(8),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,          // ← 2列
              crossAxisSpacing: 6,
              mainAxisSpacing: 6,
              childAspectRatio: 1,        // ← 正方形サムネ
            ),
            itemCount: docs.length,
            itemBuilder: (context, i) {
              final doc  = docs[i];
              final data = doc.data() as Map<String, dynamic>;

              // 1枚目の画像をサムネにする（旧 imageUrl にも対応）
              final images = (data['images'] as List?)
                      ?.whereType<String>()
                      .map((s) => s.trim())
                      .toList() ??
                  <String>[];
              if (images.isEmpty && (data['imageUrl'] ?? '').toString().isNotEmpty) {
                images.add((data['imageUrl'] as String).trim());
              }
              final thumbUrl = images.isNotEmpty ? images.first : null;

              // いいね情報（詳細遷移で使うことがある）
              final userName  = (data['userName'] ?? 'ユーザー').toString();
              final text      = (data['text'] ?? '').toString();
              final likeCount = (data['likeCount'] ?? 0) as int;
              final likedBy   =
                  (data['likedBy'] as List?)?.whereType<String>().toList() ?? <String>[];

              return _FavoriteGridTile(
                imageUrl: thumbUrl,
                onTap: () {
                  // オプション：グリッドタップで詳細（PostCard単体）をダイアログ表示
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
                                // PostCard を1件分だけ表示
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 24),
                                  child: PostCard(
                                    key: ValueKey(doc.id),
                                    postId: doc.id,
                                    images: images,
                                    userName: userName,
                                    text: text,
                                    likedBy: likedBy,
                                    likeCount: likeCount,
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

/// グリッドサムネ用のタイル（正方形・角丸・カバー表示）
class _FavoriteGridTile extends StatelessWidget {
  const _FavoriteGridTile({
    required this.imageUrl,
    required this.onTap,
  });

  final String? imageUrl;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    Widget child;
    if (imageUrl == null || imageUrl!.isEmpty) {
      child = const Center(child: Icon(Icons.image_not_supported));
    } else {
      child = Image.network(
        imageUrl!,
        fit: BoxFit.cover, // 正方形タイルを埋める
        errorBuilder: (_, __, ___) => const Center(child: Icon(Icons.broken_image)),
        loadingBuilder: (c, w, p) => p == null ? w : const Center(child: CircularProgressIndicator()),
      );
    }

    return InkWell(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: AspectRatio(
          aspectRatio: 1, // 正方形
          child: child,
        ),
      ),
    );
    }
}