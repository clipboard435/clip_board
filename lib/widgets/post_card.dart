// lib/widgets/post_card.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// 画像の実寸から比率を算出し、トリミング無しで自然に見せる
class AutoSizedNetworkImage extends StatefulWidget {
  final String url;
  final double maxHeight;
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
  double? _aspect;
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
      if (h != 0 && mounted) setState(() => _aspect = w / h);
    }, onError: (_, __) {});
    stream.addListener(_listener!);
    _stream = stream;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
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
          errorBuilder: (_, __, ___) => const Center(child: Icon(Icons.broken_image)),
        ),
      );
    });
  }
}

/// 一件分の投稿カード
/// - 画像自動リサイズ表示
/// - いいね（♡）トグル＋カウント表示
/// - 「続きを読む」で本文全文＋コメント一覧＋コメント入力をその場に展開
class PostCard extends StatefulWidget {
  const PostCard({
    super.key,
    required this.postId,
    required this.images,
    required this.userName,
    required this.text,
    this.likedBy = const <String>[],
    this.likeCount = 0,
  });

  final String postId;
  final List<String> images;
  final String userName;
  final String text;
  final List<String> likedBy;
  final int likeCount;

  @override
  State<PostCard> createState() => _PostCardState();
}

class _PostCardState extends State<PostCard> {
  bool _expanded = false;
  int _commentLimit = 5;
  final _commentCtrl = TextEditingController();
  bool _toggling = false; // 連打防止

  @override
  void dispose() {
    _commentCtrl.dispose();
    super.dispose();
  }

  Future<void> _toggleLike() async {
    if (_toggling) return;
    _toggling = true;

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('ログインしてください')));
      _toggling = false;
      return;
    }

    final ref = FirebaseFirestore.instance.collection('posts').doc(widget.postId);
    try {
      await FirebaseFirestore.instance.runTransaction((tx) async {
        final snap = await tx.get(ref);
        if (!snap.exists) return;
        final data = snap.data() as Map<String, dynamic>;
        final List liked = (data['likedBy'] as List?)?.whereType<String>().toList() ?? <String>[];
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
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('いいねに失敗しました: $e')));
    } finally {
      _toggling = false;
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final safeImages =
        (widget.images as List?)?.whereType<String>().map((s) => s.trim()).toList() ?? <String>[];
    final firstUrl = safeImages.isNotEmpty ? safeImages.first : null;
    final bool isLiked = uid != null && widget.likedBy.contains(uid);
    final int likeCount = widget.likeCount;

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
                : AutoSizedNetworkImage(url: firstUrl, maxHeight: 360, fit: BoxFit.contain),
          ),
          const SizedBox(height: 8),

          // ユーザー名＋アクション（♡含む）
          Row(
            children: [
              const CircleAvatar(radius: 12, child: Icon(Icons.person, size: 14)),
              const SizedBox(width: 8),
              Expanded(child: Text(widget.userName, style: theme.textTheme.bodyMedium)),

              // 🛒 カート（復活）
              IconButton(
                onPressed: _onTapCart, // ← 後述の関数を追加
                icon: const Icon(Icons.shopping_cart_outlined),
                tooltip: 'カートに追加',
              ),

              // いいね
              Row(
                children: [
                  IconButton(
                    onPressed: _toggleLike,
                    icon: Icon(
                      isLiked ? Icons.favorite : Icons.favorite_border,
                      color: isLiked ? Colors.red : null,
                    ),
                  ),
                  Text('$likeCount'),
                ],
              ),

              // 他アイコン（お好みで）
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

          // 展開部：本文全文＋コメント一覧＋入力
          if (_expanded) ...[
            if (widget.text.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(widget.text, style: const TextStyle(fontSize: 15, height: 1.5)),
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

  void _onTapCart() {
    // TODO: ここに購買フロー遷移やカート追加処理を実装
    // 例：別画面へ遷移
    // Navigator.push(context, MaterialPageRoute(builder: (_) => const PurchaseScreen(postId: widget.postId)));

    // ひとまずトーストで分かるように
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('カートに追加（ダミー）')),
    );
  }
  
}