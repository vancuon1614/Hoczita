import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/supabase_service.dart';

class HintQuotaState {
  final int remaining;
  final bool isLoading;

  HintQuotaState({this.remaining = 3, this.isLoading = true});

  HintQuotaState copyWith({int? remaining, bool? isLoading}) {
    return HintQuotaState(
      remaining: remaining ?? this.remaining,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

class HintQuotaNotifier extends Notifier<HintQuotaState> {
  @override
  HintQuotaState build() {
    fetchQuota();
    return HintQuotaState();
  }

  Future<void> fetchQuota() async {
    try {
      final userId = SupabaseService.instance.client.auth.currentUser?.id;
      if (userId == null) {
        state = state.copyWith(isLoading: false);
        return;
      }
      
      final today = DateTime.now().toIso8601String().split('T')[0];
      final data = await SupabaseService.instance.client
          .from('daily_hint_quota')
          .select('hints_remaining')
          .eq('user_id', userId)
          .eq('quota_date', today)
          .maybeSingle();

      if (data != null) {
        state = state.copyWith(remaining: data['hints_remaining'] as int, isLoading: false);
      } else {
        state = state.copyWith(remaining: 3, isLoading: false); // Default
      }
    } catch (e) {
      state = state.copyWith(isLoading: false);
    }
  }

  void updateRemaining(int newRemaining) {
    state = state.copyWith(remaining: newRemaining);
  }
}

final hintQuotaProvider = NotifierProvider<HintQuotaNotifier, HintQuotaState>(() {
  return HintQuotaNotifier();
});
