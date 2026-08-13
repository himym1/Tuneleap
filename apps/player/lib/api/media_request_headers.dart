enum MediaRequestKind { image, audio }

Map<String, String> mediaRequestHeaders(
  String url, {
  MediaRequestKind kind = MediaRequestKind.image,
}) {
  final uri = Uri.tryParse(url);
  final scheme = uri?.scheme.toLowerCase() ?? '';
  if (scheme != 'http' && scheme != 'https') {
    return const {};
  }

  final host = uri?.host.toLowerCase() ?? '';
  final needsBrowserHeaders = _needsBrowserHeaders(host);
  if (kind == MediaRequestKind.audio && !needsBrowserHeaders) {
    return const {};
  }

  final headers = <String, String>{
    // music.126.net 对 dart:io 默认 UA 返回 403，统一伪装为普通浏览器请求。
    'User-Agent':
        'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) '
        'AppleWebKit/537.36 (KHTML, like Gecko) '
        'Chrome/122.0.0.0 Safari/537.36',
    'Accept': switch (kind) {
      MediaRequestKind.image =>
        'image/avif,image/webp,image/apng,image/svg+xml,image/*,*/*;q=0.8',
      MediaRequestKind.audio => 'audio/*,*/*;q=0.8',
    },
  };

  if (needsBrowserHeaders) {
    headers['Referer'] = 'https://music.163.com/';
  }

  return headers;
}

bool _needsBrowserHeaders(String host) {
  return host == 'music.126.net' || host.endsWith('.music.126.net');
}
