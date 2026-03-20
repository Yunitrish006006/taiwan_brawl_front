import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/api_client.dart';
import '../../services/auth_service.dart';
import '../../utils/snackbar.dart';

class AuthPage extends StatefulWidget {
  const AuthPage({super.key});

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  final _emailController = TextEditingController(text: 'demo@taiwanbrawl.tw');
  final _passwordController = TextEditingController(text: '123456');

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    final auth = context.read<AuthService>();
    try {
      await auth.login(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );
      if (!mounted) return;
      Navigator.of(context).pushReplacementNamed('/home');
    } on ApiException catch (e) {
      if (!mounted) return;
      showAppSnackBar(context, e.message);
    }
  }

  Future<void> _googleLogin() async {
    final auth = context.read<AuthService>();
    try {
      await auth.googleLogin();
      if (!mounted) return;
      Navigator.of(context).pushReplacementNamed('/home');
    } on ApiException catch (e) {
      if (!mounted) return;
      showAppSnackBar(context, e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final loading = context.watch<AuthService>().isLoading;
    return Scaffold(
      appBar: AppBar(title: const Text('Taiwan Brawl 登入')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: _emailController,
                  decoration: const InputDecoration(labelText: 'Email'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _passwordController,
                  decoration: const InputDecoration(labelText: '密碼'),
                  obscureText: true,
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: loading ? null : _login,
                  child: const Text('一般登入'),
                ),
                const SizedBox(height: 8),
                OutlinedButton(
                  onPressed: loading ? null : _googleLogin,
                  child: const Text('Google 登入'),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => Navigator.of(context).pushNamed('/register'),
                  child: const Text('還沒有帳號？先註冊'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
