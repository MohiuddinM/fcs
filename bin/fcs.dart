import 'dart:io';

import 'package:fcs/fcs.dart';
import 'package:fcs/src/log.dart';
import 'package:quick_log/quick_log.dart';

const channels = ['stable', 'beta', 'dev', 'master'];

extension ListX<T> on List<T?> {
  T? nullableAt(int index) {
    try {
      return elementAt(index);
    } catch (_) {
      return null;
    }
  }
}

void main(List<String> args) {
  final minLogLevel = args.contains('-v') ? LogLevel.fine : LogLevel.info;
  Logger.writer = FcsWriter(minLogLevel);
  LogWriter.enableInReleaseMode = true;

  final rootPath = Platform.environment['flutter_path'] ??
      File(Platform.resolvedExecutable).parent.path;

  final manager = FlutterManager(rootPath);

  if (args.first == 'init') {
    return manager.initialize();
  } else if (args[0] == 'channel') {
    final channel = args.nullableAt(1);

    if (channel == null) {
      try {
        print(
            '${manager.currentChannel} (${manager.channelVersion('current')})');
      } on ProcessException {
        print('fcs is not initialized');
      }
    } else if (channels.contains(channel)) {
      manager.select(channel);
    } else {
      return print('${channel} is not a valid branch');
    }
  } else if (args.first == 'upgrade') {
    final channel = args.nullableAt(1);

    if (channel == null) {
      manager.upgrade('current');
    } else if (channels.contains(channel)) {
      manager.upgrade(channel);
    } else {
      return print('${channel} is not a valid branch');
    }
  } else {
    print('${args.first} is not a valid command');
  }
}
