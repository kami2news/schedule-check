import 'package:firebase_core/firebase_core.dart';

/// Firebase の Web アプリ設定（Firebase コンソール →プロジェクトの設定 → マイアプリ → SDK の設定と構成）。
/// これらの値は公開しても問題ない識別子で、データはセキュリティルール（firestore.rules）で守る。
/// apiKey が空のあいだは、オンライン機能を使わずに端末内だけで動く。
const kFirebaseWebOptions = FirebaseOptions(
  apiKey: '',
  appId: '',
  messagingSenderId: '',
  projectId: '',
  authDomain: '',
  storageBucket: '',
);

bool get isFirebaseConfigured => kFirebaseWebOptions.apiKey.isNotEmpty;
