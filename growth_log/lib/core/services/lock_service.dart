import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';

/// Minimal key-value secret store so tests can swap in memory storage.
abstract class SecretStore {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
}

class SecureSecretStore implements SecretStore {
  SecureSecretStore([FlutterSecureStorage? storage])
      : _s = storage ?? const FlutterSecureStorage();
  final FlutterSecureStorage _s;

  @override
  Future<String?> read(String key) => _s.read(key: key);
  @override
  Future<void> write(String key, String value) =>
      _s.write(key: key, value: value);
  @override
  Future<void> delete(String key) => _s.delete(key: key);
}

class MemorySecretStore implements SecretStore {
  final _map = <String, String>{};
  @override
  Future<String?> read(String key) async => _map[key];
  @override
  Future<void> write(String key, String value) async => _map[key] = value;
  @override
  Future<void> delete(String key) async => _map.remove(key);
}

/// PIN + biometric app lock. The PIN is stored only as a salted,
/// stretched SHA-256 hash in the platform keychain/keystore.
class LockService {
  LockService({SecretStore? store, LocalAuthentication? auth})
      : _store = store ?? SecureSecretStore(),
        _auth = auth;

  static const pinLength = 4;
  static const maxAttempts = 5;
  static const cooldown = Duration(seconds: 30);
  static const _kHash = 'pin_hash';
  static const _kSalt = 'pin_salt';
  static const _iterations = 20000;

  final SecretStore _store;
  final LocalAuthentication? _auth;

  LocalAuthentication get _la => _auth ?? LocalAuthentication();

  Future<bool> hasPin() async => (await _store.read(_kHash)) != null;

  static bool isValidPin(String pin) =>
      pin.length == pinLength && RegExp(r'^\d+$').hasMatch(pin);

  Future<void> setPin(String pin) async {
    if (!isValidPin(pin)) throw ArgumentError('PIN must be $pinLength digits');
    final rnd = Random.secure();
    final salt = base64Encode(List<int>.generate(16, (_) => rnd.nextInt(256)));
    await _store.write(_kSalt, salt);
    await _store.write(_kHash, await _hashAsync(pin, salt));
  }

  Future<bool> verifyPin(String pin) async {
    final salt = await _store.read(_kSalt);
    final hash = await _store.read(_kHash);
    if (salt == null || hash == null) return false;
    return await _hashAsync(pin, salt) == hash;
  }

  Future<void> clearPin() async {
    await _store.delete(_kHash);
    await _store.delete(_kSalt);
  }

  /// Key stretching runs off the UI thread to avoid a dropped frame.
  static Future<String> _hashAsync(String pin, String salt) =>
      compute(_hashPair, [pin, salt]);

  static String _hashPair(List<String> args) => _hash(args[0], args[1]);

  static String _hash(String pin, String salt) {
    var bytes = utf8.encode('$salt:$pin');
    for (var i = 0; i < _iterations; i++) {
      bytes = Uint8List.fromList(sha256.convert(bytes).bytes);
    }
    return base64Encode(bytes);
  }

  Future<bool> biometricsAvailable() async {
    if (kIsWeb) return false;
    try {
      if (!await _la.isDeviceSupported()) return false;
      if (!await _la.canCheckBiometrics) return false;
      return (await _la.getAvailableBiometrics()).isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  Future<bool> authenticateBiometric() async {
    try {
      return await _la.authenticate(
        localizedReason: 'Unlock Growth Log',
        biometricOnly: true,
        persistAcrossBackgrounding: true,
      );
    } catch (e) {
      debugPrint('Biometric auth failed: $e');
      return false;
    }
  }
}
