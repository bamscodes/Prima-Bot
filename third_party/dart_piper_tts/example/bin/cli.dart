import 'dart:io';

import 'package:dart_piper_tts/dart_piper_tts.dart';

void main(List<String> arguments) {
  PiperTTS.init(kDebugMode: true);
  final tts = PiperTTS.create(
    configPath: "./en_US-hfc_female-medium.onnx.json",
    modelPath: "./en_US-hfc_female-medium.onnx",
  );
  tts.speak("Hello world!");
  sleep(Duration(seconds: 2));
}
