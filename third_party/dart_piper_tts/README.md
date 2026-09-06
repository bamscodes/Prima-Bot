# flutter_piper_tts

TTS in Dart (or Flutter) using Piper TTS models + audio player in one package.

All onnx models are run via https://crates.io/crates/ort.

Built-in phonemizer is done via neural g2p ipa phonemizer model obtained from https://huggingface.co/OpenVoiceOS/g2p-mbyt5-12l-ipa-childes-espeak-onnx. This is done to avoid dealing with espeak GPL3 license and keep this package's MIT license. You can also provide your own ipa phonemes via `speakFromPhonemes` to bypass phonemes generation.

Piper TTS models can be downloaded from https://huggingface.co/rhasspy/piper-voices/tree/main.

Audio playback is done using https://crates.io/crates/tinyaudio.

Dict based phonemization is supported via https://crates.io/crates/cmudict-fast and https://github.com/dmort27/epitran.rs.

## Usage

- Download Piper TTS model of your choice, make sure to also prepare the `*.onnx.json` file
- Make them available to the device file system, eg. copying from your asset bundle to device application support directory
```dart
  final directory = await getApplicationSupportDirectory();
  final modelPath = join(directory.path, 'en_US-hfc_female-medium.onnx');
  final configPath = join(directory.path, 'en_US-hfc_female-medium.onnx.json');

  final exists = await File(modelPath).exists();

  if (!exists) {
    final modelData = await rootBundle.load(
      'assets/en_US-hfc_female-medium.onnx',
    );
    List<int> bytes = modelData.buffer.asUint8List(
      modelData.offsetInBytes,
      modelData.lengthInBytes,
    );

    await File(modelPath).writeAsBytes(bytes, flush: true);

    final configData = await rootBundle.load(
      'assets/en_US-hfc_female-medium.onnx.json',
    );
    bytes = configData.buffer.asUint8List(
      configData.offsetInBytes,
      configData.lengthInBytes,
    );
    await File(configPath).writeAsBytes(bytes, flush: true);
  }
```
- The example below is using flutter_piper_tts
- Initialize the package
```dart
  final tts = await PiperTTS.create(modelPath: modelPath, configPath: configPath);
```
- Speak
```dart
  final text = "Hello world!";
  // by default will wait for spoken word to be completed
  await tts.speak(text, waitForCompletion: true);
  // fire and forget
  await tts.speak(text, waitForCompletion: false);
  // phonemization based on g2p mbyt5 model for the whole text/sentence, can be slow for long sentence
  await tts.speak(text, phonemizerStrategy: PhonemizerStrategy.neuralSentence);
  // same as above, but performed on every word instead, quite a bit faster, but will be missing the sentence context
  await tts.speak(text, phonemizerStrategy: PhonemizerStrategy.neuralWord);
  // phonemization using dict based with cmudict for english and epitran for the rest, with fallback of using neural based for words not found in dict
  await tts.speak(text, phonemizerStrategy: PhonemizerStrategy.dictionaryWithNeuralFallback);
  // same as above, but will omit any words not found
  await tts.speak(text, phonemizerStrategy: PhonemizerStrategy.dictionaryWithOmitUnknown);

```
- Pause
```dart
  await tts.pause();
```
- Resume
```dart
  await tts.resume();
```
- Stop
```dart
  await tts.stop();
```
- Dispose (should not be required, but just in case)
```dart
  await tts.dispose();
```

## Notes
- Currently does not support number and any fancy symbols, for workaround you can put "forty two" instead of "42" for example.
- Some phoneme generation can be incorrect especially on heteronym words like `wind` and `live`.


## Supported platforms
- Android
- iOS
- MacOS
- Windows and Linux (not tested)

## TODO
- Adjust speed (with change in pitch/not)
- Number support
- Add phoneme override map