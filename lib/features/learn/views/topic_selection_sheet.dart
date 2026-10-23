import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'random_flashcard_screen.dart';
import '../../game/constants/game_content.dart';

class FlashcardTopicItem {
  final String? category; // null = all
  final String title;
  final String emoji;
  final Color primaryColor;
  final List<Color> gradient;
  final int count;

  const FlashcardTopicItem({
    required this.category,
    required this.title,
    required this.emoji,
    required this.primaryColor,
    required this.gradient,
    required this.count,
  });
}

class TopicSelectionSheet extends StatefulWidget {
  const TopicSelectionSheet({super.key});

  static const List<FlashcardTopicItem> topics = [
    FlashcardTopicItem(
      category: null,
      title: 'Tất Cả Chủ Đề',
      emoji: '🌟',
      primaryColor: Color(0xFF6366F1),
      gradient: [Color(0xFF818CF8), Color(0xFF6366F1), Color(0xFF3730A3)],
      count: 120,
    ),
    FlashcardTopicItem(
      category: 'animal',
      title: 'Động Vật',
      emoji: '🐶',
      primaryColor: Color(0xFF3B82F6),
      gradient: [Color(0xFF60A5FA), Color(0xFF2563EB), Color(0xFF1D4ED8)],
      count: 10,
    ),
    FlashcardTopicItem(
      category: 'fruits',
      title: 'Hoa Quả',
      emoji: '🍎',
      primaryColor: Color(0xFF16A34A),
      gradient: [Color(0xFF86EFAC), Color(0xFF22C55E), Color(0xFF15803D)],
      count: 10,
    ),
    FlashcardTopicItem(
      category: 'vegatable',
      title: 'Rau Củ',
      emoji: '🥕',
      primaryColor: Color(0xFF0284C7),
      gradient: [Color(0xFF7DD3FC), Color(0xFF0284C7), Color(0xFF0369A1)],
      count: 10,
    ),
    FlashcardTopicItem(
      category: 'Transportation',
      title: 'Phương Tiện',
      emoji: '🚗',
      primaryColor: Color(0xFF6366F1),
      gradient: [Color(0xFF818CF8), Color(0xFF4F46E5), Color(0xFF3730A3)],
      count: 10,
    ),
    FlashcardTopicItem(
      category: 'school',
      title: 'Trường Học',
      emoji: '🎒',
      primaryColor: Color(0xFFD97706),
      gradient: [Color(0xFFFDE047), Color(0xFFEAB308), Color(0xFFA16207)],
      count: 10,
    ),
    FlashcardTopicItem(
      category: 'home',
      title: 'Gia Đình',
      emoji: '🏠',
      primaryColor: Color(0xFF059669),
      gradient: [Color(0xFF6EE7B7), Color(0xFF10B981), Color(0xFF047857)],
      count: 10,
    ),
    FlashcardTopicItem(
      category: 'nature',
      title: 'Thiên Nhiên',
      emoji: '🌈',
      primaryColor: Color(0xFF0284C7),
      gradient: [Color(0xFF7DD3FC), Color(0xFF0EA5E9), Color(0xFF0369A1)],
      count: 10,
    ),
    FlashcardTopicItem(
      category: 'space',
      title: 'Vũ Trụ',
      emoji: '🚀',
      primaryColor: Color(0xFF7E22CE),
      gradient: [Color(0xFFA855F7), Color(0xFF7E22CE), Color(0xFF3B0764)],
      count: 10,
    ),
    FlashcardTopicItem(
      category: 'sea',
      title: 'Đại Dương',
      emoji: '🐠',
      primaryColor: Color(0xFF0EA5E9),
      gradient: [Color(0xFF38BDF8), Color(0xFF0284C7), Color(0xFF0F172A)],
      count: 10,
    ),
    FlashcardTopicItem(
      category: 'toy',
      title: 'Đồ Chơi',
      emoji: '🧸',
      primaryColor: Color(0xFFDB2777),
      gradient: [Color(0xFFF472B6), Color(0xFFDB2777), Color(0xFF9D174D)],
      count: 10,
    ),
    FlashcardTopicItem(
      category: 'clothing',
      title: 'Trang Phục',
      emoji: '👕',
      primaryColor: Color(0xFFEA580C),
      gradient: [Color(0xFFFDBA74), Color(0xFFF97316), Color(0xFFC2410C)],
      count: 10,
    ),
    FlashcardTopicItem(
      category: 'food',
      title: 'Món Ăn',
      emoji: '🍕',
      primaryColor: Color(0xFF0284C7),
      gradient: [Color(0xFF38BDF8), Color(0xFF0284C7), Color(0xFF075985)],
      count: 10,
    ),
  ];

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const TopicSelectionSheet(),
    );
  }

  @override
  State<TopicSelectionSheet> createState() => _TopicSelectionSheetState();
}

class _TopicSelectionSheetState extends State<TopicSelectionSheet> {
  int? _selectedTopicIndex;
  bool _isNavigating = false;

  int _getTopicCount(FlashcardTopicItem item) {
    if (item.category == null) return GameContent.allVocab.length;
    final cat = item.category!.trim().toLowerCase();
    final count = GameContent.allVocab
        .where((v) => v.category.trim().toLowerCase() == cat)
        .length;
    return count > 0 ? count : item.count;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.82,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        boxShadow: [
          BoxShadow(
            color: Color(0x33000000),
            blurRadius: 24,
            offset: Offset(0, -6),
          ),
        ],
      ),
      child: Column(
        children: [
          // Drag handle
          const SizedBox(height: 12),
          Container(
            width: 48,
            height: 5,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          const SizedBox(height: 14),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Khám Phá Từ Vựng 🎨',
                      style: GoogleFonts.baloo2(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF1E293B),
                      ),
                    ),
                    Text(
                      'Chọn chủ đề bạn muốn luyện tập hôm nay nha!',
                      style: GoogleFonts.baloo2(
                        fontSize: 13,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded, size: 26),
                  color: Colors.grey.shade600,
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          const Divider(height: 1),

          // Topic Grid
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.all(18),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 14,
                mainAxisSpacing: 14,
                childAspectRatio: 1.52,
              ),
              itemCount: TopicSelectionSheet.topics.length,
              itemBuilder: (_, index) {
                final item = TopicSelectionSheet.topics[index];
                final bool isAll = item.category == null;
                final bool isSelected = _selectedTopicIndex == index;
                final bool hasSelection = _selectedTopicIndex != null;
                final bool isOther = hasSelection && !isSelected;

                return AnimatedOpacity(
                  duration: const Duration(milliseconds: 220),
                  opacity: isOther ? 0.40 : 1.0,
                  child: AnimatedScale(
                    scale: isSelected ? 1.05 : 1.0,
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.easeOutBack,
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(20),
                        onTap: () async {
                          if (_isNavigating) return;
                          Feedback.forTap(this.context);

                          setState(() {
                            _selectedTopicIndex = index;
                            _isNavigating = true;
                          });

                          // Giữ hiệu ứng phát sáng trong 380ms để người dùng thấy rõ chủ đề đã chọn trước khi chuyển màn hình
                          await Future.delayed(const Duration(milliseconds: 380));
                          if (!mounted) return;

                          Navigator.pop(this.context); // close sheet
                          Navigator.push(
                            this.context,
                            MaterialPageRoute(
                              builder: (context) => RandomFlashcardScreen(
                                selectedCategory: item.category,
                                topicTitle: item.title,
                              ),
                            ),
                          );
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 220),
                          curve: Curves.easeOutCubic,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? Colors.white
                                : (isAll ? const Color(0xFFFFFBEB) : const Color(0xFFF8FAFC)),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: isSelected
                                  ? item.primaryColor
                                  : (isAll ? const Color(0xFFFDE68A) : const Color(0xFFE2E8F0)),
                              width: isSelected ? 2.5 : 1.2,
                            ),
                            boxShadow: [
                              if (isSelected) ...[
                                // Hiệu ứng phát sáng rực rỡ (Luminous Glow) khi ấn chọn
                                BoxShadow(
                                  color: item.primaryColor.withValues(alpha: 0.55),
                                  blurRadius: 18,
                                  spreadRadius: 2.5,
                                  offset: const Offset(0, 4),
                                ),
                                BoxShadow(
                                  color: item.primaryColor.withValues(alpha: 0.30),
                                  blurRadius: 6,
                                  spreadRadius: 1,
                                ),
                              ] else ...[
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.04),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ],
                          ),
                          child: Row(
                            children: [
                              // Biểu tượng chủ thể không khung viền, tự do và sắc nét 100% như Hình 1
                              SizedBox(
                                width: 44,
                                height: 44,
                                child: Center(
                                  child: Text(
                                    item.emoji,
                                    style: const TextStyle(fontSize: 32),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      item.title,
                                      style: GoogleFonts.baloo2(
                                        fontSize: 14.5,
                                        fontWeight: isSelected ? FontWeight.w800 : FontWeight.bold,
                                        color: isSelected ? item.primaryColor : const Color(0xFF1E293B),
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    AnimatedContainer(
                                      duration: const Duration(milliseconds: 200),
                                      margin: const EdgeInsets.only(top: 2),
                                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1.5),
                                      decoration: BoxDecoration(
                                        color: isSelected
                                            ? item.primaryColor
                                            : item.primaryColor.withValues(alpha: 0.12),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        '${_getTopicCount(item)} thẻ',
                                        style: GoogleFonts.baloo2(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color: isSelected ? Colors.white : item.primaryColor,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (isSelected)
                                Icon(
                                  Icons.check_circle_rounded,
                                  color: item.primaryColor,
                                  size: 20,
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
