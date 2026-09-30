import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';

class AuthService {
  AuthService({FlutterSecureStorage? storage, LocalAuthentication? localAuth})
    : storage =
          storage ??
          const FlutterSecureStorage(
            // Android can retain an encrypted preferences file after its
            // Keystore key has been invalidated (for example after restoring
            // app data or changing the device lock). In that case reads fail
            // with BadPaddingException. Authentication settings are
            // recoverable, so let the plugin clear the invalid secure store
            // and allow the app to start again.
            aOptions: AndroidOptions(resetOnError: true),
          ),
      localAuth = localAuth ?? LocalAuthentication();

  static const enabledKey = 'auth_enabled';
  static const biometricKey = 'auth_biometric';
  static const usernameKey = 'auth_username';
  static const passwordKey = 'auth_password';

  final FlutterSecureStorage storage;
  final LocalAuthentication localAuth;

  Future<bool> get enabled async =>
      (await storage.read(key: enabledKey)) == 'true';
  Future<bool> get biometricEnabled async =>
      (await storage.read(key: biometricKey)) == 'true';
  Future<String?> get username => storage.read(key: usernameKey);
  Future<bool> get hasPassword async =>
      (await storage.read(key: passwordKey))?.isNotEmpty ?? false;

  /// Returns whether the device can authenticate with a biometric or its
  /// configured device credential (PIN, password, or pattern).
  Future<bool> get biometricAvailable async {
    try {
      if (await localAuth.isDeviceSupported()) return true;
      return await localAuth.canCheckBiometrics &&
          (await localAuth.getAvailableBiometrics()).isNotEmpty;
    } on PlatformException {
      return false;
    }
  }

  Future<void> configure({
    required String username,
    String? password,
    required bool biometric,
  }) async {
    await storage.write(key: usernameKey, value: username.trim());
    if (password != null && password.isNotEmpty) {
      await storage.write(key: passwordKey, value: password);
    }
    await storage.write(key: biometricKey, value: biometric.toString());
    await storage.write(key: enabledKey, value: 'true');
  }

  Future<void> disable() async {
    await storage.delete(key: enabledKey);
    await storage.delete(key: biometricKey);
    await storage.delete(key: usernameKey);
    await storage.delete(key: passwordKey);
  }

  Future<bool> verifyCredentials(String username, String password) async =>
      username.trim() == await storage.read(key: usernameKey) &&
      password == await storage.read(key: passwordKey);

  Future<bool> authenticateBiometric() => localAuth.authenticate(
    localizedReason: 'برای ورود به مدیریت موجودی احراز هویت کنید',
    options: const AuthenticationOptions(
      biometricOnly: false,
      stickyAuth: true,
      useErrorDialogs: true,
      sensitiveTransaction: true,
    ),
  );
}
