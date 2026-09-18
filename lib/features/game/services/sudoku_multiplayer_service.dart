import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import '../../../core/services/supabase_service.dart';
import '../utils/sudoku_generator.dart';

enum MultiplayerMode { solo, randomQueue, privateRoom }
enum MatchState { idle, searching, inLobby, countdown, playing, finished }

class OpponentPlayer {
  final String id;
  final String name;
  final bool isBot;
  int cellsFilled;
  int totalToFill;
  int errorCount;
  bool isFinished;

  OpponentPlayer({
    required this.id,
    required this.name,
    this.isBot = false,
    this.cellsFilled = 0,
    required this.totalToFill,
    this.errorCount = 0,
    this.isFinished = false,
  });

  double get progressPercent => totalToFill == 0 ? 0 : (cellsFilled / totalToFill).clamp(0.0, 1.0);
}

class SudokuMultiplayerService extends ChangeNotifier {
  final SupabaseService _db = SupabaseService.instance;
  final Random _rand = Random();

  MultiplayerMode mode = MultiplayerMode.solo;
  MatchState state = MatchState.idle;

  SudokuDifficulty selectedDifficulty = SudokuDifficulty.medium;
  SudokuPuzzle? currentPuzzle;
  OpponentPlayer? opponent;

  String? roomCode;
  bool isHost = false;

  Timer? _searchTimeoutTimer;
  int searchSecondsElapsed = 0;
  Timer? _botSimTimer;
  Timer? _countdownTimer;
  int countdownSeconds = 3;

  dynamic _realtimeChannel;

  static const List<String> _botNames = [
    'Bảo Nam ⚡',
    'Khánh Linh 🌸',
    'Minh Triết 🧠',
    'Hải Đăng 🚀',
    'Quỳnh Anh ✨',
    'Đức Huy 🎯',
    'Gia Hân 🌟',
    'Hoàng Long 🔥',
  ];

  /// Bắt đầu tìm trận tự động (Random Queue)
  void startQuickMatch(SudokuDifficulty difficulty) {
    mode = MultiplayerMode.randomQueue;
    selectedDifficulty = difficulty;
    state = MatchState.searching;
    searchSecondsElapsed = 0;
    opponent = null;
    notifyListeners();

    _searchTimeoutTimer?.cancel();
    _searchTimeoutTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      searchSecondsElapsed++;
      notifyListeners();

      // Sau 15 giây không có người -> tự động ghép với Bot ảo
      if (searchSecondsElapsed >= 15) {
        _searchTimeoutTimer?.cancel();
        _pairWithVirtualBot();
      }
    });

    // Thử ghép cặp online qua Supabase Realtime nếu online
    _connectOnlineMatchmaking();
  }

  void _connectOnlineMatchmaking() {
    if (_db.isOfflineDemoMode) return;

    try {
      final channelName = 'sudoku_matchmaking_${selectedDifficulty.name}';
      _realtimeChannel = _db.client.channel(channelName);

      _realtimeChannel.onBroadcast(
        event: 'match_request',
        callback: (payload) {
          final senderId = payload['user_id'];
          final myId = _db.client.auth.currentUser?.id;
          if (senderId != null && senderId != myId && state == MatchState.searching) {
            // Có đối thủ online!
            _searchTimeoutTimer?.cancel();
            _startMatchWithOpponent(
              OpponentPlayer(
                id: senderId,
                name: payload['user_name'] ?? 'Kỳ thủ bí ẩn',
                isBot: false,
                totalToFill: 81 - selectedDifficulty.targetClues,
              ),
            );
          }
        },
      ).subscribe((status, [error]) {
        if (status == 'SUBSCRIBED') {
          // Bắn broadcast tìm đối thủ
          _realtimeChannel?.sendBroadcastMessage(
            event: 'match_request',
            payload: {
              'user_id': _db.client.auth.currentUser?.id ?? 'player_${_rand.nextInt(9999)}',
              'user_name': _db.client.auth.currentUser?.email?.split('@')[0] ?? 'Bạn',
              'difficulty': selectedDifficulty.name,
            },
          );
        }
      });
    } catch (e) {
      debugPrint('Error connecting matchmaking: $e');
    }
  }

  /// Ghép với Bot ảo thông minh
  void _pairWithVirtualBot() {
    final botName = _botNames[_rand.nextInt(_botNames.length)];
    final puzzle = SudokuGenerator.generate(selectedDifficulty);
    currentPuzzle = puzzle;
    final totalToFill = 81 - puzzle.clueCount;

    opponent = OpponentPlayer(
      id: 'bot_${_rand.nextInt(9999)}',
      name: botName,
      isBot: true,
      totalToFill: totalToFill,
    );

    _startCountdown();
  }

  void _startMatchWithOpponent(OpponentPlayer op) {
    opponent = op;
    currentPuzzle = SudokuGenerator.generate(selectedDifficulty);
    _startCountdown();
  }

  void _startCountdown() {
    state = MatchState.countdown;
    countdownSeconds = 3;
    notifyListeners();

    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      countdownSeconds--;
      if (countdownSeconds <= 0) {
        timer.cancel();
        _startPlaying();
      } else {
        notifyListeners();
      }
    });
  }

  void _startPlaying() {
    state = MatchState.playing;
    notifyListeners();

    if (opponent?.isBot == true) {
      _startBotSimulation();
    }
  }

  /// Mô phỏng tốc độ điền số ngẫu nhiên theo thời gian thực của Bot
  void _startBotSimulation() {
    _botSimTimer?.cancel();
    if (opponent == null || currentPuzzle == null) return;

    // Tốc độ bot điền số phụ thuộc độ khó (3.5s - 6.5s mỗi ô)
    final baseSeconds = switch (selectedDifficulty) {
      SudokuDifficulty.easy => 3.5,
      SudokuDifficulty.medium => 4.2,
      SudokuDifficulty.hard => 5.0,
      SudokuDifficulty.expert => 5.8,
      SudokuDifficulty.master => 6.5,
      SudokuDifficulty.extreme => 7.2,
    };

    void scheduleNextFill() {
      if (state != MatchState.playing || opponent == null || opponent!.isFinished) return;

      final jitter = (_rand.nextDouble() * 2.0) - 1.0; // -1.0s đến +1.0s
      final duration = Duration(milliseconds: ((baseSeconds + jitter) * 1000).round().clamp(2000, 10000));

      _botSimTimer = Timer(duration, () {
        if (state != MatchState.playing || opponent == null || opponent!.isFinished) return;

        opponent!.cellsFilled++;
        if (opponent!.cellsFilled >= opponent!.totalToFill) {
          opponent!.cellsFilled = opponent!.totalToFill;
          opponent!.isFinished = true;
          notifyListeners();
        } else {
          notifyListeners();
          scheduleNextFill();
        }
      });
    }

    scheduleNextFill();
  }

  /// Báo cáo tiến độ của người chơi hiện tại
  void updatePlayerProgress(int filledCount, int errorsCount, bool finished) {
    if (state != MatchState.playing) return;

    // Bắn broadcast cho đối thủ nếu online
    if (mode != MultiplayerMode.solo && opponent?.isBot == false && _realtimeChannel != null) {
      try {
        _realtimeChannel.sendBroadcastMessage(
          event: 'player_progress',
          payload: {
            'filled_count': filledCount,
            'errors_count': errorsCount,
            'is_finished': finished,
          },
        );
      } catch (e) {
        debugPrint('Error broadcasting progress: $e');
      }
    }

    if (finished) {
      state = MatchState.finished;
      _botSimTimer?.cancel();
      notifyListeners();
    }
  }

  /// Tạo phòng riêng (Private Room)
  void createPrivateRoom(SudokuDifficulty difficulty) {
    mode = MultiplayerMode.privateRoom;
    selectedDifficulty = difficulty;
    isHost = true;
    roomCode = _generateRoomCode();
    state = MatchState.inLobby;
    opponent = null;
    currentPuzzle = SudokuGenerator.generate(difficulty);
    notifyListeners();

    _listenToPrivateRoom(roomCode!);
  }

  /// Tham gia phòng riêng qua mã PIN
  void joinPrivateRoom(String code) {
    mode = MultiplayerMode.privateRoom;
    isHost = false;
    roomCode = code.toUpperCase().trim();
    state = MatchState.inLobby;
    opponent = null;
    notifyListeners();

    _listenToPrivateRoom(roomCode!);
  }

  void _listenToPrivateRoom(String code) {
    if (_db.isOfflineDemoMode) {
      // Trong chế độ Offline demo: tự động cho 1 bạn vào phòng sau 3 giây
      Timer(const Duration(seconds: 3), () {
        if (state == MatchState.inLobby) {
          opponent = OpponentPlayer(
            id: 'guest_demo',
            name: 'Bạn Carlos ⚡',
            totalToFill: 81 - (currentPuzzle?.clueCount ?? 34),
          );
          _startCountdown();
        }
      });
      return;
    }

    try {
      _realtimeChannel = _db.client.channel('sudoku_room_$code');
      _realtimeChannel
          .onBroadcast(
            event: 'guest_joined',
            callback: (payload) {
              if (isHost && state == MatchState.inLobby) {
                opponent = OpponentPlayer(
                  id: payload['user_id'] ?? 'guest',
                  name: payload['user_name'] ?? 'Khách',
                  totalToFill: 81 - currentPuzzle!.clueCount,
                );
                // Gửi toàn bộ ma trận đề bài và lời giải cho khách để cả 2 chơi CÙNG 1 ĐỀ
                _realtimeChannel?.sendBroadcastMessage(
                  event: 'start_game',
                  payload: {
                    'host_id': _db.client.auth.currentUser?.id ?? 'host',
                    'host_name': _db.client.auth.currentUser?.email?.split('@')[0] ?? 'Chủ phòng',
                    'puzzle_initial': currentPuzzle!.initialBoard,
                    'puzzle_solution': currentPuzzle!.solution,
                  },
                );
                _startCountdown();
              }
            },
          )
          .onBroadcast(
            event: 'start_game',
            callback: (payload) {
              if (!isHost && state == MatchState.inLobby) {
                final initial = (payload['puzzle_initial'] as List)
                    .map((row) => (row as List).map((e) => (e as num).toInt()).toList())
                    .toList();
                final solution = (payload['puzzle_solution'] as List)
                    .map((row) => (row as List).map((e) => (e as num).toInt()).toList())
                    .toList();
                currentPuzzle = SudokuPuzzle(
                  initialBoard: initial,
                  solution: solution,
                  difficulty: selectedDifficulty,
                );
                opponent = OpponentPlayer(
                  id: payload['host_id'] ?? 'host',
                  name: payload['host_name'] ?? 'Chủ phòng',
                  totalToFill: 81 - currentPuzzle!.clueCount,
                );
                _startCountdown();
              }
            },
          )
          .subscribe((status, [error]) {
        if (status == 'SUBSCRIBED' && !isHost) {
          _realtimeChannel?.sendBroadcastMessage(
            event: 'guest_joined',
            payload: {
              'user_id': _db.client.auth.currentUser?.id ?? 'guest_${_rand.nextInt(9999)}',
              'user_name': _db.client.auth.currentUser?.email?.split('@')[0] ?? 'Bạn',
            },
          );
        }
      });
    } catch (e) {
      debugPrint('Error listening private room: $e');
    }
  }

  static String _generateRoomCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final rand = Random();
    return 'SK${List.generate(4, (_) => chars[rand.nextInt(chars.length)]).join()}';
  }

  void cancelMatch() {
    _searchTimeoutTimer?.cancel();
    _botSimTimer?.cancel();
    _countdownTimer?.cancel();
    try {
      _realtimeChannel?.unsubscribe();
    } catch (_) {}
    state = MatchState.idle;
    opponent = null;
    currentPuzzle = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _searchTimeoutTimer?.cancel();
    _botSimTimer?.cancel();
    _countdownTimer?.cancel();
    try {
      _realtimeChannel?.unsubscribe();
    } catch (_) {}
    super.dispose();
  }
}
