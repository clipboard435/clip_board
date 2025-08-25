// lib/widgets/post_card.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class PostCard extends StatefulWidget {
  const PostCard({
    super.key,
    required this.postId,
    required this.images,
    required this.userName,
    required this.text,
    // いいね
    this.likedBy = const <String>[],
    this.likeCount = 0,
    // クリップ（お気に入り）
    this.clippedBy = const <String>[],
    this.clipCount = 0,
  });

  final String postId;
  final List<String> images;
  final String userName;
  final String text;

  final List<String> likedBy;
  final int likeCount;

  final List<String> clippedBy;
  final int clipCount;

  @override
  State<PostCard> createState() => _PostCardState();
}

class _PostCardState extends State<PostCard> {
  bool _expanded = false;
  int _commentLimit = 5;
  final _commentCtrl = TextEditingController();
  bool _busyLike = false;
  bool _busyClip = false;

  @override
  void dispose() {
    _commentCtrl.dispose();
    super.dispose();
  }

  Future<void> _toggleLike() async {
    if (_busyLike) return;
    _busyLike = true;

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('ログインしてください')));
      _busyLike = false;
      return;
    }

    final ref = FirebaseFirestore.instance.collection('posts').doc(widget.postId);
    try {
      await FirebaseFirestore.instance.runTransaction((tx) async {
        final snap = await tx.get(ref);
        if (!snap.exists) return;
        final data = snap.data() as Map<String, dynamic>;
        final List liked = (data['likedBy'] as List?)?.whereType<String>().toList() ?? [];
        final int count = (data['likeCount'] ?? 0) as int;

        if (liked.contains(uid)) {
          tx.update(ref, {
            'likedBy': FieldValue.arrayRemove([uid]),
            'likeCount': count > 0 ? count - 1 : 0,
          });
        } else {
          tx.update(ref, {
            'likedBy': FieldValue.arrayUnion([uid]),
            'likeCount': count + 1,
          });
        }
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('いいねに失敗しました: $e')),
      );
    } finally {
      _busyLike = false;
    }
  }

  Future<void> _toggleClip() async {
    if (_busyClip) return;
    _busyClip = true;

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('ログインしてください')));
      _busyClip = false;
      return;
    }

    final ref = FirebaseFirestore.instance.collection('posts').doc(widget.postId);
    try {
      await FirebaseFirestore.instance.runTransaction((tx) async {
        final snap = await tx.get(ref);
        if (!snap.exists) return;
        final data = snap.data() as Map<String, dynamic>;
        final List clipped = (data['clippedBy'] as List?)?.whereType<String>().toList() ?? [];
        final int count = (data['clipCount'] ?? 0) as int;

        if (clipped.contains(uid)) {
          tx.update(ref, {
            'clippedBy': FieldValue.arrayRemove([uid]),
            'clipCount': count > 0 ? count - 1 : 0,
          });
        } else {
          tx.update(ref, {
            'clippedBy': FieldValue.arrayUnion([uid]),
            'clipCount': count + 1,
          });
        }
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('クリップに失敗しました: $e')),
      );
    } finally {
      _busyClip = false;
    }
  }

  Future<void> _addComment() async {
    final user = FirebaseAuth.instance.currentUser;
    final text = _commentCtrl.text.trim();
    if (user == null || text.isEmpty) return;

    try {
      await FirebaseFirestore.instance
          .collection('posts')
          .doc(widget.postId)
          .collection('comments')
          .add({
        'text': text,
        'userId': user.uid,
        'userName': user.displayName ?? user.email ?? 'ユーザー',
        'createdAt': FieldValue.serverTimestamp(),
      });
      _commentCtrl.clear();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('コメントに失敗しました: $e')),
      );
    }
  }

  void _onTapCart() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('カートに追加（ダミー）')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final images =
        (widget.images as List?)?.whereType<String>().map((s) => s.trim()).toList() ?? <String>[];
    final isLiked = uid != null && widget.likedBy.contains(uid);
    final isClipped = uid != null && widget.clippedBy.contains(uid);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 画像（複数ならスワイプ）
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: images.isEmpty
                ? Container(
                    height: 280,
                    color: Colors.black12,
                    alignment: Alignment.center,
                    child: const Text('画像なし'),
                  )
                : _ImagesPager(urls: images),
          ),
          const SizedBox(height: 8),

          // ユーザー名＋アクション（🛒 / ♡ / 📎）
          Row(
            children: [
              const CircleAvatar(radius: 12, child: Icon(Icons.person, size: 14)),
              const SizedBox(width: 8),
              Expanded(child: Text(widget.userName, style: theme.textTheme.bodyMedium)),

              // 🛒
              IconButton(
                onPressed: _onTapCart,
                icon: const Icon(Icons.shopping_cart_outlined),
                tooltip: 'カートに追加',
              ),

              // ♡（いいね数のみ）
              Row(
                children: [
                  IconButton(
                    onPressed: _toggleLike,
                    icon: Icon(isLiked ? Icons.favorite : Icons.favorite_border,
                        color: isLiked ? Colors.red : null),
                    tooltip: isLiked ? 'いいね解除' : 'いいね',
                  ),
                  Text('${widget.likeCount}'),
                ],
              ),

              // 📎（Favorites 用）
              Row(
                children: [
                  IconButton(
                    onPressed: _toggleClip,
                    icon: Icon(isClipped ? Icons.bookmark : Icons.bookmark_border,
                        color: isClipped ? Colors.blue : null),
                    tooltip: isClipped ? 'クリップ解除' : 'クリップ',
                  ),
                  Text('${widget.clipCount}'),
                ],
              ),
            ],
          ),

          // 本文（2行まで）＋「続きを読む」
          if (widget.text.isNotEmpty) ...[
            const SizedBox(height: 4),
            if (!_expanded)
              Text(
                widget.text,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium,
              ),
            TextButton(
              style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: Size.zero),
              onPressed: () => setState(() => _expanded = !_expanded),
              child: Text(_expanded ? '閉じる' : '続きを読む',
                  style: const TextStyle(decoration: TextDecoration.underline)),
            ),
          ],

          // 展開部：本文全文＋コメント一覧＋コメント入力
          if (_expanded) ...[
            if (widget.text.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(widget.text, style: const TextStyle(fontSize: 15, height: 1.5)),
              ),

            Padding(
              padding: const EdgeInsets.only(top: 4, bottom: 4),
              child: Row(
                children: const [
                  Expanded(child: Divider()),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8),
                    child: Text('コメント', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                  Expanded(child: Divider()),
                ],
              ),
            ),

            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('posts')
                  .doc(widget.postId)
                  .collection('comments')
                  .orderBy('createdAt', descending: true)
                  .limit(_commentLimit)
                  .snapshots(),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                final docs = snap.data?.docs ?? [];
                if (docs.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 4),
                    child: Text('最初のコメントを書いてみよう！'),
                  );
                }
                return Column(
                  children: [
                    ...docs.map((d) {
                      final c = d.data() as Map<String, dynamic>;
                      final name = (c['userName'] ?? 'ユーザー').toString();
                      final text = (c['text'] ?? '').toString();
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const CircleAvatar(radius: 12, child: Icon(Icons.person, size: 14)),
                            const SizedBox(width: 8),
                            Expanded(
                              child: RichText(
                                text: TextSpan(
                                  style: Theme.of(context).textTheme.bodyMedium,
                                  children: [
                                    TextSpan(
                                      text: '$name  ',
                                      style: const TextStyle(fontWeight: FontWeight.w600),
                                    ),
                                    TextSpan(text: text),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                    if ((snap.data?.size ?? 0) >= _commentLimit)
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton(
                          onPressed: () => setState(() => _commentLimit += 10),
                          child: const Text('さらに表示'),
                        ),
                      ),
                  ],
                );
              },
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _commentCtrl,
                    decoration: const InputDecoration(
                      hintText: 'コメントを追加…',
                      isDense: true,
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(onPressed: _addComment, icon: const Icon(Icons.send)),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// 画像ページャ（複数画像をスワイプ・ドットで表示 / 画像は全体が見える）
class _ImagesPager extends StatefulWidget {
  const _ImagesPager({required this.urls});
  final List<String> urls;

  @override
  State<_ImagesPager> createState() => _ImagesPagerState();
}

class _ImagesPagerState extends State<_ImagesPager> {
  final _pc = PageController();
  var _index = 0;

  @override
  void dispose() {
    _pc.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.bottomCenter,
      children: [
        SizedBox(
          height: 360,
          width: double.infinity,
          child: PageView.builder(
            controller: _pc,
            itemCount: widget.urls.length,
            onPageChanged: (i) => setState(() => _index = i),
            itemBuilder: (_, i) => FittedBox(
              fit: BoxFit.contain, // 画像全体が見える
              child: Image.network(
                widget.urls[i],
                gaplessPlayback: true,
                errorBuilder: (_, __, ___) => const Icon(Icons.broken_image, size: 48),
                loadingBuilder: (c, w, p) =>
                    p == null ? w : const SizedBox(height: 200, child: Center(child: CircularProgressIndicator())),
              ),
            ),
          ),
        ),
        if (widget.urls.length > 1)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Wrap(
              spacing: 6,
              children: List.generate(
                widget.urls.length,
                (i) => Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: i == _index ? Colors.white : Colors.white54,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}