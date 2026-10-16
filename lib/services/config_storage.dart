import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../models/server_config.dart';

class ConfigStorage {
  static const _fileName = 'servers.json';

  Future<File> _getFile() async {
    final dir = await getApplicationSupportDirectory();
    return File('${dir.path}/$_fileName');
  }

  Future<List<ServerConfig>> loadServers() async {
    try {
      final file = await _getFile();
      if (!await file.exists()) return [];
      final content = await file.readAsString();
      final list = jsonDecode(content) as List;
      return list
          .map((e) => ServerConfig.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> saveServers(List<ServerConfig> servers) async {
    final file = await _getFile();
    final json = jsonEncode(servers.map((s) => s.toJson()).toList());
    await file.writeAsString(json, flush: true);
  }

  Future<void> addServer(ServerConfig server) async {
    final servers = await loadServers();
    servers.add(server);
    await saveServers(servers);
  }

  Future<void> removeServer(int index) async {
    final servers = await loadServers();
    if (index >= 0 && index < servers.length) {
      servers.removeAt(index);
      await saveServers(servers);
    }
  }
}
