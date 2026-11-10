import 'package:flutter/material.dart';

const weekdayNames = ['月', '火', '水', '木', '金', '土', '日'];

DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

String fmtDate(DateTime d) =>
    '${d.month}/${d.day}(${weekdayNames[d.weekday - 1]})';

String fmtMin(int m) =>
    '${(m ~/ 60).toString().padLeft(2, '0')}:${(m % 60).toString().padLeft(2, '0')}';

enum EventKind { shift, lecture, other }

extension EventKindX on EventKind {
  String get label {
    switch (this) {
      case EventKind.shift:
        return 'シフト';
      case EventKind.lecture:
        return '授業';
      case EventKind.other:
        return '予定';
    }
  }

  Color get color {
    switch (this) {
      case EventKind.shift:
        return Colors.orange;
      case EventKind.lecture:
        return Colors.indigo;
      case EventKind.other:
        return Colors.teal;
    }
  }
}

class Event {
  Event({
    required this.id,
    required this.title,
    required this.kind,
    required this.date,
    this.startMin,
    this.endMin,
    this.weekly = false,
    this.repeatUntil,
    this.place = '',
    this.note = '',
  });

  final String id;
  String title;
  EventKind kind;

  /// 初回（単発の場合はその日）の日付
  DateTime date;

  /// 0:00 からの経過分。null なら終日
  int? startMin;
  int? endMin;

  /// true の場合、[date] と同じ曜日に毎週繰り返す（時間割・固定シフト用）
  bool weekly;
  DateTime? repeatUntil;
  String place;
  String note;

  bool get allDay => startMin == null;

  String get timeLabel {
    if (startMin == null) return '終日';
    if (endMin == null) return fmtMin(startMin!);
    return '${fmtMin(startMin!)}–${fmtMin(endMin!)}';
  }

  bool occursOn(DateTime day) {
    final d = dateOnly(day);
    final first = dateOnly(date);
    if (!weekly) return d == first;
    if (d.isBefore(first)) return false;
    if (d.weekday != first.weekday) return false;
    if (repeatUntil != null && d.isAfter(dateOnly(repeatUntil!))) return false;
    return true;
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'kind': kind.name,
        'date': date.toIso8601String(),
        'startMin': startMin,
        'endMin': endMin,
        'weekly': weekly,
        'repeatUntil': repeatUntil?.toIso8601String(),
        'place': place,
        'note': note,
      };

  factory Event.fromJson(Map<String, dynamic> j) => Event(
        id: j['id'] as String,
        title: j['title'] as String,
        kind: EventKind.values.byName(j['kind'] as String),
        date: DateTime.parse(j['date'] as String),
        startMin: j['startMin'] as int?,
        endMin: j['endMin'] as int?,
        weekly: (j['weekly'] as bool?) ?? false,
        repeatUntil: j['repeatUntil'] == null
            ? null
            : DateTime.parse(j['repeatUntil'] as String),
        place: (j['place'] as String?) ?? '',
        note: (j['note'] as String?) ?? '',
      );
}

class TaskItem {
  TaskItem({
    required this.id,
    required this.title,
    this.due,
    this.dueMin,
    this.done = false,
    this.note = '',
  });

  final String id;
  String title;
  DateTime? due;
  int? dueMin;
  bool done;
  String note;

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'due': due?.toIso8601String(),
        'dueMin': dueMin,
        'done': done,
        'note': note,
      };

  factory TaskItem.fromJson(Map<String, dynamic> j) => TaskItem(
        id: j['id'] as String,
        title: j['title'] as String,
        due: j['due'] == null ? null : DateTime.parse(j['due'] as String),
        dueMin: j['dueMin'] as int?,
        done: (j['done'] as bool?) ?? false,
        note: (j['note'] as String?) ?? '',
      );
}

/// 期限の早い順（期限なしは最後）
int compareTasks(TaskItem a, TaskItem b) {
  if (a.due == null && b.due == null) return a.title.compareTo(b.title);
  if (a.due == null) return 1;
  if (b.due == null) return -1;
  final c = dateOnly(a.due!).compareTo(dateOnly(b.due!));
  if (c != 0) return c;
  return (a.dueMin ?? 24 * 60).compareTo(b.dueMin ?? 24 * 60);
}
