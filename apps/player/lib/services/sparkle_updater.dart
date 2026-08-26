import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:navidrome_player/utils/platform_utils.dart';

const sparkleChannelName = 'tuneleap/sparkle';

@visibleForTesting
bool? sparkleSupportedOverride;

@visibleForTesting
MethodChannel sparkleMethodChannel = const MethodChannel(sparkleChannelName);

bool get isSparkleSupported => sparkleSupportedOverride ?? (!kIsWeb && isMacOS);

String sparkleFeedURL(String origin) =>
    '${origin.replaceAll(RegExp(r'/$'), '')}/appcast.xml';

/// macOS Sparkle host. Android keeps [checkForUpdate].
class SparkleUpdater {
  SparkleUpdater._();

  static Future<bool> configure({
    required String feedURL,
    required String accessToken,
  }) async {
    if (!isSparkleSupported || accessToken.isEmpty) return false;
    final uri = Uri.tryParse(feedURL);
    if (uri == null || uri.scheme != 'https' || uri.host.isEmpty) {
      return false;
    }
    try {
      final ok = await sparkleMethodChannel.invokeMethod<bool>('configure', {
        'feedURL': feedURL,
        'authorization': 'Bearer $accessToken',
      });
      return ok == true;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }

  static Future<bool> checkForUpdates({bool inBackground = false}) async {
    if (!isSparkleSupported) return false;
    try {
      final method = inBackground
          ? 'checkForUpdatesInBackground'
          : 'checkForUpdates';
      final ok = await sparkleMethodChannel.invokeMethod<bool>(method);
      return ok == true;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }
}
