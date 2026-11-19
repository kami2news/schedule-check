/// Web 以外では何もしない（OS が安全な余白を教えてくれる）
void prepareStandalone() {}

/// ホーム画面アプリで足す安全な余白（上・下）
({double top, double bottom}) standaloneInsets() => (top: 0, bottom: 0);
