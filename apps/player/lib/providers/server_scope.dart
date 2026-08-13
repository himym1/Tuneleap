import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

const defaultServerId = 'default';
const activeServerIdPreferenceKey = 'active_server_id';

String normalizeServerId(String? value) {
  final normalized = value?.trim() ?? '';
  return normalized.isEmpty ? defaultServerId : normalized;
}

String scopedPreferenceKey(String baseKey, String serverId) =>
    '$baseKey::${normalizeServerId(serverId)}';

String scopedSongKey(String serverId, String songKey) =>
    '${normalizeServerId(serverId)}::$songKey';

String resolveActiveServerId(SharedPreferences prefs) {
  final stored = prefs.getString(activeServerIdPreferenceKey);
  if (stored != null && stored.trim().isNotEmpty) return stored.trim();

  final rawServers = prefs.getString('servers_list');
  if (rawServers != null) {
    try {
      final servers = jsonDecode(rawServers) as List<dynamic>;
      for (final value in servers) {
        final server = value as Map<String, dynamic>;
        if (server['isActive'] == true) {
          return normalizeServerId(server['id'] as String?);
        }
      }
    } catch (_) {
      // Fall through to the legacy default server.
    }
  }
  return defaultServerId;
}

String _recordIdentity(String baseKey, Map<String, dynamic> record) {
  if (baseKey == 'download_tasks') {
    return record['id']?.toString() ?? jsonEncode(record);
  }
  final backend = record['backend']?.toString() ?? 'subsonic';
  if (backend == 'solara') {
    final source = record['onlineSource']?.toString() ?? 'unknown';
    final id = record['urlId']?.toString() ?? record['id']?.toString() ?? '';
    return 'solara:$source:$id';
  }
  return 'subsonic:${record['id']?.toString() ?? ''}';
}

String? _mergeLegacyJsonLists(
  String baseKey,
  String legacyJson,
  String scopedJson,
) {
  try {
    final legacy = jsonDecode(legacyJson) as List<dynamic>;
    final scoped = jsonDecode(scopedJson) as List<dynamic>;
    final merged = <Map<String, dynamic>>[];
    final seen = <String>{};

    for (final value in [...scoped, ...legacy]) {
      final record = Map<String, dynamic>.from(value as Map);
      if (seen.add(_recordIdentity(baseKey, record))) merged.add(record);
    }
    return jsonEncode(merged);
  } catch (_) {
    return null;
  }
}

Future<String> migrateLegacyServerScopedData(SharedPreferences prefs) async {
  final serverId = resolveActiveServerId(prefs);
  await prefs.setString(activeServerIdPreferenceKey, serverId);

  for (final baseKey in ['download_tasks', 'play_history']) {
    final legacy = prefs.getString(baseKey);
    if (legacy == null) continue;
    final scopedKey = scopedPreferenceKey(baseKey, serverId);
    final scoped = prefs.getString(scopedKey);

    if (scoped == null) {
      if (await prefs.setString(scopedKey, legacy)) {
        await prefs.remove(baseKey);
      }
      continue;
    }

    final merged = _mergeLegacyJsonLists(baseKey, legacy, scoped);
    if (merged != null && await prefs.setString(scopedKey, merged)) {
      await prefs.remove(baseKey);
    }
    // Invalid or non-list legacy data remains under the legacy key for recovery.
  }
  return serverId;
}
