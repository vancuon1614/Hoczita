import 'lib/features/game/utils/math_crossword_generator.dart' as gen;

void main() {
  print('Generating easy puzzle...');
  final easy = gen.generatePuzzle(gen.Difficulty.easy);
  print('Easy generated: ${easy.gridSize}');

  print('Generating medium puzzle...');
  final medium = gen.generatePuzzle(gen.Difficulty.medium);
  print('Medium generated: ${medium.gridSize}');

  print('Generating hard puzzle...');
  try {
    final hard = gen.generatePuzzle(gen.Difficulty.hard);
    print('Hard generated: ${hard.gridSize}');
  } catch (e, st) {
    print('Error generating hard: $e');
    print(st);
  }
}
