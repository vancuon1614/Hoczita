import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
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
    final hasCheckedIn = checkinState.hasCheckedInToday;
    final streak = CheckinLogic.calculateStreak(checkinState.checkedDates, _today);

    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: !hasCheckedIn ? const Color(0xFFFE9D00) : const Color(0xFFE0E3E6),
              width: !hasCheckedIn ? 2.5 : 1.5,
            ),
            boxShadow: [
              if (!hasCheckedIn)
                BoxShadow(
                  color: const Color(0xFFFE9D00).withValues(alpha: 0.25 * _pulseAnimation.value),
                  blurRadius: 14,
                  spreadRadius: 2,
                )
              else
                const BoxShadow(
                  color: Color(0x0D000000),
                  blurRadius: 12,
                  offset: Offset(0, 4),
                ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: child,
        );
      },
      child: Column(
        children: [
          // 1. Reminder / Celebration Banner
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: !hasCheckedIn ? const Color(0xFFFFF4E5) : const Color(0xFFECFDF5),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(22),
                topRight: Radius.circular(22),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  !hasCheckedIn ? Icons.notifications_active_rounded : Icons.check_circle_rounded,
                  color: !hasCheckedIn ? const Color(0xFFFE9D00) : const Color(0xFF00B460),
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    !hasCheckedIn
                        ? "🎯 Đừng quên 'check-in' lớp học hôm nay nhé!"
                        : "🎉 Bạn đã hoàn thành điểm danh hôm nay!",
                    style: GoogleFonts.baloo2(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: !hasCheckedIn ? const Color(0xFFD97706) : const Color(0xFF006D38),
                    ),
                  ),
                ),
              ],
            ),
          ),
          // 2. Body
          Padding(
            padding: const EdgeInsets.all(18.0),
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
                        color: const Color(0xFF191C1E),
                      ),
                    ),
                    GestureDetector(
                      onTap: () => _showMonthSheet(checkinState.checkedDates, hasCheckedIn),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF2F4F7),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: const Color(0xFFE0E3E6)),
                        ),
                        child: Row(
                          children: [
                            Text(
                              'Tháng ${_today.month}',
                              style: GoogleFonts.baloo2(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF3F4852),
                              ),
                            ),
                            const SizedBox(width: 4),
                            const Icon(Icons.calendar_month_rounded, color: Color(0xFF6F7883), size: 16),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                // 3. Weekly Tracker
                GestureDetector(
                  onTap: () => _showMonthSheet(checkinState.checkedDates, hasCheckedIn),
                  behavior: HitTestBehavior.opaque,
                  child: _buildWeeklyTracker(checkinState.checkedDates),
                ),
                const SizedBox(height: 18),
                // 4. Streak Box
                _buildStreakBox(hasCheckedIn, streak),
                const SizedBox(height: 18),
                // 5. Tactile 3D Action Button
                _buildPlayGameButton(hasCheckedIn),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStreakBox(bool hasCheckedIn, int streak) {
    if (!hasCheckedIn) {
      if (streak > 0) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF8F0),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFFDE68A)),
          ),
          child: Row(
            children: [
              const Icon(Icons.warning_amber_rounded, color: Color(0xFFD97706), size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '⚠️ Chuỗi $streak ngày sắp bị mất nếu không điểm danh hôm nay!',
                  style: GoogleFonts.baloo2(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFFB45309),
                  ),
                ),
              ),
            ],
          ),
        );
      } else {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF4E5),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFFED7AA)),
          ),
          child: Row(
            children: [
              const Icon(Icons.rocket_launch_rounded, color: Color(0xFFD97706), size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '🚀 Hãy điểm danh hôm nay để bắt đầu chuỗi học tập mới!',
                  style: GoogleFonts.baloo2(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFFB45309),
                  ),
                ),
              ),
            ],
          ),
        );
      }
    } else {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFFECFDF5),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFA7F3D0)),
        ),
        child: Row(
          children: [
            const Icon(Icons.local_fire_department_rounded, color: Color(0xFF059669), size: 22),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                '🔥 Tuyệt vời! Bạn đang duy trì chuỗi ${streak > 0 ? streak : 1} ngày học tập liên tiếp!',
                style: GoogleFonts.baloo2(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF065F46),
                ),
              ),
            ),
          ],
        ),
      );
    }
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
        margin: const EdgeInsets.symmetric(horizontal: 3),
        decoration: BoxDecoration(
          color: isDone ? const Color(0xFF00B460).withValues(alpha: 0.6) : const Color(0xFFE0E3E6),
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
        innerCell = _buildCircle(const Color(0xFF00B460), Icons.check_rounded, Colors.white);
        break;
      case DayCellState.todayDone:
        innerCell = _buildCircle(const Color(0xFF00B460), Icons.check_rounded, Colors.white);
        break;
      case DayCellState.missed:
        innerCell = _buildCircle(const Color(0xFFE0E3E6), Icons.close_rounded, const Color(0xFF6F7883));
        break;
      case DayCellState.todayPending:
        innerCell = _buildCircle(Colors.white, Icons.star_rounded, const Color(0xFFFE9D00), border: const Color(0xFFFE9D00));
        break;
      case DayCellState.future:
        innerCell = _buildCircle(const Color(0xFFF2F4F7), Icons.lock_outline_rounded, const Color(0xFFBEC7D4));
        break;
    }

    if (shouldPulse) {
      innerCell = ScaleTransition(
        scale: _pulseAnimation,
        child: Container(
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Color(0x50FE9D00),
                blurRadius: 10,
                offset: Offset(0, 2),
              )
            ],
          ),
          child: innerCell,
        ),
      );
    }

    // Label styling
    String displayLabel = label;
    Color labelColor = const Color(0xFF3F4852);
    if (state == DayCellState.todayPending) {
      labelColor = const Color(0xFFFE9D00);
      displayLabel = 'Hôm nay';
    } else if (state == DayCellState.todayDone) {
      labelColor = const Color(0xFF00B460);
      displayLabel = 'Hôm nay';
    } else if (state == DayCellState.future) {
      labelColor = const Color(0xFF6F7883);
    }

    return Column(
      children: [
        SizedBox(width: 44, height: 44, child: Center(child: innerCell)),
        const SizedBox(height: 5),
        Text(
          displayLabel,
          style: GoogleFonts.baloo2(
            fontSize: displayLabel == 'Hôm nay' ? 12 : 13.5,
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
        border: border != null ? Border.all(color: border, width: 3.5) : null,
      ),
      child: Icon(icon, color: iconColor, size: 20),
    );
  }

  Widget _buildPlayGameButton(bool hasCheckedIn) {
    if (hasCheckedIn) {
      return Container(
        height: 54,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(9999),
          gradient: const LinearGradient(
            colors: [Color(0xFF00B460), Color(0xFF008A4A)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
          boxShadow: const [
            BoxShadow(
              color: Color(0xFF006D38),
              offset: Offset(0, 3),
              blurRadius: 0,
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(9999),
            onTap: widget.onPlayGame,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.check_circle_rounded, color: Colors.white, size: 22),
                const SizedBox(width: 8),
                Text(
                  '✨ Đã Điểm Danh Hôm Nay (Chơi Lại)',
                  style: GoogleFonts.baloo2(
                    fontSize: 16.5,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Container(
      height: 56,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(9999),
        gradient: const LinearGradient(
          colors: [Color(0xFFFE9D00), Color(0xFFE08A00)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0xFFB26E00),
            offset: Offset(0, 4),
            blurRadius: 0,
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(9999),
          onTap: widget.onPlayGame,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.sports_esports_rounded, color: Colors.white, size: 24),
              const SizedBox(width: 8),
              Text(
                '🎮 Chơi Game Điểm Danh',
                style: GoogleFonts.baloo2(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
