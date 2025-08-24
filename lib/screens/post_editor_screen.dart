import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';

class PostEditorScreen extends StatefulWidget {
  const PostEditorScreen({super.key});

  @override
  State<PostEditorScreen> createState() => _PostEditorScreenState();
}

class _PostEditorScreenState extends State<PostEditorScreen> {
  // 入力
  final descCtrl = TextEditingController();
  final addressCtrl = TextEditingController();
  String? genre;

  // 画像（複数）
  List<Uint8List> imageBytes = [];
  List<String> imageNames = [];

  // 動画（1本）
  Uint8List? videoBytes;
  String? videoName;

  bool submitting = false;

  final genres = <String>['お出かけ', 'ファッション', 'グルメ', '暮らし', '学び', 'スポーツ'];

  // ===== ユーティリティ =====
  String _guessImageContentType(String name) {
    final n = name.toLowerCase();
    if (n.endsWith('.png')) return 'image/png';
    if (n.endsWith('.webp')) return 'image/webp';
    if (n.endsWith('.gif')) return 'image/gif';
    // heic/heif はブラウザ互換のため image/jpeg に寄せることが多い
    return 'image/jpeg';
  }

  String _guessVideoContentType(String name) {
    final n = name.toLowerCase();
    if (n.endsWith('.webm')) return 'video/webm';
    if (n.endsWith('.mov')) return 'video/quicktime';
    if (n.endsWith('.mkv')) return 'video/x-matroska';
    return 'video/mp4';
  }

  /// キャッシュを抑止するメタデータ（開発中推奨）
  SettableMetadata _noCacheMeta({required String contentType}) {
    return SettableMetadata(
      contentType: contentType,
      cacheControl: 'no-store, no-cache, max-age=0, must-revalidate',
      // 必要ならカスタムメタ: customMetadata: {'v': DateTime.now().millisecondsSinceEpoch.toString()},
    );
  }

  // 画像選択（複数）
  Future<void> pickImages() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: true,
      withData: true, // Webでbytesを得る
    );
    if (result != null) {
      final files = result.files.where((f) => f.bytes != null).toList();
      setState(() {
        imageBytes = files.map((f) => f.bytes!).toList();
        imageNames = files.map((f) => f.name).toList();
      });
    }
  }

  // 動画選択（1本）
  Future<void> pickVideo() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.video,
      allowMultiple: false,
      withData: true,
    );
    if (result != null && result.files.single.bytes != null) {
      setState(() {
        videoBytes = result.files.single.bytes!;
        videoName = result.files.single.name;
      });
    }
  }

  Future<void> submit() async {
    if (submitting) return;

    if (descCtrl.text.trim().isEmpty && imageBytes.isEmpty && videoBytes == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('説明・写真・動画のいずれかを追加してください')),
      );
      return;
    }
    if (genre == null || genre!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ジャンルを選択してください')),
      );
      return;
    }

    setState(() => submitting = true);

    try {
      final user = FirebaseAuth.instance.currentUser!;
      final now = DateTime.now().millisecondsSinceEpoch;

      // 画像アップロード（キャッシュ抑止）
      final imageUrls = <String>[];
      for (var i = 0; i < imageBytes.length; i++) {
        final name = imageNames.elementAt(i);
        final path = 'posts/${user.uid}/images/$now-$i-$name';
        final ref = FirebaseStorage.instance.ref(path);
        final meta = _noCacheMeta(contentType: _guessImageContentType(name));

        await ref.putData(imageBytes[i], meta);
        final url = await ref.getDownloadURL();
        imageUrls.add(url);
      }

      // 動画アップロード（キャッシュ抑止）
      String videoUrl = '';
      if (videoBytes != null) {
        final vName = videoName ?? 'video.mp4';
        final path = 'posts/${user.uid}/videos/$now-$vName';
        final ref = FirebaseStorage.instance.ref(path);
        final meta = _noCacheMeta(contentType: _guessVideoContentType(vName));

        await ref.putData(videoBytes!, meta);
        videoUrl = await ref.getDownloadURL();
      }

      // Firestoreへ保存
      await FirebaseFirestore.instance.collection('posts').add({
        'text': descCtrl.text.trim(),
        'images': imageUrls, // 複数
        'videoUrl': videoUrl, // 1本
        'genre': genre,
        'address': addressCtrl.text.trim(),
        'userId': user.uid,
        'userName': user.displayName ?? user.email ?? '',
        'createdAt': FieldValue.serverTimestamp(),
        // クライアント側キャッシュバスター用にversionを持たせたい場合は↓
        // 'version': now,
      });

      if (mounted) {
        Navigator.pop(context); // 投稿画面を閉じる
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('投稿しました')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('投稿に失敗しました: $e')),
      );
    } finally {
      if (mounted) setState(() => submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('投稿')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 写真
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('写真', style: theme.textTheme.titleMedium),
                IconButton(
                  onPressed: pickImages,
                  icon: const Icon(Icons.add, size: 26),
                  tooltip: '写真を追加',
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (imageBytes.isEmpty)
              Container(
                height: 80,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.black12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text('写真はまだありません'),
              )
            else
              SizedBox(
                height: 86,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: imageBytes.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (_, i) => ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.memory(
                      imageBytes[i],
                      width: 86,
                      height: 86,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              ),

            const SizedBox(height: 16),

            // 動画
            Text('動画', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: pickVideo,
              child: Container(
                height: 180,
                decoration: BoxDecoration(
                  color: Colors.black12,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    if (videoBytes == null)
                      const Icon(Icons.play_circle_fill, size: 56, color: Colors.deepPurple)
                    else
                      const Icon(Icons.check_circle, size: 40, color: Colors.green),
                  ],
                ),
              ),
            ),
            if (videoName != null)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(videoName!, overflow: TextOverflow.ellipsis),
              ),

            const SizedBox(height: 16),

            // 説明
            Text('投稿の説明', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            TextField(
              controller: descCtrl,
              maxLines: 4,
              decoration: const InputDecoration(
                hintText: '説明を書いてね',
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 16),

            // ジャンル
            Text('ジャンル', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: genre,
              items: genres.map((g) => DropdownMenuItem(value: g, child: Text(g))).toList(),
              onChanged: (v) => setState(() => genre = v),
              decoration: const InputDecoration(border: OutlineInputBorder()),
            ),

            const SizedBox(height: 16),

            // 住所
            Text('住所', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            TextField(
              controller: addressCtrl,
              decoration: const InputDecoration(
                hintText: '例：東京都渋谷区…',
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 24),

            // 投稿ボタン
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: submitting ? null : submit,
                child: Text(submitting ? '投稿中…' : '投稿する'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}