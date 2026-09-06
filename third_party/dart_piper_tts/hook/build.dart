import 'dart:io';

import 'package:code_assets/code_assets.dart';
import 'package:hooks/hooks.dart';
import 'package:native_toolchain_rust/native_toolchain_rust.dart';

void main(List<String> args) async {
  await build(args, (input, output) async {
    if (input.config.code.targetOS == OS.windows) {
      stdout.write('Skipping Windows host build for Flutter unit tests.');
      return;
    }

    if (input.config.code.targetArchitecture == Architecture.x64 &&
        input.config.code.targetOS == OS.macOS) {
      stdout.write('Skipping intel mac, ort does not support it');
      return;
    }

    await const RustBuilder(
      assetName: 'src/ffi.g.dart',
    ).run(input: input, output: output);
  });
}
