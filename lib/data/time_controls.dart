/// Time control presets (mirrors the video's Time Controls sheet).
library;

class TimeControl {
  final String id;
  final String name;
  final String subtitle;
  final String icon; // emoji used as the preset icon
  /// Total seconds per side (0 when [moveSeconds] is used instead).
  final int seconds;
  /// Increment seconds added after each move.
  final int increment;
  /// Per-move clock (Chill/Tempo). 0 = classic total-time clock.
  final int moveSeconds;

  const TimeControl({
    required this.id,
    required this.name,
    required this.subtitle,
    required this.icon,
    this.seconds = 0,
    this.increment = 0,
    this.moveSeconds = 0,
  });

  bool get isPerMove => moveSeconds > 0;
}

const List<TimeControl> kTimeControls = [
  TimeControl(
    id: 'rapid',
    name: 'Rapid',
    subtitle: '10 min',
    icon: '⏰',
    seconds: 600,
  ),
  TimeControl(
    id: 'chill',
    name: 'Chill',
    subtitle: '60 seconds/move',
    icon: '☕',
    moveSeconds: 60,
  ),
  TimeControl(
    id: 'blitz53',
    name: 'Blitz',
    subtitle: '5 min +3 seconds/move',
    icon: '⚡',
    seconds: 300,
    increment: 3,
  ),
  TimeControl(
    id: 'tempo',
    name: 'Tempo',
    subtitle: '20 seconds/move',
    icon: '⏱️',
    moveSeconds: 20,
  ),
  TimeControl(
    id: 'blitz3',
    name: 'Blitz',
    subtitle: '3 min',
    icon: '🌩️',
    seconds: 180,
  ),
  TimeControl(
    id: 'bullet21',
    name: 'Bullet',
    subtitle: '2 min +1 second/move',
    icon: '🚀',
    seconds: 120,
    increment: 1,
  ),
];

TimeControl timeControlById(String id) => kTimeControls.firstWhere(
      (t) => t.id == id,
      orElse: () => kTimeControls[2],
    );
