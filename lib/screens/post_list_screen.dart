// lib/screens/post_list_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../widgets/post_card.dart';
import 'post_editor_screen.dart';
import 'favorites_screen.dart';

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

              return PostCard(
                key: ValueKey(doc.id),
                postId: doc.id,
                images: images,
                userName: (data['userName'] ?? 'ユーザー').toString(),
                text: (data['text'] ?? '').toString(),
                likedBy: (data['likedBy'] as List?)?.whereType<String>().toList() ?? <String>[],
                likeCount: (data['likeCount'] ?? 0) as int,
                clippedBy: (data['clippedBy'] as List?)?.whereType<String>().toList() ?? <String>[],
                clipCount: (data['clipCount'] ?? 0) as int,
              );
            },
          );
        },
      ),
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
            Navigator.push(context, MaterialPageRoute(builder: (_) => const PostEditorScreen()));
          } else if (index == 3) {
            Navigator.push(context, MaterialPageRoute(builder: (_) => const FavoritesScreen(columns: 3)));
          }
        },
      ),
    );
  }
}