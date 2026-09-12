import 'package:flutter/material.dart';

enum DayCellState {
  checkedIn,
  missed,
  todayPending,
  todayDone,
  future,
}

class CheckinLogic {
  static DateTime normalize(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }

  static bool isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  static DayCellState resolveState(DateTime date, DateTime today, Set<DateTime> checkedDates, [bool? todayStatus]) {
    DateTime normDate = normalize(date);
    DateTime normToday = normalize(today);

    // Normalizing all checked dates for safety
    bool checked = checkedDates.any((d) => isSameDay(d, normDate));
    bool isToday = isSameDay(normDate, normToday);

    if (normDate.isAfter(normToday)) return DayCellState.future;
    if (isToday) {
      bool isDone = todayStatus ?? checked;
      return isDone ? DayCellState.todayDone : DayCellState.todayPending;
    }
    return checked ? DayCellState.checkedIn : DayCellState.missed;
  }

  static bool shouldPulse(DayCellState state) => state == DayCellState.todayPending;

  // Helpers for calendar
  static List<DateTime> getDaysInWeek(DateTime anyDayInWeek) {
    DateTime norm = normalize(anyDayInWeek);
    // 1 = Monday, 7 = Sunday
    int weekday = norm.weekday;
    DateTime monday = norm.subtract(Duration(days: weekday - 1));
    return List.generate(7, (index) => monday.add(Duration(days: index)));
  }

  static List<DateTime> getDaysInMonthGrid(DateTime month) {
    DateTime norm = normalize(DateTime(month.year, month.month, 1));
    int firstWeekday = norm.weekday; // 1 = Monday, 7 = Sunday
    
    // Calculate days to subtract to reach Monday
    DateTime firstDayOfGrid = norm.subtract(Duration(days: firstWeekday - 1));
    
    List<DateTime> days = [];
    // 42 days grid covers 6 weeks which fits any month
    for (int i = 0; i < 42; i++) {
      days.add(firstDayOfGrid.add(Duration(days: i)));
    }
    return days;
  }
}
