enum GameType {
  zip,
  wend,
}

class ZipStarThresholds {
  static const double parTimeMultiplier3Star = 1.0;
  static const double parTimeMultiplier2Star = 1.5;
  static const int maxHintFor3Star = 0;
}

class WendStarThresholds {
  static const int maxWrongFor3Star = 1;
  static const int maxHintFor3Star = 0;
  static const int maxWrongFor2Star = 4;
  static const int maxHintFor2Star = 1;
}

int resolveZipStarRating(Duration elapsedTime, Duration parTime, int hintUsedCount) {
  int stars = 1;
  if (elapsedTime <= parTime * ZipStarThresholds.parTimeMultiplier3Star) {
    stars = 3;
  } else if (elapsedTime <= parTime * ZipStarThresholds.parTimeMultiplier2Star) {
    stars = 2;
  }
  
  if (hintUsedCount > ZipStarThresholds.maxHintFor3Star) {
    stars = (stars - 1).clamp(1, 3);
  }
  
  return stars;
}

int resolveWendStarRating(int wrongAttempts, int hintUsedCount) {
  if (wrongAttempts <= WendStarThresholds.maxWrongFor3Star && 
      hintUsedCount <= WendStarThresholds.maxHintFor3Star) {
    return 3;
  }
  
  if (wrongAttempts <= WendStarThresholds.maxWrongFor2Star || 
      hintUsedCount <= WendStarThresholds.maxHintFor2Star) {
    return 2;
  }
  
  return 1;
}

String resolveReportTitle(int starCount) {
  switch (starCount) {
    case 3:
      return "Xuất Sắc!";
    case 2:
      return "Tốt Lắm!";
    case 1:
    default:
      return "Hoàn Thành!";
  }
}

String resolveReportSubtitle(GameType gameType) {
  switch (gameType) {
    case GameType.zip:
      return "Bạn đã nối đường thành công!";
    case GameType.wend:
      return "Bạn đã tìm ra tất cả các từ ẩn!";
  }
}
