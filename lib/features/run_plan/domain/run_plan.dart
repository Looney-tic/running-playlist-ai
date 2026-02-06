/// Pure Dart domain model for run plans. No Flutter dependencies.
///
/// A [RunPlan] contains one or more [RunSegment]s, each with a target BPM
/// and duration. The segment-based design supports steady runs (Phase 6),
/// and will extend to intervals and warm-up/cool-down in Phase 8.
library;

/// The type of run plan.
enum RunType {
  steady,
  warmUpCoolDown,
  interval;

  /// Deserializes from a JSON string (enum name).
  ///
  /// Falls back to [steady] for unknown values, so a newer app version's
  /// data doesn't crash an older version.
  static RunType fromJson(String name) =>
      RunType.values.firstWhere(
        (e) => e.name == name,
        orElse: () => RunType.steady,
      );
}

/// A single segment within a run plan.
///
/// Each segment has a duration and target BPM (cadence) for playlist matching.
/// An optional [label] describes the segment (e.g. "Warm-up", "Sprint").
class RunSegment {
  const RunSegment({
    required this.durationSeconds,
    required this.targetBpm,
    this.label,
  });

  factory RunSegment.fromJson(Map<String, dynamic> json) {
    return RunSegment(
      durationSeconds: json['durationSeconds'] as int,
      targetBpm: (json['targetBpm'] as num).toDouble(),
      label: json['label'] as String?,
    );
  }

  final int durationSeconds;
  final double targetBpm;
  final String? label;

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{
      'durationSeconds': durationSeconds,
      'targetBpm': targetBpm,
    };
    if (label != null) json['label'] = label;
    return json;
  }
}

/// A complete run plan with type, distance, pace, and segments.
///
/// For a steady run, there is exactly one segment. Future plan types
/// (intervals, warm-up/cool-down) will have multiple segments.
class RunPlan {
  RunPlan({
    required this.type,
    required this.distanceKm,
    required this.paceMinPerKm,
    required this.segments,
    this.name,
    DateTime? createdAt,
    String? id,
  })  : id = id ?? DateTime.now().millisecondsSinceEpoch.toString(),
        createdAt = createdAt ?? DateTime.now();

  factory RunPlan.fromJson(Map<String, dynamic> json) {
    return RunPlan(
      id: json['id'] as String?,
      type: RunType.fromJson(json['type'] as String),
      distanceKm: (json['distanceKm'] as num).toDouble(),
      paceMinPerKm: (json['paceMinPerKm'] as num).toDouble(),
      segments: (json['segments'] as List<dynamic>)
          .map((s) => RunSegment.fromJson(s as Map<String, dynamic>))
          .toList(),
      name: json['name'] as String?,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : null,
    );
  }

  final String id;
  final RunType type;
  final double distanceKm;
  final double paceMinPerKm;
  final List<RunSegment> segments;
  final String? name;
  final DateTime createdAt;

  /// Total duration across all segments, in seconds.
  int get totalDurationSeconds =>
      segments.fold(0, (sum, s) => sum + s.durationSeconds);

  /// Total duration across all segments, in minutes.
  double get totalDurationMinutes => totalDurationSeconds / 60.0;

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type.name,
        'distanceKm': distanceKm,
        'paceMinPerKm': paceMinPerKm,
        'segments': segments.map((s) => s.toJson()).toList(),
        if (name != null) 'name': name,
        'createdAt': createdAt.toIso8601String(),
      };
}

/// Formats a duration in seconds as "H:MM:SS" or "MM:SS".
///
/// Examples:
///   1800 -> "30:00"
///   3661 -> "1:01:01"
///   90   -> "1:30"
///   0    -> "0:00"
String formatDuration(int totalSeconds) {
  final hours = totalSeconds ~/ 3600;
  final minutes = (totalSeconds % 3600) ~/ 60;
  final seconds = totalSeconds % 60;

  final mm = minutes.toString().padLeft(2, '0');
  final ss = seconds.toString().padLeft(2, '0');

  if (hours > 0) {
    return '$hours:$mm:$ss';
  }
  return '$minutes:$ss';
}
