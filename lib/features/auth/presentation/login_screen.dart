import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../settings/data/auth_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final username = TextEditingController();
  final password = TextEditingController();
  final auth = AuthService();
  bool biometric = false;
  bool loading = true;
  bool showCredentials = false;
  String? error;

  @override
  void initState() {
    super.initState();
    _prepareLogin();
  }

  @override
  void dispose() {
    username.dispose();
    password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AppScaffold(
    title: AppStrings.login,
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: loading
            ? const CircularProgressIndicator()
            : biometric && !showCredentials
            ? _buildBiometricLogin()
            : _buildCredentialLogin(),
      ),
    ),
  );

  Widget _buildBiometricLogin() => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      const Icon(Icons.face_retouching_natural_outlined, size: 64),
      const SizedBox(height: 16),
      const Text('برای ورود از احراز هویت دستگاه استفاده کنید'),
      const SizedBox(height: 20),
      SizedBox(
        width: double.infinity,
        child: AppButton(
          label: 'ورود با چهره یا قفل دستگاه',
          onPressed: _biometricLogin,
        ),
      ),
      const SizedBox(height: 12),
      TextButton(
        onPressed: () => setState(() => showCredentials = true),
        child: const Text('ورود با نام کاربری و رمز عبور'),
      ),
      if (error != null)
        Text(error!, style: const TextStyle(color: Colors.red)),
    ],
  );

  Widget _buildCredentialLogin() => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      AppTextField(controller: username, label: 'نام کاربری'),
      const SizedBox(height: 12),
      AppTextField(
        controller: password,
        label: AppStrings.password,
        obscureText: true,
      ),
      if (error != null)
        Text(error!, style: const TextStyle(color: Colors.red)),
      const SizedBox(height: 20),
      SizedBox(
        width: double.infinity,
        child: AppButton(label: AppStrings.login, onPressed: _login),
      ),
      if (biometric) ...[
        const SizedBox(height: 12),
        TextButton.icon(
          onPressed: _biometricLogin,
          icon: const Icon(Icons.fingerprint),
          label: const Text('ورود با قفل دستگاه'),
        ),
      ],
    ],
  );

  Future<void> _prepareLogin() async {
    final configured = await auth.biometricEnabled;
    final available = configured && await auth.biometricAvailable;
    if (!mounted) return;
    setState(() {
      biometric = available;
      loading = false;
    });
    if (available) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _biometricLogin();
      });
    }
  }

  Future<void> _login() async {
    if (await auth.verifyCredentials(username.text, password.text)) {
      if (mounted) context.go('/home');
    } else if (mounted) {
      setState(() => error = 'نام کاربری یا رمز عبور نادرست است.');
    }
  }

  Future<void> _biometricLogin() async {
    try {
      if (await auth.authenticateBiometric() && mounted) {
        context.go('/home');
      } else if (mounted) {
        setState(() {
          showCredentials = true;
          error = 'برای ادامه، با نام کاربری و رمز عبور وارد شوید.';
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          showCredentials = true;
          error = 'احراز هویت دستگاه در دسترس نیست.';
        });
      }
    }
  }
}
