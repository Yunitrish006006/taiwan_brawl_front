import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/api_client.dart';
import '../../services/auth_service.dart';
import '../../utils/snackbar.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final _nameController = TextEditingController();
  final _bioController = TextEditingController();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final user = context.read<AuthService>().user;
    if (user != null) {
      _nameController.text = user.name;
      _bioController.text = user.bio ?? '';
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    try {
      await context.read<AuthService>().updateProfile(
        name: _nameController.text.trim(),
        bio: _bioController.text.trim(),
      );
      if (!mounted) return;
      showAppSnackBar(context, '個人資料已更新');
    } on ApiException catch (e) {
      if (!mounted) return;
      showAppSnackBar(context, e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthService>().user;
    if (user == null) {
      return const Scaffold(body: Center(child: Text('請先登入')));
    }

    return Scaffold(
      appBar: AppBar(title: const Text('個人資料')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text('Email: ${user.email}'),
              const SizedBox(height: 12),
              TextField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: '名稱'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _bioController,
                maxLines: 4,
                decoration: const InputDecoration(labelText: '自我介紹'),
              ),
              const SizedBox(height: 16),
              FilledButton(onPressed: _save, child: const Text('儲存')),
            ],
          ),
        ),
      ),
    );
  }
}
