// lib/screens/post_list_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../widgets/post_card.dart';      // ← 分離した PostCard / AutoSizedNetworkImage
import 'post_editor_screen.dart';        // ← 投稿画面
import 'favorites_screen.dart';          // ← お気に入り一覧（自分がいいねした投稿）

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
        builder: (context, snapshot) {
          // ローディング
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          // データなし
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('まだ投稿がありません'));
          }

          final docs = snapshot.data!.docs;

          return ListView.separated(
            padding: const EdgeInsets.only(bottom: 88),
            itemCount: docs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 16),
            itemBuilder: (context, index) {
              final doc  = docs[index];
              final data = doc.data() as Map<String, dynamic>;

              // 画像（images配列 or 旧imageUrlを吸収）
              final images = (data['images'] as List?)
                      ?.whereType<String>()
                      .map((s) => s.trim())
                      .toList() ??
                  <String>[];
              if (images.isEmpty && (data['imageUrl'] ?? '').toString().isNotEmpty) {
                images.add((data['imageUrl'] as String).trim());
              }

              final userName  = (data['userName'] ?? 'ユーザー').toString();
              final text      = (data['text'] ?? '').toString();
              final likeCount = (data['likeCount'] ?? 0) as int;
              final likedBy   =
                  (data['likedBy'] as List?)?.whereType<String>().toList() ?? <String>[];

              return PostCard(
                key: ValueKey(doc.id),
                postId: doc.id,
                images: images,
                userName: userName,
                text: text,
                likeCount: likeCount,
                likedBy: likedBy,
              );
            },
          );
        },
      ),

      // 下タブ：投稿ボタン→投稿画面 / お気に入り→自分がいいねした投稿
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: 0,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'ホーム'),
          BottomNavigationBarItem(icon: Icon(Icons.search), label: '検索'),
          BottomNavigationBarItem(icon: Icon(Icons.add_box_outlined), label: '投稿'),
          BottomNavigationBarItem(icon: Icon(Icons.bookmark_border), label: 'お気に入り'),
          BottomNavigationBarItem(icon: Icon(Icons.person_outline), label: 'アカウント'),
        ],
        onTap: (index) {
          if (index == 2) {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const PostEditorScreen()),
            );
          } else if (index == 3) {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const FavoritesScreen()),
            );
          }
        },
      ),
    );
  }
}