import 'package:flutter/foundation.dart';

enum LiveKind { running, waiting, done, failed }

/// What the live activity says. Equal values are not pushed again.
@immutable
class LiveActivity {
  const LiveActivity({
    required this.kind,
    required this.title,
    required this.text,
    required this.chip,
    required this.publicText,
    this.mood = 'idle',
    this.since,
    this.eventId,
  });

  final LiveKind kind;
  final String title;
  final String text;
  final String chip;
  final String publicText;
  final String mood;
  final DateTime? since;
  final String? eventId;

  Map<String, Object?> toMap() => {
    'kind': kind.name,
    'title': title,
    'text': text,
    'chip': chip,
    'publicText': publicText,
    'mood': mood,
    'sinceMs': ?since?.millisecondsSinceEpoch,
    'eventId': ?eventId,
  };

  @override
  bool operator ==(Object other) =>
      other is LiveActivity &&
      other.kind == kind &&
      other.title == title &&
      other.text == text &&
      other.chip == chip &&
      other.publicText == publicText &&
      other.mood == mood &&
      other.since == since &&
      other.eventId == eventId;

  @override
  int get hashCode => Object.hash(kind, title, text, chip, publicText, mood, since, eventId);
}
