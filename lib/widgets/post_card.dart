// lib/widgets/post_card.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class PostCard extends StatefulWidget {
  const PostCard({
    super.key,
    required this.postId,
    required this.images,
    required this.userName,   // フォールバック表示用
    required this.text,
    this.userId,              // users/{uid} を購読して最新プロフィールを表示
    this.likedBy = const <String>[],
    this.likeCount = 0,
    this.clippedBy = const <String>[],
    this.clipCount = 0,
  });

  final String postId;
  final List<String> images;
  final String userName;
  final String text;

  final String? userId;
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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('ログインしてください')));
      }
      _busyLike = false; return;
    }
    final ref = FirebaseFirestore.instance.collection('posts').doc(widget.postId);
    try {
      await FirebaseFirestore.instance.runTransaction((tx) async {
        final snap = await tx.get(ref);
        if (!snap.exists) return;
        final data = snap.data() as Map<String, dynamic>;
        final List<String> liked = (data['likedBy'] as List?)?.whereType<String>().toList() ?? [];
        final int count = (data['likeCount'] ?? 0) as int;
        if (liked.contains(uid)) {
          tx.update(ref, {'likedBy': FieldValue.arrayRemove([uid]), 'likeCount': count > 0 ? count - 1 : 0});
        } else {
          tx.update(ref, {'likedBy': FieldValue.arrayUnion([uid]), 'likeCount': count + 1});
        }
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('いいねに失敗しました: $e')));
      }
    } finally { _busyLike = false; }
  }

  Future<void> _toggleClip() async {
    if (_busyClip) return;
    _busyClip = true;
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('ログインしてください')));
      }
      _busyClip = false; return;
    }
    final ref = FirebaseFirestore.instance.collection('posts').doc(widget.postId);
    try {
      await FirebaseFirestore.instance.runTransaction((tx) async {
        final snap = await tx.get(ref);
        if (!snap.exists) return;
        final data = snap.data() as Map<String, dynamic>;
        final List<String> clipped = (data['clippedBy'] as List?)?.whereType<String>().toList() ?? [];
        final int count = (data['clipCount'] ?? 0) as int;
        if (clipped.contains(uid)) {
          tx.update(ref, {'clippedBy': FieldValue.arrayRemove([uid]), 'clipCount': count > 0 ? count - 1 : 0});
        } else {
          tx.update(ref, {'clippedBy': FieldValue.arrayUnion([uid]), 'clipCount': count + 1});
        }
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('クリップに失敗しました: $e')));
      }
    } finally { _busyClip = false; }
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
        'userName': user.displayName ?? user.email ?? 'ユーザー', // フォールバック
        'createdAt': FieldValue.serverTimestamp(),
      });
      _commentCtrl.clear();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('コメントに失敗しました: $e')));
      }
    }
  }

  void _onTapCart() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('カートに追加（ダミー）')),
    );
  }

  void _openEditor(BuildContext context) {
    // 例：PostEditorScreen を編集モードで開く
    // Navigator.push(context, MaterialPageRoute(builder: (_) => PostEditorScreen(postId: widget.postId)));
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('編集を開く（実装予定）')));
  }

  void _confirmDelete(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('削除しますか？'),
        content: const Text('この操作は取り消せません。'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('キャンセル')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('削除', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (ok == true) {
      // TODO: 削除処理（Functions連携 or クライアント側で画像/コメント削除 → posts/{postId} delete）
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('削除処理（実装予定）')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final images =
        (widget.images as List?)?.whereType<String>().map((s) => s.trim()).toList() ?? <String>[];

        // ① build内の先頭あたりで判定を用意
    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    final isOwner = currentUid != null && currentUid == (widget.userId ?? '');

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

          
          // ここを「ユーザー名の横にボタン」を並べるレイアウトに戻す
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // 左側：ユーザーアイコン＋名前（購読）
              Expanded(
                child: _UserHeader(userId: widget.userId, fallbackName: widget.userName),
              ),
              // ★ ここに三点メニュー（自分の投稿の時だけ表示）
              if (isOwner)
                PopupMenuButton<String>(
                  onSelected: (v) {
                    if (v == 'edit') _openEditor(context);
                    if (v == 'delete') _confirmDelete(context);
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'edit', child: Text('編集')),
                    PopupMenuItem(value: 'delete', child: Text('削除')),
                  ],
                  icon: const Icon(Icons.more_vert),
                  tooltip: 'その他',
                ),

              // 右側：アクション  🛒 / ♡ / 📎
              IconButton(
                onPressed: _onTapCart,
                icon: const Icon(Icons.shopping_cart_outlined),
                tooltip: 'カートに追加',
              ),

              // ♡（いいね）— posts/{postId} を購読してライブ反映
              StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                stream: FirebaseFirestore.instance.collection('posts').doc(widget.postId).snapshots(),
                builder: (context, snap) {
                  List<String> likedBy = widget.likedBy;
                  int likeCount = widget.likeCount;
                  if (snap.hasData && snap.data!.exists) {
                    final m = snap.data!.data()!;
                    likedBy = (m['likedBy'] as List?)?.whereType<String>().toList() ?? <String>[];
                    likeCount = (m['likeCount'] ?? 0) as int;
                  }
                  final uid = FirebaseAuth.instance.currentUser?.uid;
                  final isLiked = uid != null && likedBy.contains(uid);
                  return Row(
                    children: [
                      IconButton(
                        onPressed: _toggleLike,
                        icon: Icon(isLiked ? Icons.favorite : Icons.favorite_border,
                            color: isLiked ? Colors.red : null),
                        tooltip: isLiked ? 'いいね解除' : 'いいね',
                      ),
                      Text('$likeCount'),
                    ],
                  );
                },
              ),

              // 📎（クリップ）— posts/{postId} を購読してライブ反映
              StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                stream: FirebaseFirestore.instance.collection('posts').doc(widget.postId).snapshots(),
                builder: (context, snap) {
                  List<String> clippedBy = widget.clippedBy;
                  int clipCount = widget.clipCount;
                  if (snap.hasData && snap.data!.exists) {
                    final m = snap.data!.data()!;
                    clippedBy = (m['clippedBy'] as List?)?.whereType<String>().toList() ?? <String>[];
                    clipCount = (m['clipCount'] ?? 0) as int;
                  }
                  final uid = FirebaseAuth.instance.currentUser?.uid;
                  final isClipped = uid != null && clippedBy.contains(uid);
                  return Row(
                    children: [
                      IconButton(
                        onPressed: _toggleClip,
                        icon: Icon(isClipped ? Icons.bookmark : Icons.bookmark_border,
                            color: isClipped ? Colors.blue : null),
                        tooltip: isClipped ? 'クリップ解除' : 'クリップ',
                      ),
                      Text('$clipCount'),
                    ],
                  );
                },
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

            // コメント（users/{uid} を購読して最新プロフィールで表示）
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
                      final commentUid = (c['userId'] ?? '').toString();
                      final fallbackName = (c['userName'] ?? 'ユーザー').toString();
                      final text = (c['text'] ?? '').toString();
                      return _CommentRow(userId: commentUid, fallbackName: fallbackName, text: text);
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
  void dispose() { _pc.dispose(); super.dispose(); }

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
              fit: BoxFit.contain,
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
                  width: 6, height: 6,
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

/// 投稿主プロフィール（users/{uid} を購読）
class _UserHeader extends StatelessWidget {
  const _UserHeader({required this.userId, required this.fallbackName});
  final String? userId;
  final String fallbackName;

  @override
  Widget build(BuildContext context) {
    if (userId == null || userId!.isEmpty) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircleAvatar(radius: 12, child: Icon(Icons.person, size: 14)),
          const SizedBox(width: 8),
          Flexible(child: Text(fallbackName, overflow: TextOverflow.ellipsis)),
        ],
      );
    }

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection('users').doc(userId).snapshots(),
      builder: (context, snap) {
        // フォールバック初期値
        String name = fallbackName;
        String? photoUrlWithBust;

        if (snap.hasData && snap.data!.exists) {
          final m = snap.data!.data()!;
          final dn = (m['displayName'] ?? '').toString().trim();
          if (dn.isNotEmpty) name = dn;

          final p = (m['photoUrl'] ?? '').toString().trim();
          if (p.isNotEmpty) {
            int version = 0;
            final ts = m['photoUpdatedAt'];
            if (ts is Timestamp) {
              version = ts.seconds;
            } else if (ts is int) {
              version = ts;
            }
            final sep = p.contains('?') ? '&' : '?';
            photoUrlWithBust = version > 0 ? '$p${sep}v=$version' : p;
          }
        }

        final avatar = (photoUrlWithBust == null)
            ? const CircleAvatar(radius: 12, child: Icon(Icons.person, size: 14))
            : CircleAvatar(radius: 12, backgroundImage: NetworkImage(photoUrlWithBust!));

        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            avatar,
            const SizedBox(width: 8),
            Flexible(child: Text(name, overflow: TextOverflow.ellipsis)),
          ],
        );
      },
    );
  }
}

/// コメント1行（users/{uid} を購読して最新プロフィールで表示）
class _CommentRow extends StatelessWidget {
  const _CommentRow({required this.userId, required this.fallbackName, required this.text});
  final String userId;
  final String fallbackName;
  final String text;

  @override
  Widget build(BuildContext context) {
    if (userId.isEmpty) {
      return _fallbackRow(fallbackName);
    }
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection('users').doc(userId).snapshots(),
      builder: (context, snap) {
        String name = fallbackName;
        String? photoUrlWithBust;

        if (snap.hasData && snap.data!.exists) {
          final m = snap.data!.data()!;
          final dn = (m['displayName'] ?? '').toString().trim();
          if (dn.isNotEmpty) name = dn;

          final p = (m['photoUrl'] ?? '').toString().trim();
          if (p.isNotEmpty) {
            int version = 0;
            final ts = m['photoUpdatedAt'];
            if (ts is Timestamp) {
              version = ts.seconds;
            } else if (ts is int) {
              version = ts;
            }
            final sep = p.contains('?') ? '&' : '?';
            photoUrlWithBust = version > 0 ? '$p${sep}v=$version' : p;
          }
        }
        return _row(name, photoUrlWithBust);
      },
    );
  }

  Widget _fallbackRow(String name) => _row(name, null);

  Widget _row(String name, String? photoUrl) {
    final avatar = (photoUrl == null || photoUrl.isEmpty)
        ? const CircleAvatar(radius: 12, child: Icon(Icons.person, size: 14))
        : CircleAvatar(radius: 12, backgroundImage: NetworkImage(photoUrl));
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          avatar,
          const SizedBox(width: 8),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: const TextStyle(color: Colors.black87),
                children: [
                  TextSpan(text: '$name  ', style: const TextStyle(fontWeight: FontWeight.w600)),
                  TextSpan(text: text),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}