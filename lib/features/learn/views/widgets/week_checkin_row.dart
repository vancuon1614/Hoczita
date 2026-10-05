import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../providers/checkin_provider.dart';
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
              color: !hasCheckedIn ? const Color(0xFF0047AB) : const Color(0xFFE0E3E6),
              width: !hasCheckedIn ? 2.5 : 1.5,
            ),
            boxShadow: [
              if (!hasCheckedIn)
                BoxShadow(
                  color: const Color(0xFF0047AB).withValues(alpha: 0.25 * _pulseAnimation.value),
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
          // 1. Reminder Banner (Chỉ hiển thị khi CHƯA điểm danh; khi đã điểm danh xong thì ẩn đi theo yêu cầu)
          if (!hasCheckedIn)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: const BoxDecoration(
                color: Color(0xFFEBF3FC),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(22),
                  topRight: Radius.circular(22),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.notifications_active_rounded,
                    color: Color(0xFF0047AB),
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      "🎯 Đừng quên 'check-in' lớp học hôm nay nhé!",
                      style: GoogleFonts.baloo2(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF0047AB),
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
                // 2. Rank Notice đặt ngay dưới chữ "Điểm Danh Hôm Nay"
                if (hasCheckedIn) ...[
                  const SizedBox(height: 12),
                  _buildTodayRankNotice(checkinState),
                ],
                const SizedBox(height: 18),
                // 3. Weekly Tracker
                GestureDetector(
                  onTap: () => _showMonthSheet(checkinState.checkedDates, hasCheckedIn),
                  behavior: HitTestBehavior.opaque,
                  child: _buildWeeklyTracker(checkinState.checkedDates),
                ),
                const SizedBox(height: 18),
                // 4. Streak Box
                _buildStreakBox(checkinState, streak),
                // 5. Tactile 3D Action Button (chỉ hiển thị khi chưa điểm danh)
                if (!hasCheckedIn) ...[
                  const SizedBox(height: 18),
                  _buildPlayGameButton(checkinState),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Banner xếp hạng đặt ngay dưới chữ "Điểm Danh Hôm Nay" (không có chữ duy trì chuỗi)
  Widget _buildTodayRankNotice(CheckinState checkinState) {
    final rank = checkinState.todayRank;
    String rankMsg;
    IconData rankIcon;
    Color bgColor = const Color(0xFFECFDF5);
    Color borderColor = const Color(0xFFA7F3D0);
    Color textColor = const Color(0xFF065F46);
    Color iconColor = const Color(0xFF047857);

    if (rank == 1) {
      rankMsg = '👑 Chúc mừng bạn đang đứng đầu bảng!';
      rankIcon = Icons.emoji_events_rounded;
    } else if (rank == 2 || rank == 3) {
      rankMsg = '✨ TUYỆT VỜI! BẠN ĐÃ VÀO TOP 3!';
      rankIcon = Icons.military_tech_rounded;
    } else if (rank != null && rank <= 10) {
      rankMsg = '🎯 Top 10 xuất sắc!';
      rankIcon = Icons.stars_rounded;
    } else if (rank != null && rank > 10) {
      // Thông báo khi out top 10 theo yêu cầu người dùng
      rankMsg = '🔥 CỐ LÊN! BẠN ĐANG TIẾN RẤT GẦN CÁC TOP ĐẦU.';
      rankIcon = Icons.local_fire_department_rounded;
      bgColor = const Color(0xFFFFF7ED);
      borderColor = const Color(0xFFFED7AA);
      textColor = const Color(0xFFC2410C);
      iconColor = const Color(0xFFEA580C);
    } else {
      rankMsg = '🎉 Bạn đã hoàn thành điểm danh hôm nay!';
      rankIcon = Icons.check_circle_rounded;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor, width: 1.5),
      ),
      child: Row(
        children: [
          Icon(rankIcon, color: iconColor, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              rankMsg,
              style: GoogleFonts.baloo2(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStreakBox(CheckinState checkinState, int streak) {
    final hasCheckedIn = checkinState.hasCheckedInToday;

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
            color: const Color(0xFFF0F5FF),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFCCE0FF)),
          ),
          child: Row(
            children: [
              const Icon(Icons.rocket_launch_rounded, color: Color(0xFF0047AB), size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '🚀 Hãy điểm danh hôm nay để bắt đầu chuỗi học tập mới!',
                  style: GoogleFonts.baloo2(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF003882),
                  ),
                ),
              ),
            ],
          ),
        );
      }
    } else {
      // Chuỗi nằm ở notice bên dưới đúng như yêu cầu:
      // "Bạn đã điểm danh hôm nay, hãy giữ vững phong độ với chuỗi x nhé !!!"
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
                '🔥 Bạn đã điểm danh hôm nay, hãy giữ vững phong độ với chuỗi ${streak > 0 ? streak : 1} ngày nhé !!!',
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
        innerCell = _buildCircle(Colors.white, Icons.star_rounded, const Color(0xFF0047AB), border: const Color(0xFF0047AB));
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
                color: Color(0x400047AB),
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
      labelColor = const Color(0xFF0047AB);
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

  Widget _buildPlayGameButton(CheckinState checkinState) {
    final hasCheckedIn = checkinState.hasCheckedInToday;

    if (hasCheckedIn) {
      return Container(
        height: 52,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(9999),
          color: const Color(0xFFECFDF5), // Xanh pastel êm dịu, không tương phản gắt
          border: Border.all(
            color: const Color(0xFFA7F3D0), // Viền xanh ngọc nhạt hài hoà
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(9999),
            onTap: () {
              // Tắt chức năng chơi tiếp để tránh chơi lại nhiều lần sau khi đã điểm danh
              ScaffoldMessenger.of(context).hideCurrentSnackBar();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'Bạn đã hoàn thành điểm danh hôm nay rồi nhé! Hẹn gặp lại ngày mai ✨',
                    style: GoogleFonts.baloo2(fontWeight: FontWeight.w600),
                  ),
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  duration: const Duration(seconds: 2),
                ),
              );
            },
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.check_circle_rounded, color: Color(0xFF047857), size: 22),
                const SizedBox(width: 8),
                Text(
                  '🎉 Bạn đã hoàn thành điểm danh hôm nay!',
                  style: GoogleFonts.baloo2(
                    fontSize: 15.5,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF047857), // Màu chữ xanh lục đậm sang trọng, tương phản vừa phải
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
          colors: [Color(0xFF0A58CA), Color(0xFF0047AB)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0xFF003380),
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
                'Chơi Game Điểm Danh',
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
