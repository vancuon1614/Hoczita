import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _SpeechRequest {
  final String text;
  final String locale;
  _SpeechRequest(this.text, this.locale);
}

class TtsService {
  TtsService._();
  static final TtsService instance = TtsService._();

  static const String _prefKeyTtsEnabled = 'app_tts_reading_enabled';

  final FlutterTts _tts = FlutterTts();
  final List<_SpeechRequest> _queue = [];
  bool _initialized = false;

  final ValueNotifier<bool> isSpeakingNotifier = ValueNotifier(false);
  final ValueNotifier<bool> isEnabledNotifier = ValueNotifier<bool>(true);

  bool get isEnabled => isEnabledNotifier.value;

  Future<void> initPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getBool(_prefKeyTtsEnabled);
      if (saved != null) {
        isEnabledNotifier.value = saved;
      }
    } catch (e) {
      debugPrint('TTS initPreferences error: $e');
    }
  }

  Future<void> setEnabled(bool enabled) async {
    isEnabledNotifier.value = enabled;
    if (!enabled) {
      stopAll();
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_prefKeyTtsEnabled, enabled);
    } catch (e) {
      debugPrint('TTS setEnabled error: $e');
    }
  }

  DateTime _lastToggleTime = DateTime.fromMillisecondsSinceEpoch(0);
  DateTime _lastSpeakTime = DateTime.fromMillisecondsSinceEpoch(0);
  String? _lastSpokenText;

  Future<void> toggleEnabled() async {
    final now = DateTime.now();
    if (now.difference(_lastToggleTime).inMilliseconds < 450) {
      return;
    }
    _lastToggleTime = now;
    await setEnabled(!isEnabled);
  }

  Future<void> _ensureInit() async {
    if (_initialized) return;
    await initPreferences();
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

  Future<void> speakEnglish(String text, {bool forced = false}) {
    if (!isEnabled && !forced) return Future.value();
    return _enqueue(text, 'en-US');
  }

  Future<void> speakVietnamese(String text, {bool forced = false}) {
    if (!isEnabled && !forced) return Future.value();
    return _enqueue(text, 'vi-VN');
  }

  Future<void> _enqueue(String text, String locale) async {
    await _ensureInit();
    final now = DateTime.now();
    // Chống spam: Nếu vừa yêu cầu cùng 1 nội dung trong 450ms thì bỏ qua
    if (_lastSpokenText == text && now.difference(_lastSpeakTime).inMilliseconds < 450) {
      return;
    }
    _lastSpeakTime = now;
    _lastSpokenText = text;

    // Luôn dọn sạch hàng đợi cũ và dừng phát âm trước đó để không bị dồn ứ giọng đọc
    _queue.clear();
    try {
      await _tts.stop();
    } catch (_) {}

    _queue.add(_SpeechRequest(text, locale));
    _processNext();
  }

  Future<void> _processNext() async {
    if (_queue.isEmpty) {
      isSpeakingNotifier.value = false;
      return;
    }
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
    isSpeakingNotifier.value = false;
  }
}
