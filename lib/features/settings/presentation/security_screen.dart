import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../../core/widgets/app_text_field.dart';
import '../providers/auth_provider.dart';

class SecurityScreen extends ConsumerStatefulWidget {
  const SecurityScreen({super.key});
  @override
  ConsumerState<SecurityScreen> createState() => _SecurityScreenState();
}

class _SecurityScreenState extends ConsumerState<SecurityScreen> {
  final username = TextEditingController();
  final password = TextEditingController();
  final confirmation = TextEditingController();
  bool enabled = false;
  bool biometric = false;
  bool loading = true;
  bool saving = false;
  String? error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final service = ref.read(authServiceProvider);
    final current = await service.enabled;
    final savedUsername = await service.username;
    final savedBiometric = current && await service.biometricEnabled;
    if (!mounted) return;
    setState(() {
      enabled = current;
      biometric = savedBiometric;
      loading = false;
      username.text = savedUsername ?? '';
    });
  }

  @override
  void dispose() {
    username.dispose();
    password.dispose();
    confirmation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AppScaffold(
    title: 'احراز هویت',
    body: loading
        ? const Center(child: CircularProgressIndicator())
        : ListView(
            children: [
              SwitchListTile.adaptive(
                title: const Text('فعال‌سازی احراز هویت'),
                subtitle: const Text(
                  'در ورود بعدی رمز عبور یا قفل دستگاه لازم است',
                ),
                value: enabled,
                onChanged: (value) {
                  setState(() {
                    enabled = value;
                    if (!value) biometric = false;
                  });
                },
              ),
              if (enabled) ...[
                const SizedBox(height: AppSpacing.md),
                AppTextField(controller: username, label: 'نام کاربری'),
                const SizedBox(height: AppSpacing.md),
                AppTextField(
                  controller: password,
                  label: 'رمز عبور جدید',
                  obscureText: true,
                ),
                const SizedBox(height: AppSpacing.md),
                AppTextField(
                  controller: confirmation,
                  label: 'تکرار رمز عبور',
                  obscureText: true,
                ),
                SwitchListTile.adaptive(
                  title: const Text('ورود با چهره، اثر انگشت یا الگوی قفل'),
                  value: biometric,
                  onChanged: _toggleBiometric,
                ),
              ],
              if (error != null)
                Text(error!, style: const TextStyle(color: Colors.red)),
              const SizedBox(height: AppSpacing.lg),
              AppButton(
                label: saving ? 'در حال ذخیره...' : 'ذخیره تنظیمات',
                onPressed: saving ? null : _save,
              ),
            ],
          ),
  );

  Future<void> _save() async {
    if (saving) return;
    setState(() {
      error = null;
      saving = true;
    });
    final service = ref.read(authServiceProvider);
    if (!enabled) {
      await service.disable();
    } else if (username.text.trim().length < 3) {
      setState(() {
        error = 'نام کاربری باید حداقل ۳ حرف باشد.';
        saving = false;
      });
      return;
    } else if (password.text.isNotEmpty &&
        (password.text.length < 4 || password.text != confirmation.text)) {
      setState(() {
        error = 'رمز عبور باید حداقل ۴ حرف باشد و تکرار آن یکسان باشد.';
        saving = false;
      });
      return;
    } else if (password.text.isEmpty && !await service.hasPassword) {
      setState(() {
        error = 'برای فعال‌سازی، رمز عبور را وارد کنید.';
        saving = false;
      });
      return;
    } else {
      if (biometric && !await service.biometricAvailable) {
        setState(() {
          error = 'قفل چهره، اثر انگشت یا الگوی دستگاه در دسترس نیست.';
          saving = false;
        });
        return;
      }
      await service.configure(
        username: username.text,
        password: password.text,
        biometric: biometric,
      );
    }
    if (mounted) Navigator.pop(context);
  }

  Future<void> _toggleBiometric(bool value) async {
    if (!value) {
      setState(() => biometric = false);
      return;
    }

    final service = ref.read(authServiceProvider);
    setState(() => error = null);
    if (!await service.biometricAvailable) {
      if (!mounted) return;
      setState(() {
        biometric = false;
        error = 'ابتدا قفل صفحه یا اثر انگشت دستگاه را فعال کنید.';
      });
      return;
    }

    try {
      final verified = await service.authenticateBiometric();
      if (!mounted) return;
      setState(() {
        biometric = verified;
        if (!verified) error = 'احراز هویت لغو شد.';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        biometric = false;
        error = 'احراز هویت دستگاه در دسترس نیست.';
      });
    }
  }
}
