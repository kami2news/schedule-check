{{flutter_js}}
{{flutter_build_config}}

// Flutter 標準の Service Worker は使わない（自分で解除される古い仕組みのため）。
// 同じ場所に通知用の push-sw.js を登録するので、ここでは何も登録しない。
_flutter.loader.load();
