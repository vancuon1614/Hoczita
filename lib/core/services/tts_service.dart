import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

class _SpeechRequest {
  final String text;
  final String locale;
  _SpeechRequest(this.text, this.locale);
}

class TtsService {
  TtsService._();
  static final TtsService instance = TtsService._();

  final FlutterTts _tts = FlutterTts();
  final List<_SpeechRequest> _queue = [];
  bool _isProcessing = false;
  bool _initialized = false;

  final ValueNotifier<bool> isSpeakingNotifier = ValueNotifier(false);

  Future<void> _ensureInit() async {
    if (_initialized) return;
    try {
      await _tts.setSpeechRate(0.42); // Chậm hơn mặc định, phù hợp học sinh tiểu học
      await _tts.setPitch(1.0);
      _tts.setCompletionHandler(_onDone);
      _tts.setErrorHandler((msg) {
        debugPrint('TTS error: $msg');
        _onDone();
      });
      _tts.setCancelHandler(_onDone);
      _initialized = true;
    } catch (e) {
      debugPrint('TTS init error: $e');
    }
  }

  Future<void> speakEnglish(String text) => _enqueue(text, 'en-US');
  Future<void> speakVietnamese(String text) => _enqueue(text, 'vi-VN');

  Future<void> _enqueue(String text, String locale) async {
    await _ensureInit();
    _queue.add(_SpeechRequest(text, locale));
    if (!_isProcessing) _processNext();
  }

  Future<void> _processNext() async {
    if (_queue.isEmpty) {
      _isProcessing = false;
      isSpeakingNotifier.value = false;
      return;
    }
    _isProcessing = true;
    isSpeakingNotifier.value = true;

    final req = _queue.removeAt(0);

    try {
      final available = await _tts.isLanguageAvailable(req.locale);
      if (available != 1 && available != true) {
        debugPrint('Ngôn ngữ ${req.locale} không khả dụng trên máy này, thử phát âm.');
      } else {
        await _tts.setLanguage(req.locale);
      }
      await _tts.speak(req.text);
    } catch (e) {
      debugPrint('TTS speak error: $e');
      _onDone();
    }
  }

  void _onDone() {
    _processNext(); // Xử lý tiếp phần tử kế trong queue (nếu có)
  }

  Future<void> stopAll() async {
    _queue.clear();
    try {
      await _tts.stop();
    } catch (_) {}
    _isProcessing = false;
    isSpeakingNotifier.value = false;
  }
}
