import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hoczita_app/core/services/supabase_service.dart';

class CheckinState {
  final bool hasCheckedInToday;
  final Set<DateTime> checkedDates;
  final int? todayRank;
  final int? totalPlayersToday;

  CheckinState({
    this.hasCheckedInToday = false,
    this.checkedDates = const {},
    this.todayRank,
    this.totalPlayersToday,
  });
}

class CheckinNotifier extends Notifier<CheckinState> {
  @override
  CheckinState build() {
    // Initial empty state, then trigger a refresh
    Future.microtask(() => refreshStatus());
    return CheckinState();
  }

  void markTodayAsCompletedLocal({int? rank, int? totalPlayers}) {
    final today = DateTime.now();
    final todayTruncated = DateTime(today.year, today.month, today.day);
    final newDates = Set<DateTime>.from(state.checkedDates)..add(todayTruncated);
    state = CheckinState(
      hasCheckedInToday: true,
      checkedDates: newDates,
      todayRank: rank ?? state.todayRank,
      totalPlayersToday: totalPlayers ?? state.totalPlayersToday,
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
    
    int? rank = state.todayRank;
    int? totalPlayers = state.totalPlayersToday;
    if (hasCheckedIn) {
      final rankData = await SupabaseService.instance.getTodayUserRank();
      if (rankData != null) {
        rank = rankData['rank'] as int?;
        totalPlayers = rankData['totalPlayersToday'] as int?;
      }
    }
    
    state = CheckinState(
      hasCheckedInToday: hasCheckedIn,
      checkedDates: dates,
      todayRank: rank,
      totalPlayersToday: totalPlayers,
    );
  }
}

final checkinProvider = NotifierProvider<CheckinNotifier, CheckinState>(() {
  return CheckinNotifier();
});
