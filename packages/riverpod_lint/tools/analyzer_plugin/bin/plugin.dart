import 'dart:isolate';

import 'package:analysis_server_plugin/edit/server_plugin_starter.dart';
import 'package:analyzer_plugin/starter.dart';
import 'package:riverpod_lint/main.dart' as plugin;

void main(List<String> args, SendPort sendPort) {
  ServerPluginStarter(plugin.plugin).start(sendPort);
}
