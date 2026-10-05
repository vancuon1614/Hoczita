import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flip_card/flip_card.dart';
import 'package:flutter_tts/flutter_tts.dart';

import '../services/advanced_vocab_api_service.dart';
import '../services/learning_progress_service.dart';
import 'widgets/gel_candy_icon.dart';

class AdvancedFlashcardScreen extends StatefulWidget {
  const AdvancedFlashcardScreen({super.key});

  @override
  State<AdvancedFlashcardScreen> createState() => _AdvancedFlashcardScreenState();
}

class _AdvancedFlashcardScreenState extends State<AdvancedFlashcardScreen> {
  late PageController _pageController;
  int _currentIndex = 0;
  final FlutterTts _flutterTts = FlutterTts();

  bool _isLoading = true;
  String? _errorMessage;
  List<AdvancedVocabItem> _allWords = [];
  List<AdvancedVocabItem> _filteredWords = [];
  String _selectedLevel = 'ALL';

  final List<String> _levels = ['ALL', 'A1', 'A2', 'B1', 'B2', 'C1'];

  @override
  void initState() {
    super.initState();
    _pageController = PageController(viewportFraction: 0.85);
    _initTts();
    _loadWords();
  }

  Future<void> _initTts() async {
    await _flutterTts.setLanguage("en-US");
    await _flutterTts.setSpeechRate(0.48);
    await _flutterTts.setVolume(1.0);
    await _flutterTts.setPitch(1.0);
  }

  Future<void> _speak(String text) async {
    await _flutterTts.speak(text);
  }

  Future<void> _loadWords({bool refresh = false}) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final items = await AdvancedVocabApiService.instance.fetchAdvancedVocab(forceRefresh: refresh);
      if (mounted) {
        setState(() {
          _allWords = items;
          _applyLevelFilter();
          _isLoading = false;
        });
        _recordCurrentWord();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Không thể tải danh sách từ vựng. Bạn hãy thử lại nhé!';
        });
      }
    }
  }

  void _applyLevelFilter() {
    if (_selectedLevel == 'ALL') {
      _filteredWords = List.from(_allWords);
    } else {
      _filteredWords = _allWords.where((w) => w.level == _selectedLevel).toList();
    }
    if (_filteredWords.isEmpty) {
      _filteredWords = List.from(_allWords);
    }
    _currentIndex = 0;
  }

  void _recordCurrentWord() {
    if (_filteredWords.isNotEmpty && _currentIndex < _filteredWords.length) {
      final current = _filteredWords[_currentIndex];
      LearningProgressService.instance.recordAdvancedVocabViewed(current.word);
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    _flutterTts.stop();
    super.dispose();
  }

  void _nextCard() {
    if (_currentIndex < _filteredWords.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _previousCard() {
    if (_currentIndex > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: Column(
          children: [
            Text(
              'Từ Điển & Ngữ Cảnh 📖',
              style: GoogleFonts.baloo2(
                color: const Color(0xFF0F172A),
                fontWeight: FontWeight.bold,
                fontSize: 21,
              ),
            ),
            Text(
              'Flashcard Nâng Cao (API Chuẩn)',
              style: GoogleFonts.baloo2(
                color: const Color(0xFF0284C7),
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ],
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFF0F172A)),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            tooltip: 'Tải lại',
            icon: const Icon(Icons.refresh_rounded, color: Color(0xFF0284C7)),
            onPressed: () => _loadWords(refresh: true),
          ),
        ],
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(strokeWidth: 3, color: Color(0xFF0284C7)),
                    SizedBox(height: 16),
                    Text('Đang tải kho từ vựng nâng cao...', style: TextStyle(color: Color(0xFF64748B))),
                  ],
                ),
              )
            : _errorMessage != null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.error_outline_rounded, color: Colors.amber, size: 54),
                          const SizedBox(height: 12),
                          Text(_errorMessage!, textAlign: TextAlign.center),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: () => _loadWords(refresh: true),
                            child: const Text('Thử lại'),
                          ),
                        ],
                      ),
                    ),
                  )
                : Column(
                    children: [
                      // Level Filter Selector Chips
                      SizedBox(
                        height: 44,
                        child: ListView.separated(
                          padding: const EdgeInsets.symmetric(horizontal: 18),
                          scrollDirection: Axis.horizontal,
                          itemCount: _levels.length,
                          separatorBuilder: (_, _) => const SizedBox(width: 8),
                          itemBuilder: (context, index) {
                            final lvl = _levels[index];
                            final isSelected = lvl == _selectedLevel;
                            return ChoiceChip(
                              label: Text(
                                lvl == 'ALL' ? '🌟 Tất Cả' : 'Cấp độ $lvl',
                                style: GoogleFonts.baloo2(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: isSelected ? Colors.white : const Color(0xFF334155),
                                ),
                              ),
                              selected: isSelected,
                              selectedColor: const Color(0xFF0284C7),
                              backgroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                                side: BorderSide(
                                  color: isSelected ? const Color(0xFF0284C7) : Colors.grey.shade300,
                                ),
                              ),
                              onSelected: (val) {
                                if (val) {
                                  setState(() {
                                    _selectedLevel = lvl;
                                    _applyLevelFilter();
                                  });
                                }
                              },
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Counter bar
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFFE0F2FE),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Text(
                                'Từ ${_currentIndex + 1} / ${_filteredWords.length}',
                                style: GoogleFonts.baloo2(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFF0369A1),
                                ),
                              ),
                            ),
                            Row(
                              children: [
                                const Icon(Icons.touch_app_rounded, color: Color(0xFF0284C7), size: 18),
                                const SizedBox(width: 4),
                                Text(
                                  'Chạm để xem câu ví dụ',
                                  style: GoogleFonts.baloo2(
                                    fontSize: 13,
                                    color: const Color(0xFF64748B),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Card Carousel
                      Expanded(
                        child: PageView.builder(
                          controller: _pageController,
                          onPageChanged: (index) {
                            setState(() {
                              _currentIndex = index;
                            });
                            _recordCurrentWord();
                          },
                          itemCount: _filteredWords.length,
                          itemBuilder: (context, index) {
                            final word = _filteredWords[index];
                            return AnimatedBuilder(
                              animation: _pageController,
                              builder: (context, child) {
                                double value = 1.0;
                                if (_pageController.position.haveDimensions) {
                                  value = _pageController.page! - index;
                                  value = (1 - (value.abs() * 0.2)).clamp(0.8, 1.0);
                                }
                                return Center(
                                  child: Transform.scale(
                                    scale: value,
                                    child: child,
                                  ),
                                );
                              },
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 12.0),
                                child: FlipCard(
                                  direction: FlipDirection.HORIZONTAL,
                                  front: _buildCardFront(word),
                                  back: _buildCardBack(word),
                                ),
                              ),
                            );
                          },
                        ),
                      ),

                      // Bottom Nav Controls
                      Padding(
                        padding: const EdgeInsets.all(20.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            IconButton(
                              onPressed: _currentIndex > 0 ? _previousCard : null,
                              icon: const Icon(Icons.arrow_circle_left_rounded),
                              iconSize: 52,
                              color: _currentIndex > 0 ? const Color(0xFF0284C7) : Colors.grey.shade300,
                            ),
                            Text(
                              'Học liên tục tự do 🚀',
                              style: GoogleFonts.baloo2(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF64748B),
                              ),
                            ),
                            IconButton(
                              onPressed: _currentIndex < _filteredWords.length - 1 ? _nextCard : null,
                              icon: const Icon(Icons.arrow_circle_right_rounded),
                              iconSize: 52,
                              color: _currentIndex < _filteredWords.length - 1
                                  ? const Color(0xFF0284C7)
                                  : Colors.grey.shade300,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
      ),
    );
  }

  Widget _buildCardFront(AdvancedVocabItem item) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(32),
        boxShadow: const [
          BoxShadow(
            color: Color(0x140284C7),
            blurRadius: 20,
            offset: Offset(0, 10),
          ),
        ],
        border: Border.all(
          color: const Color(0xFFBAE6FD),
          width: 2,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Level Badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFE0F2FE),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFF7DD3FC)),
              ),
              child: Text(
                '⭐ CẤP ĐỘ ${item.level}',
                style: GoogleFonts.baloo2(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF0369A1),
                  letterSpacing: 0.5,
                ),
              ),
            ),
            const SizedBox(height: 20),

            // English Word
            Text(
              item.word,
              textAlign: TextAlign.center,
              style: GoogleFonts.baloo2(
                fontSize: 44,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 8),

            // IPA Transcription & Audio
            if (item.transcription.isNotEmpty)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    item.transcription,
                    style: GoogleFonts.nunito(
                      fontSize: 22,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF0284C7),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () => _speak(item.word),
                    child: GelCandyBadge.blue(
                      icon: const Icon(Icons.volume_up_rounded, color: Colors.white),
                      size: 40,
                    ),
                  ),
                ],
              ),
            const SizedBox(height: 24),

            // English definition if available
            if (item.description.isNotEmpty)
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Text(
                  '"${item.description}"',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.nunito(
                    fontSize: 14.5,
                    fontStyle: FontStyle.italic,
                    color: const Color(0xFF475569),
                  ),
                ),
              ),
            const SizedBox(height: 20),

            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.flip_camera_android_rounded, size: 16, color: Color(0xFF94A3B8)),
                const SizedBox(width: 6),
                Text(
                  'Lật mặt sau để xem nghĩa tiếng Việt & ví dụ',
                  style: GoogleFonts.baloo2(
                    fontSize: 12.5,
                    color: const Color(0xFF94A3B8),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCardBack(AdvancedVocabItem item) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFF0284C7),
        borderRadius: BorderRadius.circular(32),
        boxShadow: const [
          BoxShadow(
            color: Color(0x330284C7),
            blurRadius: 20,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(22.0),
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Word & Pronounce
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    item.word,
                    style: GoogleFonts.baloo2(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () => _speak(item.word),
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.25),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.volume_up_rounded, color: Colors.white, size: 22),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Vietnamese Meaning Highlight Box
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x20000000),
                      blurRadius: 8,
                      offset: Offset(0, 3),
                    ),
                  ],
                ),
                child: Text(
                  item.viWord,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.baloo2(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF0369A1),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Example Sentence Box with Speaker
              if (item.example.isNotEmpty) ...[
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.format_quote_rounded, color: Colors.white, size: 20),
                              const SizedBox(width: 4),
                              Text(
                                'Câu ví dụ mẫu:',
                                style: GoogleFonts.baloo2(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white.withValues(alpha: 0.9),
                                ),
                              ),
                            ],
                          ),
                          InkWell(
                            onTap: () => _speak(item.example),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.25),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.volume_up_rounded, color: Colors.white, size: 14),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Nghe cả câu',
                                    style: GoogleFonts.baloo2(fontSize: 11, color: Colors.white, fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        item.example,
                        style: GoogleFonts.nunito(
                          fontSize: 14.5,
                          color: Colors.white,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],

              // Vietnamese Definition if available
              if (item.viDescription.isNotEmpty)
                Text(
                  '💡 ${item.viDescription}',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.baloo2(
                    fontSize: 13,
                    color: Colors.white.withValues(alpha: 0.85),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
