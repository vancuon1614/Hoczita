class WordCompletionEntry {
  final String word;
  final int elapsedSeconds; // _secondsElapsed TẠI THỜI ĐIỂM giải xong từ này
  final bool viaHint;

  WordCompletionEntry({
    required this.word,
    required this.elapsedSeconds,
    required this.viaHint,
  });

  Map<String, dynamic> toJson() => {
        'word': word,
        'elapsed_seconds': elapsedSeconds,
        'via_hint': viaHint,
      };

  factory WordCompletionEntry.fromJson(Map<String, dynamic> json) =>
      WordCompletionEntry(
        word: json['word'] as String,
        elapsedSeconds: json['elapsed_seconds'] as int? ?? 0,
        viaHint: json['via_hint'] as bool? ?? false,
      );
}
