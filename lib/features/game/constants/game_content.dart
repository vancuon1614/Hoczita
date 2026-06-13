import 'dart:math';
import '../models/game_question.dart';

class VocabItem {
  final String en;
  final String vi;
  final String category;

  const VocabItem(this.en, this.vi, this.category);
}

class GameContent {
  static final Random _random = Random();

  // The 120 vocabulary items divided into 12 topics (10 items each)
  static const List<VocabItem> allVocab = [
    // 1. animals
    VocabItem('Dog', 'Con chó', 'animals'),
    VocabItem('Cat', 'Con mèo', 'animals'),
    VocabItem('Lion', 'Sư tử', 'animals'),
    VocabItem('Elephant', 'Con voi', 'animals'),
    VocabItem('Monkey', 'Con khỉ', 'animals'),
    VocabItem('Rabbit', 'Con thỏ', 'animals'),
    VocabItem('Bear', 'Con gấu', 'animals'),
    VocabItem('Tiger', 'Con hổ', 'animals'),
    VocabItem('Sheep', 'Con cừu', 'animals'),
    VocabItem('Pig', 'Con lợn', 'animals'),

    // 2. fruits
    VocabItem('Apple', 'Quả táo', 'fruits'),
    VocabItem('Banana', 'Quả chuối', 'fruits'),
    VocabItem('Orange', 'Quả cam', 'fruits'),
    VocabItem('Watermelon', 'Dưa hấu', 'fruits'),
    VocabItem('Strawberry', 'Dâu tây', 'fruits'),
    VocabItem('Grape', 'Quả nho', 'fruits'),
    VocabItem('Mango', 'Quả xoài', 'fruits'),
    VocabItem('Pineapple', 'Quả dứa', 'fruits'),
    VocabItem('Peach', 'Quả đào', 'fruits'),
    VocabItem('Cherry', 'Quả anh đào', 'fruits'),

    // 3. vegatable
    VocabItem('Carrot', 'Củ cà rốt', 'vegatable'),
    VocabItem('Tomato', 'Quả cà chua', 'vegatable'),
    VocabItem('Potato', 'Củ khoai tây', 'vegatable'),
    VocabItem('Corn', 'Bắp ngô', 'vegatable'),
    VocabItem('Broccoli', 'Súp lơ xanh', 'vegatable'),
    VocabItem('Pumpkin', 'Quả bí ngô', 'vegatable'),
    VocabItem('Onion', 'Củ hành tây', 'vegatable'),
    VocabItem('Cucumber', 'Quả dưa chuột', 'vegatable'),
    VocabItem('Mushroom', 'Cây nấm', 'vegatable'),
    VocabItem('Pea', 'Hạt đậu Hà Lan', 'vegatable'),

    // 4. Transportation
    VocabItem('Car', 'Ô tô', 'Transportation'),
    VocabItem('Airplane', 'Máy bay', 'Transportation'),
    VocabItem('Train', 'Tàu hỏa', 'Transportation'),
    VocabItem('Bicycle', 'Xe đạp', 'Transportation'),
    VocabItem('Ship', 'Tàu thủy', 'Transportation'),
    VocabItem('Helicopter', 'Trực thăng', 'Transportation'),
    VocabItem('Bus', 'Xe buýt', 'Transportation'),
    VocabItem('Truck', 'Xe tải', 'Transportation'),
    VocabItem('Rocket', 'Tên lửa', 'Transportation'),
    VocabItem('Motorbike', 'Xe máy', 'Transportation'),

    // 5. school
    VocabItem('Book', 'Quyển sách', 'school'),
    VocabItem('Pen', 'Bút mực', 'school'),
    VocabItem('Pencil', 'Bút chì', 'school'),
    VocabItem('Backpack', 'Balo', 'school'),
    VocabItem('Eraser', 'Cục tẩy', 'school'),
    VocabItem('Ruler', 'Thước kẻ', 'school'),
    VocabItem('Scissors', 'Kéo thủ công', 'school'),
    VocabItem('Globe', 'Quả địa cầu', 'school'),
    VocabItem('Desk', 'Bàn học', 'school'),
    VocabItem('Chair', 'Ghế ngồi', 'school'),

    // 6. home
    VocabItem('Sofa', 'Ghế sofa', 'home'),
    VocabItem('Bed', 'Giường ngủ', 'home'),
    VocabItem('Table', 'Bàn tròn', 'home'),
    VocabItem('Lamp', 'Đèn ngủ', 'home'),
    VocabItem('Clock', 'Đồng hồ', 'home'),
    VocabItem('Key', 'Chìa khóa', 'home'),
    VocabItem('Cup', 'Cốc nước', 'home'),
    VocabItem('Door', 'Cửa ra vào', 'home'),
    VocabItem('Window', 'Cửa sổ', 'home'),
    VocabItem('Mirror', 'Cái gương', 'home'),

    // 7. nature
    VocabItem('Sun', 'Mặt trời', 'nature'),
    VocabItem('Moon', 'Mặt trăng', 'nature'),
    VocabItem('Star', 'Ngôi sao', 'nature'),
    VocabItem('Cloud', 'Đám mây', 'nature'),
    VocabItem('Rainbow', 'Cầu vồng', 'nature'),
    VocabItem('Tree', 'Cây xanh', 'nature'),
    VocabItem('Flower', 'Bông hoa', 'nature'),
    VocabItem('Rain', 'Mưa', 'nature'),
    VocabItem('Snow', 'Tuyết', 'nature'),
    VocabItem('Wind', 'Gió', 'nature'),

    // 8. space
    VocabItem('Astronaut', 'Phi hành gia', 'space'),
    VocabItem('Spaceship', 'Tàu vũ trụ', 'space'),
    VocabItem('Earth', 'Trái Đất', 'space'),
    VocabItem('Mars', 'Sao Hỏa', 'space'),
    VocabItem('Rover', 'Xe tự hành vũ trụ', 'space'),
    VocabItem('UFO', 'Đĩa bay', 'space'),
    VocabItem('Telescope', 'Kính thiên văn', 'space'),
    VocabItem('Satellite', 'Vệ tinh', 'space'),
    VocabItem('Meteor', 'Sao băng', 'space'),
    VocabItem('Spacesuit', 'Bộ đồ phi hành', 'space'),

    // 9. sea
    VocabItem('Fish', 'Con cá', 'sea'),
    VocabItem('Shark', 'Cá mập', 'sea'),
    VocabItem('Whale', 'Cá voi', 'sea'),
    VocabItem('Dolphin', 'Cá heo', 'sea'),
    VocabItem('Octopus', 'Bạch tuộc', 'sea'),
    VocabItem('Crab', 'Con cua', 'sea'),
    VocabItem('Starfish', 'Sao biển', 'sea'),
    VocabItem('Turtle', 'Rùa biển', 'sea'),
    VocabItem('Seahorse', 'Cá ngựa', 'sea'),
    VocabItem('Jellyfish', 'Con sứa', 'sea'),

    // 10. toy
    VocabItem('Soccer', 'Bóng đá', 'toy'),
    VocabItem('Basketball', 'Bóng rổ', 'toy'),
    VocabItem('Kite', 'Cánh diều', 'toy'),
    VocabItem('Slide', 'Cầu trượt', 'toy'),
    VocabItem('Balloon', 'Bóng bay', 'toy'),
    VocabItem('Doll', 'Búp bê', 'toy'),
    VocabItem('Teddy', 'Gấu bông', 'toy'),
    VocabItem('Robot', 'Rô bốt đồ chơi', 'toy'),
    VocabItem('Yo-yo', 'Đồ chơi yo-yo', 'toy'),
    VocabItem('Swing', 'Xích đu', 'toy'),

    // 11. clothing
    VocabItem('Shirt', 'Áo thun', 'clothing'),
    VocabItem('Pants', 'Quần dài', 'clothing'),
    VocabItem('Dress', 'Váy liền', 'clothing'),
    VocabItem('Hat', 'Mũ', 'clothing'),
    VocabItem('Shoes', 'Giày', 'clothing'),
    VocabItem('Socks', 'Tất/Vớ', 'clothing'),
    VocabItem('Jacket', 'Áo khoác', 'clothing'),
    VocabItem('Glasses', 'Kính mắt', 'clothing'),
    VocabItem('Scarf', 'Khăn quàng', 'clothing'),
    VocabItem('Boots', 'Ủng', 'clothing'),

    // 12. food
    VocabItem('Bread', 'Bánh mì', 'food'),
    VocabItem('Milk', 'Sữa', 'food'),
    VocabItem('Ice cream', 'Kem', 'food'),
    VocabItem('Lollipop', 'Kẹo mút', 'food'),
    VocabItem('Cake', 'Bánh ngọt', 'food'),
    VocabItem('Pizza', 'Bánh pizza', 'food'),
    VocabItem('Egg', 'Quả trứng', 'food'),
    VocabItem('Cheese', 'Phô mai', 'food'),
    VocabItem('Burger', 'Hamburger', 'food'),
    VocabItem('Juice', 'Nước ép', 'food'),
  ];

  // Helper function to build Supabase URL mapping based on user's exact folder and filename casing
  static String getSupabaseImageUrl(VocabItem item) {
    // Encodes characters like space to %20, and appends .jpg extension
    final encodedFilename = Uri.encodeComponent('${item.en}.jpg');
    return 'https://sinqzsswmecneliyjfrg.supabase.co/storage/v1/object/public/game-assets/${item.category}/$encodedFilename';
  }

  // Helper to generate 3 wrong choices from the same category to make it educational
  static List<String> getWrongChoices(VocabItem correctItem, {required bool isEnglish}) {
    final sameCategoryItems = allVocab
        .where((item) => item.category == correctItem.category && item.en != correctItem.en)
        .toList();
    sameCategoryItems.shuffle();
    final selectedItems = sameCategoryItems.take(3).toList();
    return selectedItems.map((item) => isEnglish ? item.en : item.vi).toList();
  }

  // 1. Flashcard Speed Run Data Generator (using the new 120 vocabulary pool)
  static List<GameQuestion> getFlashcardQuestions() {
    final List<VocabItem> shuffled = List<VocabItem>.from(allVocab)..shuffle();
    final selected = shuffled.take(10).toList();

    return selected.map((item) {
      final String correct = item.vi;
      final List<String> wrongs = getWrongChoices(item, isEnglish: false);
      final List<String> choices = [correct, ...wrongs]..shuffle();
      
      return GameQuestion(
        prompt: 'Từ "${item.en}" trong tiếng Việt nghĩa là gì?',
        choices: choices,
        correctAnswer: correct,
      );
    }).toList();
  }

  // 2. Picture Guess Data Generator (using the new 120 vocabulary pool + Supabase URLs)
  static List<GameQuestion> getPictureGuessQuestions() {
    final List<VocabItem> shuffled = List<VocabItem>.from(allVocab)..shuffle();
    final selected = shuffled.take(10).toList();

    return selected.map((item) {
      final String correct = item.en;
      final List<String> wrongs = getWrongChoices(item, isEnglish: true);
      final List<String> choices = [correct, ...wrongs]..shuffle();
      final String imageUrl = getSupabaseImageUrl(item);
      
      return GameQuestion(
        prompt: 'Hình ảnh trên tương ứng với từ tiếng Anh nào?',
        visualAsset: imageUrl,
        choices: choices,
        correctAnswer: correct,
      );
    }).toList();
  }

  // 3. Fast Counting Data Generator
  static List<GameQuestion> getCountingQuestions() {
    final List<String> emojis = ['🍎', '⭐️', '🎈', '🍪', '🐝', '🐸', '🦁', '🍓', '🐶'];
    final List<GameQuestion> questions = [];

    for (int i = 0; i < 10; i++) {
      final String emoji = emojis[_random.nextInt(emojis.length)];
      final int count = _random.nextInt(8) + 3; // 3 to 10
      
      final String visualAsset = emoji * count;
      final String correct = count.toString();
      
      final Set<int> wrongs = {count};
      while (wrongs.length < 4) {
        int wrong = count + _random.nextInt(5) - 2; // -2 to +2
        if (wrong > 0) wrongs.add(wrong);
      }
      
      final List<String> choices = wrongs.map((e) => e.toString()).toList()..shuffle();

      questions.add(
        GameQuestion(
          prompt: 'Đếm nhanh xem có bao nhiêu vật thể?',
          visualAsset: visualAsset,
          choices: choices,
          correctAnswer: correct,
        ),
      );
    }

    return questions;
  }

  // 4. Math Ops (Tàu Hỏa Thêm Bớt) Data Generator
  static List<GameQuestion> getMathOpsQuestions() {
    final List<GameQuestion> questions = [];

    for (int i = 0; i < 10; i++) {
      final bool isAddition = _random.nextBool();
      late int num1;
      late int num2;
      late String op;
      late int result;

      if (isAddition) {
        op = '+';
        num1 = _random.nextInt(20) + 5; // 5 to 25
        num2 = _random.nextInt(15) + 1; // 1 to 15
        result = num1 + num2;
      } else {
        op = '-';
        num1 = _random.nextInt(30) + 10; // 10 to 40
        num2 = _random.nextInt(num1 - 2) + 1; // Avoid negative and 0
        result = num1 - num2;
      }

      final String correct = result.toString();
      
      final Set<int> wrongs = {result};
      while (wrongs.length < 4) {
        int wrong = result + _random.nextInt(9) - 4; // -4 to +4
        if (wrong >= 0) wrongs.add(wrong);
      }

      final List<String> choices = wrongs.map((e) => e.toString()).toList()..shuffle();

      questions.add(
        GameQuestion(
          prompt: 'Bé hãy tính nhanh kết quả của phép tính:',
          visualAsset: '$num1 $op $num2 = ?',
          choices: choices,
          correctAnswer: correct,
        ),
      );
    }

    return questions;
  }

  // 5. Left-Right Comparison Data Generator
  static List<GameQuestion> getComparisonQuestions() {
    final List<String> emojis = ['🍎', '⭐️', '🎈', '🍪', '🐝', '🐸', '🦁'];
    final List<GameQuestion> questions = [];

    for (int i = 0; i < 10; i++) {
      final String emoji = emojis[_random.nextInt(emojis.length)];
      final int leftCount = _random.nextInt(7) + 2; // 2 to 8
      
      int rightCount = _random.nextInt(7) + 2;
      while (rightCount == leftCount) {
        rightCount = _random.nextInt(7) + 2; // Make sure they are not equal
      }

      final String leftAsset = emoji * leftCount;
      final String rightAsset = emoji * rightCount;

      final String correct = leftCount > rightCount ? 'Bên trái' : 'Bên phải';
      final List<String> choices = ['Bên trái', 'Bên phải', 'Bằng nhau']..shuffle();

      questions.add(
        GameQuestion(
          prompt: 'Bên nào có số lượng nhiều hơn?',
          comparisonLeft: leftAsset,
          comparisonRight: rightAsset,
          choices: choices,
          correctAnswer: correct,
        ),
      );
    }

    return questions;
  }
}
