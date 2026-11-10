// このファイルは `flutterfire configure` で上書きされます（それまでの仮のファイル）。
// 仮のあいだは Firebase を使わず、端末内だけで動きます。
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    throw UnsupportedError(
        'Firebase はまだ設定されていません。flutterfire configure を実行してください。');
  }
}
