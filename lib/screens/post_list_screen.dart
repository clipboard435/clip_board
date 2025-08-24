// lib/screens/post_list_screen.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'post_editor_screen.dart';

/// 画像の実寸（width/height）から比率を解決し、
/// カード幅に合わせて自然な高さで表示（トリミング無し BoxFit.contain）。
class AutoSizedNetworkImage extends StatefulWidget {
  final String url;
  final double maxHeight; // 縦長でもダラっと長くなりすぎないようにする上限
  final BoxFit fit;

  const AutoSizedNetworkImage({
    super.key,
    required this.url,
    this.maxHeight = 360,
    this.fit = BoxFit.contain,
  });

  @override
  State<AutoSizedNetworkImage> createState() => _AutoSizedNetworkImageState();
}

class _AutoSizedNetworkImageState extends State<AutoSizedNetworkImage> {
  double? _aspect; // width / height（未解決の間は null）
  ImageStream? _stream;
  ImageStreamListener? _listener;

  @override
  void initState() {
    super.initState();
    _resolveImage();
  }

  @override
  void didUpdateWidget(covariant AutoSizedNetworkImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url) {
      _aspect = null;
      _unsubscribe();
      _resolveImage();
    }
  }

  @override
  void dispose() {
    _unsubscribe();
    super.dispose();
  }

  void _unsubscribe() {
    if (_stream != null && _listener != null) {
      _stream!.removeListener(_listener!);
    }
    _stream = null;
    _listener = null;
  }

  void _resolveImage() {
    final img = Image.network(widget.url);
    final stream = img.image.resolve(const ImageConfiguration());
    _listener = ImageStreamListener((info, _) {
      final w = info.image.width.toDouble();
      final h = info.image.height.toDouble();
      if (h != 0 && mounted) {
        setState(() => _aspect = w / h);
      }
    }, onError: (_, __) {});
    stream.addListener(_listener!);
    _stream = stream;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final aspect = _aspect ?? (4 / 3);
        final expectedHeight = width / aspect;
        final height = expectedHeight.clamp(160.0, widget.maxHeight);

        return SizedBox(
          height: height,
          width: double.infinity,
          child: Image.network(
            widget.url,
            fit: widget.fit,
            key: ValueKey(widget.url),
            gaplessPlayback: true,
            loadingBuilder: (c, w, p) =>
                p == null ? w : const Center(child: CircularProgressIndicator()),
            errorBuilder: (_, __, ___) =>
                const Center(child: Icon(Icons.broken_image)),
          ),
        );
      },
    );
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
              final doc = docs[i];
              final data = doc.data() as Map<String, dynamic>;

              // images(List<String>) または旧 imageUrl(String) を吸収
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

              return PostCard(
                key: ValueKey(doc.id), // Flutter のリユース対策
                postId: doc.id,
                images: images,
                userName: userName,
                text: text,
              );
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
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const PostEditorScreen()),
            );
          }
        },
      ),
    );
  }
}

/// 1件分の投稿カード（「続きを読む」で本文＋コメントをインライン展開）
class PostCard extends StatefulWidget {
  const PostCard({
    super.key,
    required this.postId,
    required this.images,
    required this.userName,
    required this.text,
  });

  final String postId;
  final List<String> images;
  final String userName;
  final String text;

  @override
  State<PostCard> createState() => _PostCardState();
}

class _PostCardState extends State<PostCard> {
  bool _expanded = false;      // 本文・コメントの展開状態
  int _commentLimit = 5;       // もっと見る用
  final _commentCtrl = TextEditingController();

  @override
  void dispose() {
    _commentCtrl.dispose();
    super.dispose();
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final safeImages =
        (widget.images as List?)?.whereType<String>().map((s) => s.trim()).toList() ?? <String>[];
    final firstUrl = safeImages.isNotEmpty ? safeImages.first : null;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 画像
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: firstUrl == null
                ? Container(
                    height: 240,
                    color: Colors.black12,
                    alignment: Alignment.center,
                    child: const Text('画像なし'),
                  )
                : AutoSizedNetworkImage(
                    url: firstUrl,
                    maxHeight: 360,
                    fit: BoxFit.contain,
                  ),
          ),
          const SizedBox(height: 8),

          // ユーザー名＋アクション
          Row(
            children: [
              const CircleAvatar(radius: 12, child: Icon(Icons.person, size: 14)),
              const SizedBox(width: 8),
              Expanded(child: Text(widget.userName, style: theme.textTheme.bodyMedium)),
              IconButton(onPressed: () {}, icon: const Icon(Icons.shopping_cart_outlined)),
              IconButton(onPressed: () {}, icon: const Icon(Icons.favorite_border)),
              IconButton(onPressed: () {}, icon: const Icon(Icons.attach_file)),
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
              child: Text(
                _expanded ? '閉じる' : '続きを読む',
                style: const TextStyle(decoration: TextDecoration.underline),
              ),
            ),
          ],

          // ===== 展開部（本文全文 + コメント一覧 + 入力） =====
          if (_expanded) ...[
            // 本文全文
            if (widget.text.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  widget.text,
                  style: const TextStyle(fontSize: 15, height: 1.5),
                ),
              ),

            // コメント一覧（展開時だけ購読して負荷を抑える）
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
                    // コメント行
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
                                  style: theme.textTheme.bodyMedium,
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

                    // もっと見る
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

            // コメント入力
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
                IconButton(
                  onPressed: _addComment,
                  icon: const Icon(Icons.send),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}