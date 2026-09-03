import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/app_theme.dart';
import 'checkin_logic.dart';

class MonthCheckinSheet extends StatefulWidget {
  final Set<DateTime> checkedDates;
  final DateTime today;

  const MonthCheckinSheet({
    super.key,
    required this.checkedDates,
    required this.today,
  });

  @override
  State<MonthCheckinSheet> createState() => _MonthCheckinSheetState();
}

class _MonthCheckinSheetState extends State<MonthCheckinSheet> with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  late List<DateTime> _monthDays;
  late DateTime _currentMonth;

  @override
  void initState() {
    super.initState();
    _currentMonth = DateTime(widget.today.year, widget.today.month, 1);
    _monthDays = CheckinLogic.getDaysInMonthGrid(_currentMonth);
    
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(30),
          topRight: Radius.circular(30),
        ),
      ),
      padding: const EdgeInsets.only(top: 16, bottom: 32, left: 24, right: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            width: 40,
            height: 5,
            decoration: BoxDecoration(
              color: AppColors.border,
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Tháng ${_currentMonth.month}, ${_currentMonth.year}',
            style: GoogleFonts.baloo2(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 24),
          _buildDaysOfWeek(),
          const SizedBox(height: 12),
          _buildGrid(),
        ],
      ),
    );
  }

  Widget _buildDaysOfWeek() {
    final labels = ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN'];
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: labels.map((l) => SizedBox(
        width: 36,
        child: Text(
          l,
          textAlign: TextAlign.center,
          style: GoogleFonts.baloo2(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: AppColors.textSecondary,
          ),
        ),
      )).toList(),
    );
  }

  Widget _buildGrid() {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 7,
        mainAxisSpacing: 12,
        crossAxisSpacing: 4,
        childAspectRatio: 1.0,
      ),
      itemCount: 42,
      itemBuilder: (context, index) {
        DateTime date = _monthDays[index];
        bool isCurrentMonth = date.month == _currentMonth.month;
        
        // If not current month, just show faded
        if (!isCurrentMonth) {
          return Opacity(
            opacity: 0.3,
            child: Center(
              child: Text(
                '${date.day}',
                style: GoogleFonts.baloo2(
                  fontSize: 16,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          );
        }

        DayCellState state = CheckinLogic.resolveState(date, widget.today, widget.checkedDates);
        return _buildMonthCell(date, state);
      },
    );
  }

  Widget _buildMonthCell(DateTime date, DayCellState state) {
    bool shouldPulse = CheckinLogic.shouldPulse(state);
    
    Widget innerContent;
    BoxDecoration decoration;
    
    if (state == DayCellState.checkedIn || state == DayCellState.todayDone) {
      decoration = const BoxDecoration(color: AppColors.success, shape: BoxShape.circle);
      innerContent = Text(
        '${date.day}',
        style: GoogleFonts.baloo2(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
      );
    } else if (state == DayCellState.missed) {
      decoration = BoxDecoration(color: AppColors.border.withOpacity(0.5), shape: BoxShape.circle);
      innerContent = Text(
        '${date.day}',
        style: GoogleFonts.baloo2(color: AppColors.textSecondary, fontSize: 16),
      );
    } else if (state == DayCellState.todayPending) {
      decoration = BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.primary, width: 2),
      );
      innerContent = Text(
        '${date.day}',
        style: GoogleFonts.baloo2(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 16),
      );
    } else {
      // future
      decoration = const BoxDecoration();
      innerContent = Opacity(
        opacity: 0.5,
        child: Text(
          '${date.day}',
          style: GoogleFonts.baloo2(color: AppColors.textPrimary, fontSize: 16),
        ),
      );
    }

    Widget cell = Container(
      decoration: decoration,
      alignment: Alignment.center,
      child: innerContent,
    );

    if (shouldPulse) {
      cell = ScaleTransition(
        scale: _pulseAnimation,
        child: Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withOpacity(0.3),
                blurRadius: 8,
              )
            ],
          ),
          child: cell,
        ),
      );
    }

    return Center(child: SizedBox(width: 40, height: 40, child: cell));
  }
}
