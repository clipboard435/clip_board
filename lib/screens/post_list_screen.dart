import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class PostListScreen extends StatelessWidget {
  const PostListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('CLiP Board')),
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
            return const Center(child: Text('投稿はまだありません'));
          }
          final docs = snap.data!.docs;
          return ListView.builder(
            itemCount: docs.length,
            itemBuilder: (context, i) {
              final data = docs[i].data() as Map<String, dynamic>;
              final images = List<String>.from(data['images'] ?? const []);
              final userName = (data['userName'] ?? 'No Name').toString();
              final text = (data['text'] ?? '').toString();
              final genre = (data['genre'] ?? '').toString();
              final address = (data['address'] ?? '').toString();

              return PostCard(
                images: images,
                userName: userName,
                text: text,
                genre: genre,
                address: address,
              );
            },
          );
        },
      ),
    );
  }
}

class PostCard extends StatefulWidget {
  const PostCard({
    super.key,
    required this.images,
    required this.userName,
    required this.text,
    required this.genre,
    required this.address,
  });

  final List<String> images;
  final String userName;
  final String text;
  final String genre;
  final String address;

  @override
  State<PostCard> createState() => _PostCardState();
}

class _PostCardState extends State<PostCard> {
  final _page = PageController();
  int _index = 0;

  @override
  void dispose() {
    _page.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.all(8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.images.isNotEmpty)
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
              child: Stack(
                alignment: Alignment.bottomCenter,
                children: [
                  AspectRatio(
                    aspectRatio: 4 / 3,
                    child: PageView.builder(
                      controller: _page,
                      itemCount: widget.images.length,
                      onPageChanged: (i) => setState(() => _index = i),
                      itemBuilder: (_, i) => Image.network(
                        widget.images[i],
                        fit: BoxFit.cover,
                        width: double.infinity,
                        loadingBuilder: (c, w, p) =>
                            p == null ? w : const Center(child: CircularProgressIndicator()),
                        errorBuilder: (_, __, ___) =>
                            Container(color: Colors.black12, child: const Icon(Icons.broken_image)),
                      ),
                    ),
                  ),
                  if (widget.images.length > 1)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(
                          widget.images.length,
                          (i) => Container(
                            width: 8,
                            height: 8,
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: i == _index ? Colors.white : Colors.white70,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),

          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                const CircleAvatar(child: Icon(Icons.person, size: 16)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(widget.userName,
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                ),
                IconButton(onPressed: () {}, icon: const Icon(Icons.shopping_cart_outlined)),
                IconButton(onPressed: () {}, icon: const Icon(Icons.favorite_border)),
                IconButton(onPressed: () {}, icon: const Icon(Icons.attach_file)),
              ],
            ),
          ),

          if (widget.text.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12.0),
              child: Text(widget.text, style: theme.textTheme.bodyMedium),
            ),

          const SizedBox(height: 4),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8),
            child: Row(
              children: [
                Text('ジャンル: ${widget.genre}',
                    style: const TextStyle(color: Colors.grey, fontSize: 12)),
                const SizedBox(width: 16),
                Expanded(
                  child: Text('住所: ${widget.address}',
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.grey, fontSize: 12)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}