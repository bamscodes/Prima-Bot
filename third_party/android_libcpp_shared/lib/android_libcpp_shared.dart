import 'dart:ffi' as ffi;
import 'dart:io' show Platform;

final class _AndroidLibcppShared {
  static final instance = _AndroidLibcppShared._();
  final ffi.DynamicLibrary? lib;
  _AndroidLibcppShared._()
    : lib = Platform.isAndroid
          ? ffi.DynamicLibrary.open('libc++_shared.so')
          : null;
}

/// If the current platform is Android, returns a [ffi.DynamicLibrary] for
/// `libc++_shared.so` from the Android system libraries.
/// For all other platforms, returns `null`.
ffi.DynamicLibrary? get libCppShared => _AndroidLibcppShared.instance.lib;
