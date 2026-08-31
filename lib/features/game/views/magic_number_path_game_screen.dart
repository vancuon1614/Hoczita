import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_theme.dart';

class MagicNumberPathGameScreen extends ConsumerStatefulWidget {
  const MagicNumberPathGameScreen({super.key});

  @override
  ConsumerState<MagicNumberPathGameScreen> createState() => _MagicNumberPathGameScreenState();
}

class _MagicNumberPathGameScreenState extends ConsumerState<MagicNumberPathGameScreen> {
  bool _showHowToPlay = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            _buildAppBar(),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                child: Column(
                  children: [
                    _buildGrid(),
                    const SizedBox(height: 24),
                    _buildActionButtons(),
                    const SizedBox(height: 24),
                    _buildHowToPlayCard(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_rounded, color: AppColors.textPrimary),
            onPressed: () => Navigator.pop(context),
          ),
          const Icon(Icons.access_time_rounded, size: 20, color: AppColors.textPrimary),
          const SizedBox(width: 4),
          Text(
            '0:02',
            style: GoogleFonts.baloo2(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          Expanded(
            child: Center(
              child: Text(
                'Đường Số Diệu Kỳ 🔢',
                style: GoogleFonts.baloo2(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
          ),
          TextButton(
            onPressed: () {},
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(color: Colors.grey.shade400),
              ),
            ),
            child: Text(
              'Đặt lại',
              style: GoogleFonts.baloo2(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
    );
  }

  Widget _buildGrid() {
    // Mockup 6x6 grid with walls and some numbers
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade300, width: 1.5),
      ),
      child: Stack(
        children: [
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 6,
              childAspectRatio: 1.0,
            ),
            itemCount: 36,
            itemBuilder: (context, index) {
              int row = index ~/ 6;
              int col = index % 6;

              // Mockup walls based on the wireframe (some random thick borders)
              bool hasTopWall = (row == 1 && col >= 1 && col <= 2) || (row == 1 && col >= 4 && col <= 5);
              bool hasLeftWall = (col == 1 && row >= 1 && row <= 4) || (col == 4 && row >= 1 && row <= 4);
              bool hasRightWall = (col == 2 && row >= 1 && row <= 4) || (col == 5 && row >= 1 && row <= 4);
              bool hasBottomWall = (row == 4 && col >= 1 && col <= 2) || (row == 4 && col >= 4 && col <= 5);

              // Mockup numbered circles
              int? number;
              if (row == 1 && col == 1) number = 1;
              if (row == 0 && col == 2) number = 4;
              if (row == 0 && col == 4) number = 6;
              if (row == 1 && col == 5) number = 8;
              if (row == 4 && col == 1) number = 2;
              if (row == 5 && col == 2) number = 3;
              if (row == 5 && col == 4) number = 5;
              if (row == 4 && col == 5) number = 7;

              // Mockup path background
              bool isPath = (row == 1 && col == 1); // Mock start of path

              return Container(
                decoration: BoxDecoration(
                  color: isPath ? Colors.purple.withOpacity(0.2) : Colors.transparent,
                  border: Border(
                    top: hasTopWall ? const BorderSide(color: Color(0xFF1E293B), width: 6) : BorderSide(color: Colors.grey.shade200, width: 1),
                    left: hasLeftWall ? const BorderSide(color: Color(0xFF1E293B), width: 6) : BorderSide(color: Colors.grey.shade200, width: 1),
                    right: hasRightWall ? const BorderSide(color: Color(0xFF1E293B), width: 6) : BorderSide(color: Colors.grey.shade200, width: 1),
                    bottom: hasBottomWall ? const BorderSide(color: Color(0xFF1E293B), width: 6) : BorderSide(color: Colors.grey.shade200, width: 1),
                  ),
                ),
                alignment: Alignment.center,
                child: number != null
                    ? Container(
                        width: 32,
                        height: 32,
                        decoration: const BoxDecoration(
                          color: Color(0xFF0F172A),
                          shape: BoxShape.circle,
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          number.toString(),
                          style: GoogleFonts.baloo2(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      )
                    : null,
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton(
            onPressed: null, // Disabled
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.grey.shade300,
              disabledBackgroundColor: Colors.grey.shade200,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30),
              ),
            ),
            child: Text(
              'Hoàn Tác',
              style: GoogleFonts.baloo2(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade500,
              ),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: OutlinedButton(
            onPressed: () {},
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              side: const BorderSide(color: AppColors.primary, width: 2),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30),
              ),
            ),
            child: Text(
              'Gợi Ý 💡',
              style: GoogleFonts.baloo2(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHowToPlayCard() {
    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: _showHowToPlay,
          onExpansionChanged: (val) {
            setState(() {
              _showHowToPlay = val;
            });
          },
          title: Text(
            'Cách chơi',
            style: GoogleFonts.baloo2(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 16.0, right: 16.0, bottom: 20.0),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _buildMiniCircle('1', Colors.purple),
                            Container(width: 12, height: 4, color: Colors.purple.withOpacity(0.5)),
                            _buildMiniCircle('2', Colors.pink),
                            Container(width: 12, height: 4, color: Colors.pink.withOpacity(0.5)),
                            _buildMiniCircle('3', Colors.orange),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Kết nối các dấu\nchấm theo thứ tự',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.nunito(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Column(
                      children: [
                        Icon(Icons.grid_on_rounded, size: 40, color: Colors.pink.shade300),
                        const SizedBox(height: 12),
                        Text(
                          'Điền vào từng ô',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.nunito(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMiniCircle(String text, Color color) {
    return Container(
      width: 20,
      height: 20,
      decoration: BoxDecoration(
        color: Colors.black87,
        shape: BoxShape.circle,
        border: Border.all(color: color, width: 2),
      ),
      alignment: Alignment.center,
      child: Text(
        text,
        style: GoogleFonts.baloo2(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
    );
  }
}
