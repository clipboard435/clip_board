// lib/screens/favorites_screen.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../widgets/post_card.dart';

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
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final docs = snap.data?.docs ?? [];
          if (docs.isEmpty) {
            return const Center(child: Text('まだ「いいね」した投稿がありません'));
          }
          return ListView.separated(
            padding: const EdgeInsets.only(bottom: 24),
            itemCount: docs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 16),
            itemBuilder: (context, i) {
              final doc = docs[i];
              final data = doc.data() as Map<String, dynamic>;
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
              final likedBy =
                  (data['likedBy'] as List?)?.whereType<String>().toList() ?? <String>[];
              final likeCount = (data['likeCount'] ?? 0) as int;

              return PostCard(
                key: ValueKey(doc.id),
                postId: doc.id,
                images: images,
                userName: userName,
                text: text,
                likedBy: likedBy,
                likeCount: likeCount,
              );
            },
          );
        },
      ),
    );
  }
}