import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/app_theme.dart';
import '../../providers/checkin_provider.dart';
import '../checkin_celebration_banner.dart';
import 'checkin_logic.dart';
import 'month_checkin_sheet.dart';

class WeekCheckinRow extends ConsumerStatefulWidget {
  final VoidCallback onPlayGame;

  const WeekCheckinRow({
    super.key,
    required this.onPlayGame,
  });

  @override
  ConsumerState<WeekCheckinRow> createState() => _WeekCheckinRowState();
}

class _WeekCheckinRowState extends ConsumerState<WeekCheckinRow> with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  late DateTime _today;
  late List<DateTime> _weekDays;

  @override
  void initState() {
    super.initState();
    _initData();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  void _initData() {
    _today = DateTime.now();
    _today = DateTime(_today.year, _today.month, _today.day);
    int currentWeekday = _today.weekday;
    DateTime startOfWeek = _today.subtract(Duration(days: currentWeekday - 1));

    _weekDays = [];
    for (int i = 0; i < 7; i++) {
      _weekDays.add(startOfWeek.add(Duration(days: i)));
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  void _showMonthSheet(Set<DateTime> checkedDates, bool hasCheckedInToday) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => MonthCheckinSheet(
        checkedDates: checkedDates,
        today: _today,
        hasCheckedInToday: hasCheckedInToday,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Lắng nghe sự kiện điểm danh thành công để hiển thị popup
    ref.listen<CheckinState>(checkinProvider, (previous, next) {
      if (previous != null && !previous.hasCheckedInToday && next.hasCheckedInToday) {
        CheckinCelebrationBanner.show(context);
      }
    });

    final checkinState = ref.watch(checkinProvider);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.primary, width: 2),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.1),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          // Banner - tự ẩn khi đã điểm danh xong
          if (!checkinState.hasCheckedInToday)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: const BoxDecoration(
                color: AppColors.primaryLight,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(22),
                  topRight: Radius.circular(22),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.notifications_active_rounded, color: AppColors.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      "🎯 Đừng quên 'check-in' lớp học hôm nay nhé!",
                      style: GoogleFonts.baloo2(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          // Content
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Điểm Danh Hôm Nay',
                      style: GoogleFonts.baloo2(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    GestureDetector(
                      onTap: () => _showMonthSheet(checkinState.checkedDates, checkinState.hasCheckedInToday),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.background,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          children: [
                            Text(
                              'Tuần này',
                              style: GoogleFonts.baloo2(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textSecondary,
                              ),
                            ),
                            const Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.textSecondary, size: 18),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                GestureDetector(
                  onTap: () => _showMonthSheet(checkinState.checkedDates, checkinState.hasCheckedInToday),
                  behavior: HitTestBehavior.opaque,
                  child: _buildWeeklyTracker(checkinState.checkedDates),
                ),
                const SizedBox(height: 20),
                // TỰ ĐỘNG ẨN BANNER KHI ĐÃ CHECK-IN
                if (!checkinState.hasCheckedInToday) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.info.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.info.withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.rocket_launch_rounded, color: AppColors.info),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Hãy điểm danh hôm nay để bắt đầu chuỗi học tập mới!',
                            style: GoogleFonts.baloo2(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: AppColors.info,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
                _buildPlayGameButton(checkinState.hasCheckedInToday),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWeeklyTracker(Set<DateTime> checkedDates) {
    List<Widget> children = [];
    final labels = ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN'];
    
    for (int i = 0; i < 7; i++) {
      DayCellState state = CheckinLogic.resolveState(_weekDays[i], _today, checkedDates);
      children.add(_buildDayCell(labels[i], state));
      if (i < 6) {
        children.add(_buildLine(state));
      }
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: children,
    );
  }

  Widget _buildLine(DayCellState state) {
    bool isDone = state == DayCellState.checkedIn || state == DayCellState.todayDone;
    return Expanded(
      child: Container(
        height: 4,
        margin: const EdgeInsets.symmetric(horizontal: 4),
        decoration: BoxDecoration(
          color: isDone ? AppColors.success.withOpacity(0.5) : AppColors.border,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }

  Widget _buildDayCell(String label, DayCellState state) {
    bool shouldPulse = CheckinLogic.shouldPulse(state);
    
    Widget innerCell;
    switch (state) {
      case DayCellState.checkedIn:
      case DayCellState.todayDone:
        innerCell = _buildCircle(AppColors.success, Icons.check_rounded, Colors.white);
        break;
      case DayCellState.missed:
        innerCell = _buildCircle(AppColors.border, Icons.close_rounded, Colors.white);
        break;
      case DayCellState.todayPending:
        innerCell = _buildCircle(Colors.white, Icons.star_rounded, AppColors.primary, border: AppColors.primary);
        break;
      case DayCellState.future:
        innerCell = Opacity(
          opacity: 0.3,
          child: _buildCircle(AppColors.border, Icons.lock_outline_rounded, AppColors.textSecondary),
        );
        break;
    }

    if (shouldPulse) {
      innerCell = ScaleTransition(
        scale: _pulseAnimation,
        child: Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withOpacity(0.3),
                blurRadius: 8,
                offset: const Offset(0, 2),
              )
            ],
          ),
          child: innerCell,
        ),
      );
    }

    // Wrap label
    Color labelColor = AppColors.textSecondary;
    if (state == DayCellState.todayPending || state == DayCellState.todayDone) labelColor = AppColors.primary;
    if (state == DayCellState.future) labelColor = AppColors.textSecondary.withOpacity(0.3);

    return Column(
      children: [
        SizedBox(width: 48, height: 48, child: Center(child: innerCell)),
        const SizedBox(height: 4),
        Text(
          label,
          style: GoogleFonts.baloo2(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: labelColor,
          ),
        ),
      ],
    );
  }

  Widget _buildCircle(Color bgColor, IconData icon, Color iconColor, {Color? border}) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: bgColor,
        shape: BoxShape.circle,
        border: border != null ? Border.all(color: border, width: 3) : null,
      ),
      child: Icon(icon, color: iconColor, size: 20),
    );
  }

  Widget _buildPlayGameButton(bool hasCheckedIn) {
    if (hasCheckedIn) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: Colors.green,
          borderRadius: BorderRadius.circular(30),
        ),
        alignment: Alignment.center,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.check_circle_rounded, color: Colors.white),
            const SizedBox(width: 8),
            Text(
              'Đã Điểm Danh Hôm Nay',
              style: GoogleFonts.baloo2(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ],
        ),
      );
    }
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.5),
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ElevatedButton.icon(
        onPressed: widget.onPlayGame,
        icon: const Icon(Icons.sports_esports_rounded, color: Colors.white),
        label: Text(
          '🎮 Chơi Game Điểm Danh',
          style: GoogleFonts.baloo2(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
          ),
          elevation: 0,
        ),
      ),
    );
  }
}
