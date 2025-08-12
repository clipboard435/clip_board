import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final email = TextEditingController();
  final pass = TextEditingController();
  final passConfirm = TextEditingController();
  final displayName = TextEditingController();
  bool loading = false;

  Future<void> _signUp() async {
    if (loading) return;
    if (pass.text != passConfirm.text) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('パスワードが一致しません')));
      return;
    }
    setState(() => loading = true);
    try {
      final cred = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email.text.trim(),
        password: pass.text.trim(),
      );

      // プロフィール保存（任意：表示名をAuthにも反映）
      await cred.user?.updateDisplayName(displayName.text.trim());

      // Firestoreにもユーザープロファイルを作成しておくと後々便利
      await FirebaseFirestore.instance.collection('users').doc(cred.user!.uid).set({
        'displayName': displayName.text.trim(),
        'email': email.text.trim(),
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (mounted) Navigator.pop(context); // 戻ってサインイン画面へ
    } on FirebaseAuthException catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.message ?? '登録に失敗しました')));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('アカウント作成')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                TextField(
                  controller: displayName,
                  decoration: const InputDecoration(labelText: '表示名（ニックネーム）'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: email,
                  decoration: const InputDecoration(labelText: 'メールアドレス'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: pass,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: 'パスワード'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: passConfirm,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: 'パスワード（確認）'),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: loading ? null : _signUp,
                  child: Text(loading ? '作成中…' : 'アカウントを作成'),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('サインインに戻る'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}