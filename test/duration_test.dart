import 'package:flutter_test/flutter_test.dart';
import 'package:schedule_check/models.dart';

void main() {
  test('所要時間の書き方', () {
    expect(fmtDuration(50), '50分');
    expect(fmtDuration(60), '1時間');
    expect(fmtDuration(90), '1時間30分');
    expect(fmtDuration(150), '2時間30分');
  });

  test('終了時刻に添える所要時間（開始以前は翌日に終わる扱い）', () {
    expect(durationNote(9 * 60, 10 * 60 + 30), '（1時間30分）');
    expect(durationNote(9 * 60, 9 * 60 + 15), '（15分）');
    // 夜勤: 23:00 開始で 5:00 を選ぶと翌日
    expect(durationNote(23 * 60, 5 * 60), '（翌日・6時間）');
    // 終了日が翌日と決まっているときは、開始より後の時刻も翌日
    expect(durationNote(22 * 60, 23 * 60, endOffset: 1), '（翌日・25時間）');
    // 2日後に終わる
    expect(durationNote(9 * 60, 9 * 60, endOffset: 2), '（2日後・48時間）');
  });

  test('日をまたぐ時限（通しの分）', () {
    expect(fmtPeriodMin(23 * 60), '23:00');
    expect(fmtPeriodMin(24 * 60 + 20), '翌0:20');
    // 予定の時刻に直す
    expect(periodToEvent(23 * 60 + 30, 24 * 60 + 20),
        (start: 23 * 60 + 30, end: 20, endOffset: 1));
    expect(periodToEvent(24 * 60 + 30, 25 * 60 + 20),
        (start: 30, end: 80, endOffset: 0));
    // 選んだ時刻を、前の時限より後の通しの分に
    expect(periodAfter(10, 23 * 60), 24 * 60 + 10);
    expect(periodAfter(23 * 60 + 40, 23 * 60), 23 * 60 + 40);
    expect(periodAfter(20, 23 * 60 + 31), 24 * 60 + 20);
  });
}
