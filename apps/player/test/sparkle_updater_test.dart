import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:navidrome_player/services/sparkle_updater.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    sparkleSupportedOverride = true;
    sparkleMethodChannel = const MethodChannel(sparkleChannelName);
  });

  tearDown(() {
    sparkleSupportedOverride = null;
  });

  test('sparkleFeedURL stays on the Cloud origin', () {
    expect(
      sparkleFeedURL('https://player.himym.us.ci'),
      'https://player.himym.us.ci/appcast.xml',
    );
    expect(
      sparkleFeedURL('https://player.himym.us.ci/'),
      'https://player.himym.us.ci/appcast.xml',
    );
  });

  test('configure rejects empty tokens and non-https feeds', () async {
    expect(
      await SparkleUpdater.configure(
        feedURL: 'https://player.himym.us.ci/appcast.xml',
        accessToken: '',
      ),
      isFalse,
    );
    expect(
      await SparkleUpdater.configure(
        feedURL: 'http://player.himym.us.ci/appcast.xml',
        accessToken: 'token',
      ),
      isFalse,
    );
  });

  test('configure sends Bearer header without using a query token', () async {
    late MethodCall captured;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(sparkleMethodChannel, (call) async {
          captured = call;
          return true;
        });

    expect(
      await SparkleUpdater.configure(
        feedURL: 'https://player.himym.us.ci/appcast.xml',
        accessToken: 'access-token',
      ),
      isTrue,
    );
    expect(captured.method, 'configure');
    final args = captured.arguments as Map;
    expect(args['feedURL'], 'https://player.himym.us.ci/appcast.xml');
    expect(args['authorization'], 'Bearer access-token');
    expect(args['feedURL'], isNot(contains('access-token')));
  });

  test('unsupported platforms skip the native channel', () async {
    sparkleSupportedOverride = false;
    expect(
      await SparkleUpdater.configure(
        feedURL: 'https://player.himym.us.ci/appcast.xml',
        accessToken: 'access-token',
      ),
      isFalse,
    );
    expect(await SparkleUpdater.checkForUpdates(), isFalse);
  });
}
