import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hoczita_app/core/services/supabase_service.dart';

class CheckinState {
  final bool hasCheckedInToday;
  final Set<DateTime> checkedDates;

  CheckinState({
    this.hasCheckedInToday = false,
    this.checkedDates = const {},
  });
}

class CheckinNotifier extends Notifier<CheckinState> {
  @override
  CheckinState build() {
    // Initial empty state, then trigger a refresh
    Future.microtask(() => refreshStatus());
    return CheckinState();
  }

  void markTodayAsCompletedLocal() {
    final today = DateTime.now();
    final todayTruncated = DateTime(today.year, today.month, today.day);
    final newDates = Set<DateTime>.from(state.checkedDates)..add(todayTruncated);
    state = CheckinState(
      hasCheckedInToday: true,
      checkedDates: newDates,
    );
  }

  Future<void> refreshStatus() async {
    final dates = await SupabaseService.instance.getCheckinDates();
    final today = DateTime.now();
    
    bool hasCheckedIn = dates.any((d) => 
      d.year == today.year && 
      d.month == today.month && 
      d.day == today.day
    );
    
    state = CheckinState(
      hasCheckedInToday: hasCheckedIn,
      checkedDates: dates,
    );
  }
}

final checkinProvider = NotifierProvider<CheckinNotifier, CheckinState>(() {
  return CheckinNotifier();
});
