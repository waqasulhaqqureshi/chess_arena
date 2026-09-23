/// Time control presets (mirrors the video's Time Controls sheet).
///
/// Each preset has a bespoke SVG icon in assets/icons/ (rendered with
/// flutter_svg) instead of emoji.
library;

class TimeControl {
  final String id;
  final String name;
  final String subtitle;
  /// SVG asset path, e.g. 'assets/icons/blitz.svg'.
  final String iconAsset;
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
    required this.iconAsset,
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
    iconAsset: 'assets/icons/rapid.svg',
    seconds: 600,
  ),
  TimeControl(
    id: 'chill',
    name: 'Chill',
    subtitle: '60 seconds/move',
    iconAsset: 'assets/icons/chill.svg',
    moveSeconds: 60,
  ),
  TimeControl(
    id: 'blitz53',
    name: 'Blitz',
    subtitle: '5 min +3 seconds/move',
    iconAsset: 'assets/icons/blitz.svg',
    seconds: 300,
    increment: 3,
  ),
  TimeControl(
    id: 'tempo',
    name: 'Tempo',
    subtitle: '20 seconds/move',
    iconAsset: 'assets/icons/tempo.svg',
    moveSeconds: 20,
  ),
  TimeControl(
    id: 'blitz3',
    name: 'Blitz',
    subtitle: '3 min',
    iconAsset: 'assets/icons/storm.svg',
    seconds: 180,
  ),
  TimeControl(
    id: 'bullet21',
    name: 'Bullet',
    subtitle: '2 min +1 second/move',
    iconAsset: 'assets/icons/rocket.svg',
    seconds: 120,
    increment: 1,
  ),
];

TimeControl timeControlById(String id) => kTimeControls.firstWhere(
      (t) => t.id == id,
      orElse: () => kTimeControls[2],
    );
