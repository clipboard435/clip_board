import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

class ProfileEditScreen extends StatefulWidget {
  const ProfileEditScreen({super.key});

  @override
  State<ProfileEditScreen> createState() => _ProfileEditScreenState();
}

class _ProfileEditScreenState extends State<ProfileEditScreen> {
  final uid = FirebaseAuth.instance.currentUser!.uid;

  final _nameCtrl = TextEditingController();
  final _bioCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  // 既存の値
  String? _currentPhotoUrl;

  // 編集中のアイコン画像
  Uint8List? _avatarBytes;
  String? _avatarName;

  bool _saving = false;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadCurrent();
  }

  Future<void> _loadCurrent() async {
    try {
      final user = FirebaseAuth.instance.currentUser!;
      _nameCtrl.text = user.displayName ?? '';
      _currentPhotoUrl = user.photoURL;

      final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      _bioCtrl.text = (doc.data()?['bio'] ?? '') as String;
      // name / photoUrl を users ドキュメントに持っているならマージ表示
      _nameCtrl.text = (doc.data()?['displayName'] ?? _nameCtrl.text) as String? ?? _nameCtrl.text;
      _currentPhotoUrl = (doc.data()?['photoUrl'] ?? _currentPhotoUrl) as String? ?? _currentPhotoUrl;
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pickAvatar() async {
    final res = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: false,
      withData: true,
    );
    if (res != null && res.files.single.bytes != null) {
      setState(() {
        _avatarBytes = res.files.single.bytes!;
        _avatarName = res.files.single.name;
      });
    }
  }

  Future<String?> _uploadAvatarIfNeeded() async {
    if (_avatarBytes == null) return _currentPhotoUrl; // 未変更
    final ts = DateTime.now().millisecondsSinceEpoch;
    final path = 'users/$uid/avatar/$ts-${_avatarName ?? 'avatar.jpg'}';
    final ref = FirebaseStorage.instance.ref(path);
    await ref.putData(
      _avatarBytes!,
      SettableMetadata(contentType: 'image/jpeg'),
    );
    return ref.getDownloadURL();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final displayName = _nameCtrl.text.trim();
      final photoUrl = await _uploadAvatarIfNeeded();
      final user = FirebaseAuth.instance.currentUser!;

      // FirebaseAuth のプロフィールも更新
      await user.updateDisplayName(displayName.isEmpty ? null : displayName);
      if (photoUrl != null && photoUrl.isNotEmpty) {
        await user.updatePhotoURL(photoUrl);
      }

      // Firestore users/{uid} に保存（将来の拡張想定）
      await FirebaseFirestore.instance.collection('users').doc(uid).set({
        'displayName': displayName,
        'photoUrl': photoUrl,
        'bio': _bioCtrl.text.trim(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (mounted) Navigator.pop(context, true); // 保存成功 → 戻る
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('保存に失敗しました: $e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _bioCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: const Color(0xFFFFF8D9), // 画像に近い淡いアイボリー
      appBar: AppBar(
        backgroundColor: const Color(0xFFFFF8D9),
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('プロフィールを編集'),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: Text(
              '保存',
              style: TextStyle(
                color: _saving ? Colors.grey : const Color(0xFF0077CC), // 青系
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                children: [
                  // アイコン画像（円形）＋「写真を編集」
                  Center(
                    child: Column(
                      children: [
                        Container(
                          width: 140,
                          height: 140,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.black26, width: 3),
                          ),
                          child: ClipOval(
                            child: _avatarBytes != null
                                ? Image.memory(_avatarBytes!, fit: BoxFit.cover)
                                : (_currentPhotoUrl == null || _currentPhotoUrl!.isEmpty)
                                    ? const Icon(Icons.person, size: 72, color: Colors.black38)
                                    : Image.network(
                                        _currentPhotoUrl!,
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) =>
                                            const Icon(Icons.person, size: 72, color: Colors.black38),
                                      ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        TextButton(
                          onPressed: _pickAvatar,
                          child: const Text('写真を編集'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // ユーザー名
                  Text('ユーザー名', style: theme.textTheme.bodySmall),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: _nameCtrl,
                    decoration: const InputDecoration(
                      hintText: 'ひらがな・カタカナ・数字・文字数',
                      border: OutlineInputBorder(),
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    ),
                    maxLength: 20,
                    validator: (v) {
                      final t = v?.trim() ?? '';
                      if (t.isEmpty) return 'ユーザー名を入力してください';
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),

                  // 自己紹介
                  Text('自己紹介', style: theme.textTheme.bodySmall),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: _bioCtrl,
                    maxLines: 6,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      isDense: true,
                      contentPadding: EdgeInsets.all(12),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}