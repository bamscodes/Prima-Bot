import 'dart:async';
import 'dart:ffi';
import 'dart:isolate';

import 'package:dart_piper_tts/src/ffi.g.dart' as g;
import 'package:ffi/ffi.dart';

/// A text-to-speech engine powered by [Piper TTS](https://github.com/rhasspy/piper).
///
/// Synthesizes speech from text or phonemes and streams audio through the
/// native audio player. Instances are tied to a specific voice model and
/// must be created with [PiperTTS.create] after calling [PiperTTS.init].
///
/// ```dart
/// PiperTTS.init();
/// final tts = PiperTTS.create(
///   modelPath: 'path/to/model.onnx',
///   configPath: 'path/to/model.onnx.json',
/// );
/// await tts.speak('Hello, world!');
/// tts.dispose();
/// ```
class PiperTTS implements Finalizable {
  PiperTTS._(this._instancePtr) {
    _finalizer.attach(this, _instancePtr.cast(), detach: this);
  }

  static final StreamController<int> _completionStreamController =
      StreamController<int>.broadcast();

  static RawReceivePort? _receivePort;

  static NativeCallable<Void Function(Int64)>? _nativeCompletionCallback;

  static int _nextCompletionId = 0;

  static final NativeFinalizer _finalizer = NativeFinalizer(
    Native.addressOf<NativeFunction<Void Function(Pointer<Void>)>>(
      g.dispose,
    ).cast(),
  );

  final Pointer<Void> _instancePtr;

  static void _onNativeComplete(int port) {
    _receivePort!.sendPort.send(port);
  }

  /// Initializes the native audio engine and registers the playback completion
  /// callback.
  ///
  /// Must be called once before [create]. Subsequent calls are no-ops — the
  /// underlying native resources are only initialized on the first call.
  ///
  /// Set [kDebugMode] to `false` in production builds to suppress verbose
  /// native logging.
  static void init({bool kDebugMode = true}) {
    _receivePort ??= RawReceivePort(_completionStreamController.add);

    _nativeCompletionCallback ??= NativeCallable<Void Function(Int64)>.listener(
      _onNativeComplete,
    );

    final result = g.init(
      _nativeCompletionCallback!.nativeFunction,
      kDebugMode,
    );
    final g.FFIResponse(:error_message) = result;
    _checkIfError(error_message);
  }

  /// Creates a [PiperTTS] instance loaded with the given voice model.
  ///
  /// [modelPath] is the path to the ONNX model file and [configPath] is the
  /// path to its accompanying JSON configuration file. Both files must exist
  /// and be readable at the time of this call.
  ///
  /// Throws an [Exception] if the native layer fails to load the model.
  ///
  /// [PiperTTS.init] must be called before this method.
  // ignore: prefer_constructors_over_static_methods
  static PiperTTS create({
    required String modelPath,
    required String configPath,
  }) {
    return using((arena) {
      final result = g.create_instance(
        modelPath.toNativeUtf8(allocator: arena).cast(),
        configPath.toNativeUtf8(allocator: arena).cast(),
      );
      final g.FFIResponse(:ptr, :error_message) = result;
      _checkIfError(error_message);
      return PiperTTS._(ptr);
    });
  }

  /// Synthesizes [text] and plays it through the audio device.
  ///
  /// When [waitForCompletion] is `true` (the default), the returned [Future]
  /// completes only after the last audio sample has finished playing. Set it
  /// to `false` to return as soon as synthesis has been enqueued, allowing
  /// audio to play in the background.
  ///
  /// [phonemizerStrategy] controls how the text is converted to phonemes
  /// before synthesis. Defaults to [PhonemizerStrategy.neuralWord].
  ///
  /// [phonemeChunkSize] controls the split size of phonemes. Defaults to 80.
  /// Maximum value is 255 (max of u8). Setting to 0 will disable chunking.
  ///
  /// Throws an [Exception] if the native layer reports an error.
  Future<void> speak(
    String text, {
    bool waitForCompletion = true,
    PhonemizerStrategy phonemizerStrategy = PhonemizerStrategy.neuralWord,
    int phonemeChunkSize = 80,
  }) async {
    return using((arena) {
      final id = _nextCompletionId++;
      final playbackComplete = _completionStreamController.stream
          .firstWhere((id_) => id_ == id)
          .then((_) {});
      final result = g.speak(
        _instancePtr,
        text.toNativeUtf8(allocator: arena).cast(),
        false,
        id,
        phonemizerStrategy.native.toNativeUtf8(allocator: arena).cast(),
        phonemeChunkSize,
      );
      final g.FFIResponse(:error_message) = result;
      _checkIfError(error_message);
      if (waitForCompletion) return playbackComplete;
    });
  }

  /// Synthesizes pre-computed [phonemes] and plays them through the audio
  /// device, bypassing the text-to-phoneme step.
  ///
  /// Useful when phonemes have already been resolved externally or cached, as
  /// it reduces synthesis latency.
  ///
  /// When [waitForCompletion] is `true` (the default), the returned [Future]
  /// completes only after the last audio sample has finished playing. Set it
  /// to `false` to return as soon as synthesis has been enqueued.
  ///
  /// [phonemeChunkSize] controls the split size of phonemes. Defaults to 80.
  /// Maximum value is 255 (max of u8). Setting to 0 will disable chunking.
  ///
  /// Throws an [Exception] if the native layer reports an error.
  Future<void> speakFromPhonemes({
    required String phonemes,
    bool waitForCompletion = true,
    int phonemeChunkSize = 80,
  }) async {
    return using((arena) {
      final id = _nextCompletionId++;
      final playbackComplete = _completionStreamController.stream
          .firstWhere((id_) => id_ == id)
          .then((_) {});
      final result = g.speak(
        _instancePtr,
        phonemes.toNativeUtf8(allocator: arena).cast(),
        true,
        id,
        PhonemizerStrategy.neuralWord.native
            .toNativeUtf8(allocator: arena)
            .cast(),
        phonemeChunkSize,
      );
      final g.FFIResponse(:error_message) = result;
      _checkIfError(error_message);
      if (waitForCompletion) return playbackComplete;
    });
  }

  /// Pauses audio playback.
  ///
  /// Has no effect if playback is already paused. Call [resume] to continue
  /// from where playback stopped. Any audio already buffered is preserved.
  ///
  /// Throws an [Exception] if the native layer reports an error.
  void pause() {
    final result = g.pause(_instancePtr);
    final g.FFIResponse(:error_message) = result;
    _checkIfError(error_message);
  }

  /// Resumes playback after a [pause].
  ///
  /// Has no effect if playback is already active.
  ///
  /// Throws an [Exception] if the native layer reports an error.
  void resume() {
    final result = g.resume(_instancePtr);
    final g.FFIResponse(:error_message) = result;
    _checkIfError(error_message);
  }

  /// Stops playback and discards all buffered audio.
  ///
  /// Unlike [pause], buffered audio is drained and cannot be resumed.
  /// Any [speak] or [speakFromPhonemes] call that is waiting for completion
  /// will not receive its completion event for the discarded audio.
  ///
  /// Throws an [Exception] if the native layer reports an error.
  void stop() {
    final result = g.stop(_instancePtr);
    final g.FFIResponse(:error_message) = result;
    _checkIfError(error_message);
  }

  /// Releases the native resources held by this instance.
  ///
  /// After calling this method the instance must not be used again. This is
  /// called automatically by the [NativeFinalizer] when the object is garbage
  /// collected, but calling it explicitly allows resources to be freed
  /// deterministically.
  void dispose() {
    _finalizer.detach(this);
    g.dispose(_instancePtr);
  }
}

extension on Pointer<Char> {
  bool get isEmpty => this == nullptr || toDartString().isEmpty;

  bool get isNotEmpty => !isEmpty;

  String toDartString() => cast<Utf8>().toDartString();
}

/// Determines how input text is converted to phonemes before synthesis.
///
/// The choice of strategy trades off latency, accuracy, and behaviour on
/// unknown words. Neural strategies are slower but handle arbitrary text;
/// dictionary strategies are faster but may struggle with out-of-vocabulary
/// words.
enum PhonemizerStrategy {
  /// Converts entire sentences at once using a neural model.
  ///
  /// Produces the most natural prosody for long utterances, but has higher
  /// latency than [neuralWord] for short inputs.
  neuralSentence('neural_sentence'),

  /// Converts text word-by-word using a neural model.
  ///
  /// A good default: lower latency than [neuralSentence] while still
  /// handling arbitrary vocabulary.
  neuralWord('neural_word'),

  /// Looks up phonemes in a pronunciation dictionary, falling back to the
  /// neural model for unknown words.
  ///
  /// Faster than pure neural strategies for text that is well covered by
  /// the dictionary.
  dictionaryWithNeuralFallback('dict_neural'),

  /// Looks up phonemes in a pronunciation dictionary and silently omits any
  /// word that is not found.
  ///
  /// Fastest option, but unknown words are dropped entirely rather than
  /// approximated.
  dictionaryWithOmitUnknown('dict_omit');

  /// String value is used to pass to the native layer.
  final String native;

  /// Creates a [PhonemizerStrategy] from a string value.
  // ignore: sort_constructors_first
  const PhonemizerStrategy(this.native);
}

void _checkIfError(Pointer<Char> errorMessage) {
  if (errorMessage.isNotEmpty) {
    final message = errorMessage.toDartString();
    g.free_string(errorMessage);
    throw Exception(message);
  }
}
