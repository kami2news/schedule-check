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
}
