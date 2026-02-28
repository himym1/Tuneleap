import 'dart:io';

bool get isDesktop => Platform.isMacOS || Platform.isWindows || Platform.isLinux;
bool get isMobile => Platform.isAndroid || Platform.isIOS;
bool get isMacOS => Platform.isMacOS;
bool get isAndroid => Platform.isAndroid;
