import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:navidrome_player/providers/server_scope.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('same song key is isolated by server namespace', () {
    expect(
      scopedSongKey('server-a', 'subsonic:same-id'),
      isNot(scopedSongKey('server-b', 'subsonic:same-id')),
    );
  });

  test('resolves the active server from the legacy server list', () async {
    SharedPreferences.setMockInitialValues({
      'servers_list': jsonEncode([
        {'id': 'a', 'isActive': false},
        {'id': 'b', 'isActive': true},
      ]),
    });
    final prefs = await SharedPreferences.getInstance();

    expect(resolveActiveServerId(prefs), 'b');
  });

  test(
    'moves legacy downloads and history to the active server once',
    () async {
      SharedPreferences.setMockInitialValues({
        'active_server_id': 'server-a',
        'download_tasks': '[1]',
        'play_history': '[2]',
      });
      final prefs = await SharedPreferences.getInstance();

      final serverId = await migrateLegacyServerScopedData(prefs);

      expect(serverId, 'server-a');
      expect(prefs.getString('download_tasks::server-a'), '[1]');
      expect(prefs.getString('play_history::server-a'), '[2]');
      expect(prefs.containsKey('download_tasks'), isFalse);
      expect(prefs.containsKey('play_history'), isFalse);
    },
  );

  test(
    'merges legacy and scoped values without losing either record',
    () async {
      final legacy = jsonEncode([
        {'id': 'subsonic:legacy', 'songId': 'legacy'},
      ]);
      final current = jsonEncode([
        {'id': 'subsonic:current', 'songId': 'current'},
      ]);
      SharedPreferences.setMockInitialValues({
        'active_server_id': 'server-a',
        'download_tasks': legacy,
        'download_tasks::server-a': current,
      });
      final prefs = await SharedPreferences.getInstance();

      await migrateLegacyServerScopedData(prefs);

      final merged =
          jsonDecode(prefs.getString('download_tasks::server-a')!) as List;
      expect(merged.map((item) => item['id']), [
        'subsonic:current',
        'subsonic:legacy',
      ]);
      expect(prefs.containsKey('download_tasks'), isFalse);
    },
  );

  test('keeps invalid legacy data for manual recovery', () async {
    SharedPreferences.setMockInitialValues({
      'active_server_id': 'server-a',
      'download_tasks': 'invalid',
      'download_tasks::server-a': '[]',
    });
    final prefs = await SharedPreferences.getInstance();

    await migrateLegacyServerScopedData(prefs);

    expect(prefs.getString('download_tasks'), 'invalid');
  });
}
