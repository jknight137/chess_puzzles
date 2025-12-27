import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/puzzle_stats.dart';
import '../models/run_result.dart';

class StorageService {
  StorageService._();

  static final StorageService instance = StorageService._();

  static const String _kPuzzleStats = 'puzzle_stats_v1';
  static const String _kRuns = 'leaderboard_runs_v1';
  static const String _kEndgameCompleted = 'endgame_completed_v1';

  Future<Map<String, PuzzleStats>> loadAllPuzzleStats() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kPuzzleStats);
    if (raw == null || raw.isEmpty) return <String, PuzzleStats>{};

    final decoded = jsonDecode(raw);
    if (decoded is! Map) return <String, PuzzleStats>{};

    final out = <String, PuzzleStats>{};
    for (final entry in decoded.entries) {
      final key = entry.key.toString();
      final val = entry.value;
      if (val is Map<String, dynamic>) {
        out[key] = PuzzleStats.fromJson(val);
      } else if (val is Map) {
        out[key] = PuzzleStats.fromJson(Map<String, dynamic>.from(val));
      }
    }
    return out;
  }

  Future<PuzzleStats> getPuzzleStats(String puzzleKey) async {
    final all = await loadAllPuzzleStats();
    return all[puzzleKey] ?? PuzzleStats.empty(puzzleKey);
  }

  Future<void> upsertPuzzleStats(PuzzleStats stats) async {
    final prefs = await SharedPreferences.getInstance();
    final all = await loadAllPuzzleStats();
    all[stats.puzzleKey] = stats;

    final mapJson = <String, dynamic>{};
    for (final e in all.entries) {
      mapJson[e.key] = e.value.toJson();
    }
    await prefs.setString(_kPuzzleStats, jsonEncode(mapJson));
  }

  Future<List<RunResult>> loadRuns() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kRuns);
    if (raw == null || raw.isEmpty) return <RunResult>[];

    final decoded = jsonDecode(raw);
    if (decoded is! List) return <RunResult>[];

    final out = <RunResult>[];
    for (final item in decoded) {
      if (item is Map<String, dynamic>) {
        out.add(RunResult.fromJson(item));
      } else if (item is Map) {
        out.add(RunResult.fromJson(Map<String, dynamic>.from(item)));
      }
    }

    out.sort((a, b) {
      final s = b.score.compareTo(a.score);
      if (s != 0) return s;
      return a.durationMs.compareTo(b.durationMs);
    });

    return out;
  }

  Future<void> addRun(RunResult run) async {
    final prefs = await SharedPreferences.getInstance();
    final runs = await loadRuns();
    runs.add(run);

    runs.sort((a, b) {
      final s = b.score.compareTo(a.score);
      if (s != 0) return s;
      return a.durationMs.compareTo(b.durationMs);
    });

    final jsonList = runs.map((r) => r.toJson()).toList();
    await prefs.setString(_kRuns, jsonEncode(jsonList));
  }

  Future<void> clearRuns() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kRuns);
  }

  Future<Set<int>> loadEndgameCompleted() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kEndgameCompleted);
    if (raw == null || raw.isEmpty) return <int>{};

    final decoded = jsonDecode(raw);
    if (decoded is! List) return <int>{};

    return decoded
        .whereType<num>()
        .map((e) => e.toInt())
        .toSet();
  }

  Future<void> saveEndgameCompleted(Set<int> completed) async {
    final prefs = await SharedPreferences.getInstance();
    final list = completed.toList()..sort();
    await prefs.setString(_kEndgameCompleted, jsonEncode(list));
  }

  Future<void> clearEndgameCompleted() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kEndgameCompleted);
  }

}
