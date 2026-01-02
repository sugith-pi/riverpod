import 'dart:isolate';

import 'package:riverpod_lint/main.dart' as plugin;
import 'package:analysis_server_plugin/starter.dart';

void main(List<String> args, SendPort sendPort) {
  ServerPluginStarter(plugin.plugin).start(sendPort);
}
