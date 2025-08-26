import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../widgets/post_card.dart';
import 'profile_edit_screen.dart';

class AccountScreen extends StatefulWidget {
  const AccountScreen({super.key});

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  final uid = FirebaseAuth.instance.currentUser!.uid;
  String displayName =
      FirebaseAuth.instance.currentUser?.displayName ??
      (FirebaseAuth.instance.currentUser?.email ?? 'user');

  // ----- stats -----
  int postCount = 0;
  int followerCount = 0;  // users/{uid}/followers の件数（なければ0）
  int followingCount = 0; // users/{uid}/following の件数（なければ0）
  int receivedLikeSum = 0; // もらった♡合計（自分の投稿の likeCount 合計）
  int receivedClipSum = 0; // もらった📎合計（自分の投稿の clipCount 合計）
  String bio = '';

  bool loadingStats = true;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
  try {
    final postsQuery = FirebaseFirestore.instance
        .collection('posts')
        .where('userId', isEqualTo: uid);

    // ① 投稿の取得（件数＋合計値計算に使う）
    final postsSnap = await postsQuery.get();
    postCount = postsSnap.size; // ← Aggregateではなく size を使用

    // ② 自己紹介
    final userDoc =
        await FirebaseFirestore.instance.collection('users').doc(uid).get();
    bio = (userDoc.data()?['bio'] ?? '') as String;

    // ③ フォロワー / フォロー中（サブコレクションがある場合）
    try {
      final folSnap = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('followers')
          .get();
      followerCount = folSnap.size; // ← size
    } catch (_) {}
    try {
      final fol2Snap = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('following')
          .get();
      followingCount = fol2Snap.size; // ← size
    } catch (_) {}

    // ④ もらった いいね / クリップ の合計
    int likeSum = 0;
    int clipSum = 0;
    for (final d in postsSnap.docs) {
      final m = d.data() as Map<String, dynamic>;
      likeSum += (m['likeCount'] ?? 0) as int;
      clipSum += (m['clipCount'] ?? 0) as int;
    }
    receivedLikeSum = likeSum;
    receivedClipSum = clipSum;
  } finally {
    if (mounted) setState(() => loadingStats = false);
  }
}


  @override
  Widget build(BuildContext context) {
    final nameStyle = Theme.of(context).textTheme.titleMedium;

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
              // --- ヘッダ（アイコン＋名前＋統計） ---
              Text(displayName, style: nameStyle),
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Avatar
                  const CircleAvatar(radius: 32, child: Icon(Icons.person, size: 28)),
                  const SizedBox(width: 16),
                  // Stats
                  Expanded(
                    child: loadingStats
                        ? const Center(child: Padding(
                            padding: EdgeInsets.only(top: 16),
                            child: CircularProgressIndicator(),
                          ))
                        : _StatsTable(
                            postCount: postCount,
                            followerCount: followerCount,
                            followingCount: followingCount,
                            receivedLikeSum: receivedLikeSum,
                            receivedClipSum: receivedClipSum,
                          ),
                  ),
                ],
              ),

              const SizedBox(height: 16),
              // --- 自己紹介 + 編集ボタン ---
              if (bio.isNotEmpty)
                Text(bio),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const ProfileEditScreen()),
                    );
                    _loadStats(); // 変更反映
                  },
                  child: const Text('プロフィールを編集する'),
                ),
              ),

              const SizedBox(height: 24),
              // --- お気に入り一覧（横スクロール） ---
              Row(
                children: const [
                  Icon(Icons.bookmark_border),
                  SizedBox(width: 8),
                  Text('お気に入り一覧', style: TextStyle(fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 92,
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('posts')
                      .where('clippedBy', arrayContains: uid)
                      // .orderBy('createdAt', descending: true) // インデックス後に有効化
                      .limit(24)
                      .snapshots(),
                  builder: (context, snap) {
                    if (snap.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final docs = snap.data?.docs ?? [];
                    if (docs.isEmpty) {
                      return const Center(child: Text('まだクリップがありません'));
                    }
                    return ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: docs.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                      itemBuilder: (_, i) {
                        final data = docs[i].data() as Map<String, dynamic>;
                        final imgs = (data['images'] as List?)
                                ?.whereType<String>()
                                .map((e) => e.trim())
                                .toList() ??
                            <String>[];
                        final url = imgs.isNotEmpty ? imgs.first : (data['imageUrl'] ?? '');
                        return ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: AspectRatio(
                            aspectRatio: 1,
                            child: url.toString().isEmpty
                                ? const ColoredBox(color: Color(0x11000000))
                                : Image.network(
                                    url,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => const Icon(Icons.broken_image),
                                  ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),

              // --- 「すべてのお気に入りを見る」 ---
              Align(
                alignment: Alignment.center,
                child: TextButton(
                  onPressed: () {
                    // 既存の FavoritesScreen を使ってください
                    Navigator.of(context).pushNamed('/favorites');
                  },
                  child: const Text('すべてのお気に入りを見る'),
                ),
              ),

              const SizedBox(height: 16),
              // --- 自分の投稿一覧（グリッド3列） ---
              Row(
                children: const [
                  Icon(Icons.photo_camera_outlined),
                  SizedBox(width: 8),
                  Text('投稿一覧', style: TextStyle(fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 8),
              StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('posts')
                    .where('userId', isEqualTo: uid)
                    .orderBy('createdAt', descending: true)
                    .snapshots(),
                builder: (context, snap) {
                  if (snap.connectionState == ConnectionState.waiting) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }
                  final docs = snap.data?.docs ?? [];
                  if (docs.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: Center(child: Text('まだ投稿がありません')),
                    );
                  }
                  return GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      mainAxisSpacing: 6,
                      crossAxisSpacing: 6,
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
                        onTap: () {
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
                                          images: images.isEmpty ? [thumb.toString()] : images,
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
                        },
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: AspectRatio(
                            aspectRatio: 1,
                            child: thumb.toString().isEmpty
                                ? const ColoredBox(color: Color(0x11000000))
                                : Image.network(
                                    thumb,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => const Icon(Icons.broken_image),
                                  ),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),

              Align(
                alignment: Alignment.center,
                child: TextButton(
                  onPressed: () {
                    // 必要なら「すべての投稿を見る」画面へ
                  },
                  child: const Text('すべての投稿を見る'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatsTable extends StatelessWidget {
  const _StatsTable({
    required this.postCount,
    required this.followerCount,
    required this.followingCount,
    required this.receivedLikeSum,
    required this.receivedClipSum,
  });

  final int postCount;
  final int followerCount;
  final int followingCount;
  final int receivedLikeSum;
  final int receivedClipSum;

  @override
  Widget build(BuildContext context) {
    Text _num(int n) => Text('$n', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16));
    const label = TextStyle(fontSize: 12, color: Colors.black54);

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            Column(children: [const Text('投稿数', style: label), _num(postCount)]),
            Column(children: [const Text('フォロワー', style: label), _num(followerCount)]),
            Column(children: [const Text('フォロー中', style: label), _num(followingCount)]),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            Column(children: [const Text('いいねされた数', style: label), _num(receivedLikeSum)]),
            Column(children: [const Text('お気に入りされた数', style: label), _num(receivedClipSum)]),
          ],
        ),
      ],
    );
  }
}