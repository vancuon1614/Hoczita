import 'dart:math';

enum MultiplicationLevel {
  easy, // 2 x 9 = ?
  medium, // ? x 9 = 18 hoặc 2 x ? = 18
  hard, // Bài toán đố thực tế
}

class MultiplicationQuestionOption {
  final int value;
  final String display; // e.g. "18" hoặc "4 cây"

  const MultiplicationQuestionOption({
    required this.value,
    required this.display,
  });
}

class MultiplicationQuestionModel {
  final int factorA;
  final int factorB;
  final int correctResult;
  final String correctDisplay;
  final String questionText;
  final String formulaHeader;
  final String ttsPrompt;
  final List<MultiplicationQuestionOption> options;
  final MultiplicationLevel level;

  const MultiplicationQuestionModel({
    required this.factorA,
    required this.factorB,
    required this.correctResult,
    required this.correctDisplay,
    required this.questionText,
    required this.formulaHeader,
    required this.ttsPrompt,
    required this.options,
    required this.level,
  });
}

class MultiplicationQuestionGenerator {
  static final Random _random = Random();

  /// Sinh danh sách 10 câu hỏi theo bảng và cấp độ đã chọn
  static List<MultiplicationQuestionModel> generateQuestions({
    required int tableNumber, // 0: tổng hợp, 2..9: bảng tương ứng
    required MultiplicationLevel level,
  }) {
    final List<MultiplicationQuestionModel> list = [];
    final List<int> multipliers = List.generate(10, (i) => i + 1)..shuffle(_random);

    for (int i = 0; i < 10; i++) {
      int a;
      int b;

      if (tableNumber == 0) {
        a = _random.nextInt(8) + 2; // 2..9
        b = _random.nextInt(10) + 1; // 1..10
      } else {
        a = tableNumber;
        b = multipliers[i];
      }

      final correctProduct = a * b;

      switch (level) {
        case MultiplicationLevel.easy:
          list.add(_generateEasyQuestion(a, b, correctProduct));
          break;
        case MultiplicationLevel.medium:
          list.add(_generateMediumQuestion(a, b, correctProduct));
          break;
        case MultiplicationLevel.hard:
          list.add(_generateHardQuestion(a, b, correctProduct));
          break;
      }
    }

    return list;
  }

  // ================= LEVEL 1: DỄ (2 x 9 = ?) =================
  static MultiplicationQuestionModel _generateEasyQuestion(int a, int b, int correct) {
    final Set<int> wrongOptions = {};
    final List<int> deltas = [-a, a, -1, 1, -2, 2, -10, 10, -5, 5];
    deltas.shuffle(_random);

    for (final d in deltas) {
      final val = correct + d;
      if (val > 0 && val != correct) {
        wrongOptions.add(val);
        if (wrongOptions.length == 3) break;
      }
    }

    while (wrongOptions.length < 3) {
      final fallback = (a * (_random.nextInt(10) + 1)) + (_random.nextBool() ? 1 : -1);
      if (fallback > 0 && fallback != correct) {
        wrongOptions.add(fallback);
      }
    }

    final allValues = [correct, ...wrongOptions]..shuffle(_random);
    final options = allValues
        .map((v) => MultiplicationQuestionOption(value: v, display: v.toString()))
        .toList();

    return MultiplicationQuestionModel(
      factorA: a,
      factorB: b,
      correctResult: correct,
      correctDisplay: correct.toString(),
      questionText: '$a × $b = ?',
      formulaHeader: 'BẢNG CỬU CHƯƠNG $a',
      ttsPrompt: '$a nhân $b bằng bao nhiêu?',
      options: options,
      level: MultiplicationLevel.easy,
    );
  }

  // ================= LEVEL 2: VỪA (? x 9 = 18 hoặc 2 x ? = 18) =================
  static MultiplicationQuestionModel _generateMediumQuestion(int a, int b, int correctProduct) {
    final bool findFirst = _random.nextBool(); // true: ? x b = c, false: a x ? = c
    final int targetAnswer = findFirst ? a : b;
    final String formulaText = findFirst ? '? × $b = $correctProduct' : '$a × ? = $correctProduct';
    final String ttsText = findFirst
        ? 'Mấy nhân $b bằng $correctProduct?'
        : '$a nhân mấy bằng $correctProduct?';

    // Sinh 3 đáp án sai trong phạm vi 1..10
    final Set<int> wrongOptions = {};
    final List<int> candidates = List.generate(10, (i) => i + 1)..shuffle(_random);
    for (final c in candidates) {
      if (c != targetAnswer) {
        wrongOptions.add(c);
        if (wrongOptions.length == 3) break;
      }
    }

    final allValues = [targetAnswer, ...wrongOptions]..shuffle(_random);
    final options = allValues
        .map((v) => MultiplicationQuestionOption(value: v, display: v.toString()))
        .toList();

    return MultiplicationQuestionModel(
      factorA: a,
      factorB: b,
      correctResult: targetAnswer,
      correctDisplay: targetAnswer.toString(),
      questionText: formulaText,
      formulaHeader: 'ĐIỀN VÀO CHỖ TRỐNG',
      ttsPrompt: ttsText,
      options: options,
      level: MultiplicationLevel.medium,
    );
  }

  // ================= LEVEL 3: THỰC TẾ (BÀI TOÁN ĐỐ ĐỜI SỐNG) =================
  static MultiplicationQuestionModel _generateHardQuestion(int a, int b, int product) {
    // Kho kịch bản toán đố phong phú
    final List<Map<String, dynamic>> templates = [];

    // Mẫu 1: Mua kẹo / giá tiền (Tìm số lượng mua được c : a = b)
    templates.add({
      'question': 'Em có ${product}k, mỗi cây kẹo giá ${a}k. Hỏi em mua được bao nhiêu cây kẹo?',
      'tts': 'Em có $product nghìn, mỗi cây kẹo giá $a nghìn. Hỏi em mua được bao nhiêu cây kẹo?',
      'target': b,
      'unit': 'cây',
      'wrongDeltas': [-1, 1, 2, -2],
    });

    // Mẫu 2: Giá tiền tổng (Nhân a x b = product)
    templates.add({
      'question': 'Mỗi que kem giá ${a}k. Nam mua $b que kem. Hỏi Nam phải trả bao nhiêu tiền?',
      'tts': 'Mỗi que kem giá $a nghìn. Nam mua $b que kem. Hỏi Nam phải trả bao nhiêu tiền?',
      'target': product,
      'unit': 'k',
      'wrongDeltas': [-a, a, -10, 10, -5],
    });

    // Mẫu 3: Đóng gói hộp bánh (Nhân a x b = product)
    templates.add({
      'question': 'Một hộp bánh có $a chiếc. Mẹ mua $b hộp như vậy. Hỏi có tất cả bao nhiêu chiếc bánh?',
      'tts': 'Một hộp bánh có $a chiếc. Mẹ mua $b hộp như vậy. Hỏi có tất cả bao nhiêu chiếc bánh?',
      'target': product,
      'unit': 'chiếc',
      'wrongDeltas': [-a, a, -2, 2, -5],
    });

    // Mẫu 4: Chia đều bánh vào hộp (c : a = b)
    templates.add({
      'question': 'Có $product chiếc bánh chia đều vào các hộp, mỗi hộp $a chiếc. Hỏi có bao nhiêu hộp bánh?',
      'tts': 'Có $product chiếc bánh chia đều vào các hộp, mỗi hộp $a chiếc. Hỏi có bao nhiêu hộp bánh?',
      'target': b,
      'unit': 'hộp',
      'wrongDeltas': [-1, 1, 2, -2],
    });

    // Mẫu 5: Thưởng vở học sinh (c : b = a)
    templates.add({
      'question': 'Cô giáo có $product quyển vở thưởng đều cho $b bạn học sinh giỏi. Hỏi mỗi bạn được mấy quyển vở?',
      'tts': 'Cô giáo có $product quyển vở thưởng đều cho $b bạn học sinh giỏi. Hỏi mỗi bạn được mấy quyển vở?',
      'target': a,
      'unit': 'quyển',
      'wrongDeltas': [-1, 1, 2, -2],
    });

    // Mẫu 6: Xếp hàng học sinh (Nhân a x b = product)
    templates.add({
      'question': 'Mỗi hàng có $a bạn học sinh, có tất cả $b hàng. Hỏi có bao nhiêu bạn học sinh?',
      'tts': 'Mỗi hàng có $a bạn học sinh, có tất cả $b hàng. Hỏi có bao nhiêu bạn học sinh?',
      'target': product,
      'unit': 'bạn',
      'wrongDeltas': [-a, a, -2, 2, -10],
    });

    // Mẫu đặc thù theo con số
    if (a == 4 || b == 4) {
      final cars = a == 4 ? b : a;
      templates.add({
        'question': 'Mỗi chiếc ô tô có 4 bánh xe. Bãi đỗ xe có $cars chiếc ô tô. Hỏi có tất cả bao nhiêu bánh xe?',
        'tts': 'Mỗi chiếc ô tô có 4 bánh xe. Bãi đỗ xe có $cars chiếc ô tô. Hỏi có tất cả bao nhiêu bánh xe?',
        'target': 4 * cars,
        'unit': 'bánh',
        'wrongDeltas': [-4, 4, -2, 2],
      });
    }

    if (a == 2 || b == 2) {
      final rabbits = a == 2 ? b : a;
      templates.add({
        'question': 'Mỗi chú thỏ có 2 cái tai dài. Trong chuồng có $rabbits chú thỏ. Hỏi có bao nhiêu cái tai thỏ?',
        'tts': 'Mỗi chú thỏ có 2 cái tai dài. Trong chuồng có $rabbits chú thỏ. Hỏi có bao nhiêu cái tai thỏ?',
        'target': 2 * rabbits,
        'unit': 'cái tai',
        'wrongDeltas': [-2, 2, -1, 1],
      });
    }

    if (a == 7 || b == 7) {
      final weeks = a == 7 ? b : a;
      templates.add({
        'question': 'Một tuần lễ có 7 ngày. Bố đi công tác $weeks tuần lễ. Hỏi bố đi công tác bao nhiêu ngày?',
        'tts': 'Một tuần lễ có 7 ngày. Bố đi công tác $weeks tuần lễ. Hỏi bố đi công tác bao nhiêu ngày?',
        'target': 7 * weeks,
        'unit': 'ngày',
        'wrongDeltas': [-7, 7, -3, 3],
      });
    }

    if (a == 8 || b == 8) {
      final octo = a == 8 ? b : a;
      templates.add({
        'question': 'Mỗi con bạch tuộc có 8 cái vòi. Có $octo con bạch tuộc. Hỏi có tất cả bao nhiêu cái vòi?',
        'tts': 'Mỗi con bạch tuộc có 8 cái vòi. Có $octo con bạch tuộc. Hỏi có tất cả bao nhiêu cái vòi?',
        'target': 8 * octo,
        'unit': 'cái vòi',
        'wrongDeltas': [-8, 8, -4, 4],
      });
    }

    final chosen = templates[_random.nextInt(templates.length)];
    final int target = chosen['target'] as int;
    final String unit = chosen['unit'] as String;
    final List<int> deltas = (chosen['wrongDeltas'] as List<int>)..shuffle(_random);

    final Set<int> wrongOptions = {};
    for (final d in deltas) {
      final w = target + d;
      if (w > 0 && w != target) {
        wrongOptions.add(w);
        if (wrongOptions.length == 3) break;
      }
    }

    while (wrongOptions.length < 3) {
      final randW = target + (_random.nextInt(7) - 3);
      if (randW > 0 && randW != target) {
        wrongOptions.add(randW);
      }
    }

    final allValues = [target, ...wrongOptions]..shuffle(_random);
    final options = allValues.map((v) {
      return MultiplicationQuestionOption(
        value: v,
        display: unit.isNotEmpty ? '$v $unit' : v.toString(),
      );
    }).toList();

    return MultiplicationQuestionModel(
      factorA: a,
      factorB: b,
      correctResult: target,
      correctDisplay: unit.isNotEmpty ? '$target $unit' : target.toString(),
      questionText: chosen['question'] as String,
      formulaHeader: 'TOÁN ĐỐ THỰC TẾ 💡',
      ttsPrompt: chosen['tts'] as String,
      options: options,
      level: MultiplicationLevel.hard,
    );
  }
}
