// lib/screens/account_screen.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../widgets/post_card.dart';
import 'post_list_screen.dart';
import 'post_editor_screen.dart';
import 'favorites_screen.dart';
import 'profile_edit_screen.dart';

class AccountScreen extends StatefulWidget {
  const AccountScreen({super.key});
  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

enum _Tab { posts, likes, clips }

class _AccountScreenState extends State<AccountScreen> {
  final uid = FirebaseAuth.instance.currentUser!.uid;

  String displayName = FirebaseAuth.instance.currentUser?.displayName ??
      (FirebaseAuth.instance.currentUser?.email ?? 'user');

  // stats
  int postCount = 0;
  int followerCount = 0;
  int followingCount = 0;
  int receivedLikeSum = 0;
  int receivedClipSum = 0;
  String bio = '';

  bool loadingStats = true;
  _Tab currentTab = _Tab.posts;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    try {
      // 自分の投稿
      final postsSnap = await FirebaseFirestore.instance
          .collection('posts')
          .where('userId', isEqualTo: uid)
          .get();
      postCount = postsSnap.size;

      // user doc
      final userDoc =
          await FirebaseFirestore.instance.collection('users').doc(uid).get();
      final m = userDoc.data() ?? {};
      bio = (m['bio'] ?? '') as String;

      // followers / following
      try {
        final f1 = await FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .collection('followers')
            .get();
        followerCount = f1.size;
      } catch (_) {}
      try {
        final f2 = await FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .collection('following')
            .get();
        followingCount = f2.size;
      } catch (_) {}

      // もらった♡📎合計
      int likeSum = 0, clipSum = 0;
      for (final d in postsSnap.docs) {
        final mm = d.data() as Map<String, dynamic>;
        likeSum += (mm['likeCount'] ?? 0) as int;
        clipSum += (mm['clipCount'] ?? 0) as int;
      }
      receivedLikeSum = likeSum;
      receivedClipSum = clipSum;
    } finally {
      if (mounted) setState(() => loadingStats = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const primary = Color(0xFF7D2A8E);

    return Scaffold(
      appBar: AppBar(
        title: const Text('アカウント'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => FirebaseAuth.instance.signOut(),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadStats,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 見出し
              _ReactiveDisplayName(uid: uid, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 10),

              // ヘッダ：アイコン + ステータス
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _ReactiveAvatar(uid: uid, radius: 36),
                  const SizedBox(width: 16),
                  Expanded(
                    child: loadingStats
                        ? const Padding(
                            padding: EdgeInsets.only(top: 8),
                            child: Center(child: CircularProgressIndicator()),
                          )
                        : Column(
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                children: [
                                  _statBox('投稿数', postCount),
                                  _statBox('フォロワー', followerCount),
                                  _statBox('フォロー中', followingCount),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                children: [
                                  _statBox('いいねされた数', receivedLikeSum),
                                  _statBox('お気に入りされた数', receivedClipSum),
                                ],
                              ),
                            ],
                          ),
                  ),
                ],
              ),

              const SizedBox(height: 14),

              // 自己紹介（URL欄は削除）
              if (bio.isNotEmpty)
                Text(bio, style: const TextStyle(height: 1.5)),

              const SizedBox(height: 16),

              // プロフィール編集ボタン（アウトラインの丸）
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: primary, width: 1.5),
                    foregroundColor: primary,
                    shape: const StadiumBorder(),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                    textStyle:
                        const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                  ),
                  onPressed: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const ProfileEditScreen()),
                    );
                    _loadStats(); // 変更反映（stats と bio 再読込）
                  },
                  child: const Text('プロフィールを編集する'),
                ),
              ),

              const SizedBox(height: 18),

              // 3つのショートカット（中央揃え：真ん中がきっちり中央に）
              Row(
                children: [
                  Expanded(
                    child: _shortcut(
                      icon: Icons.photo_camera_outlined,
                      label: '投稿一覧',
                      selected: currentTab == _Tab.posts,
                      onTap: () => setState(() => currentTab = _Tab.posts),
                      color: primary,
                    ),
                  ),
                  Expanded(
                    child: _shortcut(
                      icon: Icons.favorite_border,
                      label: 'いいね一覧',
                      selected: currentTab == _Tab.likes,
                      onTap: () => setState(() => currentTab = _Tab.likes),
                      color: primary,
                    ),
                  ),
                  Expanded(
                    child: _shortcut(
                      icon: Icons.attach_file,
                      label: 'お気に入り一覧',
                      selected: currentTab == _Tab.clips,
                      onTap: () => setState(() => currentTab = _Tab.clips),
                      color: primary,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // 選択中タブの二列グリッド
              _TwoColumnGrid(
                uid: uid,
                tab: currentTab,
                onTapTile: (doc) => _openPostBottomSheet(doc),
              ),
            ],
          ),
        ),
      ),

      // ▼ 投稿一覧画面と同じ BottomNavigationBar
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: 4,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'ホーム'),
          BottomNavigationBarItem(icon: Icon(Icons.search), label: '検索'),
          BottomNavigationBarItem(icon: Icon(Icons.add_box_outlined), label: '投稿'),
          BottomNavigationBarItem(icon: Icon(Icons.bookmark_border), label: 'お気に入り'),
          BottomNavigationBarItem(icon: Icon(Icons.person_outline), label: 'アカウント'),
        ],
        onTap: (index) {
          if (index == 0) {
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(builder: (_) => const PostListScreen()),
              (route) => false,
            );
          } else if (index == 2) {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const PostEditorScreen()),
            );
          } else if (index == 3) {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const FavoritesScreen(columns: 3)),
            );
          }
          // index==1(検索) は未実装、index==4 は現在地
        },
      ),
    );
  }

  // タイルを PostCard でモーダル表示
  void _openPostBottomSheet(QueryDocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final images = (data['images'] as List?)
            ?.whereType<String>()
            .map((e) => e.trim())
            .toList() ??
        <String>[];
    final urls = images.isNotEmpty ? images : [(data['imageUrl'] ?? '').toString()];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DraggableScrollableSheet(
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
                  padding: const EdgeInsets.only(bottom: 24),
                  child: PostCard(
                    postId: doc.id,
                    images: urls,
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
      ),
    );
  }

  Widget _statBox(String label, int value) {
    return Column(
      children: [
        Text('$value',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.black54)),
      ],
    );
  }

  Widget _shortcut({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    required Color color,
    bool selected = false,
  }) {
    final style = TextStyle(
      color: color,
      fontWeight: selected ? FontWeight.w800 : FontWeight.w700,
      fontSize: 13,
    );
    return InkWell(
      onTap: onTap,
      child: Column(
        children: [
          Icon(icon, color: color, size: 26),
          const SizedBox(height: 6),
          Text(label, style: style, textAlign: TextAlign.center),
        ],
      ),
    );
  }
}

/// 二列グリッド（投稿 / いいね / お気に入り を切り替えて表示）
class _TwoColumnGrid extends StatelessWidget {
  const _TwoColumnGrid({
    required this.uid,
    required this.tab,
    required this.onTapTile,
  });

  final String uid;
  final _Tab tab;
  final void Function(QueryDocumentSnapshot doc) onTapTile;

  @override
  Widget build(BuildContext context) {
    if (tab == _Tab.posts) {
      // まず userId で読む（orderBy しない → インデックス不要）
      final q1 = FirebaseFirestore.instance
          .collection('posts')
          .where('userId', isEqualTo: uid);

      return StreamBuilder<QuerySnapshot>(
        stream: q1.snapshots(),
        builder: (context, snap1) {
          if (snap1.connectionState == ConnectionState.waiting) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          final docs1 = snap1.data?.docs ?? [];

          if (docs1.isNotEmpty) {
            final sorted = _sortByCreatedAtDesc(docs1);
            return _buildGrid(sorted, onTapTile);
          }

          // 旧データ互換：フィールド名が 'uid' の投稿も拾う
          final q2 = FirebaseFirestore.instance
              .collection('posts')
              .where('uid', isEqualTo: uid);

          return StreamBuilder<QuerySnapshot>(
            stream: q2.snapshots(),
            builder: (context, snap2) {
              if (snap2.connectionState == ConnectionState.waiting) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              final docs2 = snap2.data?.docs ?? [];
              if (docs2.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(child: Text('まだ投稿がありません')),
                );
              }
              final sorted = _sortByCreatedAtDesc(docs2);
              return _buildGrid(sorted, onTapTile);
            },
          );
        },
      );
    }

    // いいね / クリップは従来どおり
    Query q;
    switch (tab) {
      case _Tab.likes:
        q = FirebaseFirestore.instance
            .collection('posts')
            .where('likedBy', arrayContains: uid);
        break;
      case _Tab.clips:
        q = FirebaseFirestore.instance
            .collection('posts')
            .where('clippedBy', arrayContains: uid);
        break;
      default:
        q = FirebaseFirestore.instance.collection('posts').limit(0); // ここは来ない
    }

    return StreamBuilder<QuerySnapshot>(
      stream: q.snapshots(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        final docs = snap.data?.docs ?? [];
        if (docs.isEmpty) {
          final msg = switch (tab) {
            _Tab.likes => 'まだ いいね した投稿がありません',
            _Tab.clips => 'まだクリップがありません',
            _ => 'まだ投稿がありません',
          };
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Center(child: Text(msg)),
          );
        }
        // いいね／クリップは createdAt 無くても OK。念のため並び替え
        final sorted = _sortByCreatedAtDesc(docs);
        return _buildGrid(sorted, onTapTile);
      },
    );
  }

  List<QueryDocumentSnapshot> _sortByCreatedAtDesc(List<QueryDocumentSnapshot> docs) {
    final list = [...docs];
    list.sort((a, b) {
      final ma = a.data() as Map<String, dynamic>;
      final mb = b.data() as Map<String, dynamic>;
      final ta = ma['createdAt'];
      final tb = mb['createdAt'];
      final va = ta is Timestamp ? ta : Timestamp(0, 0);
      final vb = tb is Timestamp ? tb : Timestamp(0, 0);
      return vb.compareTo(va); // desc
    });
    return list;
  }

  Widget _buildGrid(List<QueryDocumentSnapshot> docs,
      void Function(QueryDocumentSnapshot) onTap) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2, // 二列
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 1,
      ),
      itemCount: docs.length,
      itemBuilder: (_, i) {
        final doc = docs[i];
        final data = doc.data() as Map<String, dynamic>;
        final images = (data['images'] as List?)
                ?.whereType<String>()
                .map((s) => s.trim())
                .toList() ??
            <String>[];
        final thumb = images.isNotEmpty ? images.first : (data['imageUrl'] ?? '');

        return InkWell(
          onTap: () => onTap(doc),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: AspectRatio(
              aspectRatio: 1,
              child: thumb.toString().isEmpty
                  ? const ColoredBox(color: Color(0x11000000))
                  : Image.network(
                      thumb,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) =>
                          const Icon(Icons.broken_image),
                    ),
            ),
          ),
        );
      },
    );
  }
}

/// 最新プロフィール画像を購読し、キャッシュバスター付で表示
class _ReactiveAvatar extends StatelessWidget {
  const _ReactiveAvatar({required this.uid, this.radius = 36});
  final String uid;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection('users').doc(uid).snapshots(),
      builder: (context, snap) {
        String? photoUrl;
        int version = 0;
        if (snap.hasData && snap.data!.exists) {
          final m = snap.data!.data()!;
          final p = (m['photoUrl'] ?? '').toString();
          photoUrl = p.isEmpty ? null : p;

          final ts = m['photoUpdatedAt'];
          if (ts is Timestamp) {
            version = ts.seconds;
          } else if (ts is int) {
            version = ts;
          }
        }

        String? showUrl;
        if (photoUrl != null) {
          final sep = photoUrl!.contains('?') ? '&' : '?';
          showUrl = '$photoUrl${sep}v=$version';
        }

        if (showUrl == null) {
          return const CircleAvatar(radius: 36, child: Icon(Icons.person, size: 30));
        }

        return CircleAvatar(
          radius: radius,
          backgroundColor: Colors.transparent,
          child: ClipOval(
            child: Image.network(
              showUrl,
              key: ValueKey(showUrl),
              width: radius * 2,
              height: radius * 2,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => const Icon(Icons.person, size: 30),
              loadingBuilder: (c, w, p) => p == null
                  ? w
                  : SizedBox(
                      width: radius * 2,
                      height: radius * 2,
                      child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                    ),
            ),
          ),
        );
      },
    );
  }
}

class _ReactiveDisplayName extends StatelessWidget {
  const _ReactiveDisplayName({required this.uid, this.style});
  final String uid;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final authFallback = FirebaseAuth.instance.currentUser?.displayName
        ?? (FirebaseAuth.instance.currentUser?.email ?? 'user');

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection('users').doc(uid).snapshots(),
      builder: (context, snap) {
        String name = authFallback;
        if (snap.hasData && snap.data!.exists) {
          final m = snap.data!.data()!;
          final n = (m['displayName'] ?? '').toString().trim();
          if (n.isNotEmpty) name = n;
        }
        return Text(name, style: style ?? const TextStyle(fontSize: 18, fontWeight: FontWeight.w700));
      },
    );
  }
}