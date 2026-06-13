class GameQuestion {
  final String prompt;            // Câu hỏi hoặc từ khóa chính (ví dụ: 'Apple' hoặc 'Có bao nhiêu...')
  final String? visualAsset;      // Hình ảnh hoặc emoji (ví dụ: '🍎', hoặc URL ảnh)
  final String? comparisonLeft;   // Dành cho game so sánh (nội dung bên trái)
  final String? comparisonRight;  // Dành cho game so sánh (nội dung bên phải)
  final List<String> choices;     // 4 lựa chọn trả lời
  final String correctAnswer;     // Đáp án chính xác

  const GameQuestion({
    required this.prompt,
    this.visualAsset,
    this.comparisonLeft,
    this.comparisonRight,
    required this.choices,
    required this.correctAnswer,
  });
}
