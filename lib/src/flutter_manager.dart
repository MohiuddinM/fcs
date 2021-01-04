import 'dart:io';

import 'package:path/path.dart' as p;

import 'log.dart';

extension DirectoryX on Directory {
  Directory append(String a) => Directory(p.join(path, a));
}

class FlutterManager {
  static const _log = FcsLogger('FlutterManager');

  final Directory _flutterDir,
      _currentSdkDir,
      _stableSdkDir,
      _betaSdkDir,
      _devSdkDir,
      _masterSdkDir;

  FlutterManager(String rootPath)
      : _flutterDir = Directory(rootPath),
        _currentSdkDir = Directory(p.join(rootPath, 'current')),
        _stableSdkDir = Directory(p.join(rootPath, 'stable')),
        _betaSdkDir = Directory(p.join(rootPath, 'beta')),
        _devSdkDir = Directory(p.join(rootPath, 'dev')),
        _masterSdkDir = Directory(p.join(rootPath, 'master'));

  String exePath(String channel) {
    return p.join(_flutterDir.path, channel, 'bin', 'flutter.bat');
  }

  String channelVersion(String channel) {
    if (currentChannel == channel) {
      channel = 'current';
    }

    final all = Process.runSync(exePath(channel), ['--version']);

    final parts = (all.stdout as String).split(' ');

    return parts[1].trim();
  }

  String get currentChannel {
    final branch = Process.runSync(
      'git',
      ['branch', '--show-current'],
      workingDirectory: _currentSdkDir.path,
    );

    return (branch.stdout as String).trim();
  }

  void select(String channel) async {
    if (!_currentSdkDir.existsSync()) {
      _log.error('fcs is not initialized');
      _log.error('Please run "fcs init" to initialized');
      return;
    }

    // check if it is already selected
    if (currentChannel == channel) {
      return _log.info('$channel is already selected');
    }

    final branchDir = _flutterDir.append(channel);

    if (!branchDir.existsSync()) {
      _log.error('fcs is not initialized');
      _log.error('Please run "fcs init" to initialized');
      return;
    }

    final originalDir = _flutterDir.append(currentChannel);
    final originalChannel = currentChannel;

    try {
      _currentSdkDir.renameSync(originalDir.path);
    } on FileSystemException catch (e) {
      return _log.error('select failed: ${e.message}');
    }

    _unpatch(originalChannel);

    try {
      branchDir.renameSync(_currentSdkDir.path);
    } on FileSystemException catch (e) {
      originalDir.renameSync(_currentSdkDir.path);
      return _log.error('select failed: ${e.message}');
    }

    _patch();

    _log.info(
        '$currentChannel (${channelVersion('current')}) has been selected');
  }

  void upgrade(String channel) {
    _log.info('upgrading $channel to latest version');

    if (channel == currentChannel) {
      channel = 'current';
    }

    _unpatch(channel);

    Process.runSync(exePath(channel), ['upgrade']);

    _patch(channel);
  }

  void initialize() {
    _log.info('initializing fcs in $_flutterDir');

    _masterSdkDir.createSync(recursive: true);
    _stableSdkDir.createSync(recursive: true);
    _betaSdkDir.createSync(recursive: true);
    _devSdkDir.createSync(recursive: true);
    _currentSdkDir.createSync(recursive: true);

    _cloneMaster();

    _copy(_masterSdkDir.path, _stableSdkDir.path);
    _setChannelAndUpgrade(_stableSdkDir.path, 'stable');

    _copy(_masterSdkDir.path, _betaSdkDir.path);
    _setChannelAndUpgrade(_betaSdkDir.path, 'beta');

    _copy(_masterSdkDir.path, _devSdkDir.path);
    _setChannelAndUpgrade(_devSdkDir.path, 'dev');

    _log.fine('stable has been selected as the current channel');
    _stableSdkDir.renameSync(_currentSdkDir.path);

    _patch();
  }

  void _patch([String channel = 'current']) {
    final file = File(exePath(channel));

    _log.fine('patching file: ${file.path}');

    final original = file.readAsStringSync();

    if (original.contains('fcs_cmd')) {
      return;
    }

    final patched = original.replaceFirst('@ECHO off', patchString);

    file.writeAsStringSync(patched);
  }

  void _unpatch([String channel = 'current']) {
    final file = File(exePath(channel));

    _log.fine('unpatching file: ${file.path}');

    final patched = file.readAsStringSync();

    if (patched.contains('fcs_cmd')) {
      final unpatched = patched.replaceFirst(patchString, '@ECHO off');
      file.writeAsStringSync(unpatched);
    }
  }

  void _setChannelAndUpgrade(String folder, String channel) {
    _log.info('setting up $channel');
    _log.fine('setting channel $channel in $folder');

    Process.runSync(
      exePath(channel),
      ['channel', channel],
    );

    _log.fine('$folder set to $channel channel');
    _log.fine('upgrading $channel to latest version');

    Process.runSync(
      exePath(channel),
      ['upgrade'],
    );

    _log.fine('$channel upgraded to version ${channelVersion(channel)}');
  }

  void _cloneMaster() {
    _log.info('setting up master');

    const gitRepo = 'https://github.com/flutter/flutter.git';

    _log.fine('cloning master from $gitRepo');

    Process.runSync(
      'git',
      ['clone', gitRepo, '.'],
      workingDirectory: _masterSdkDir.path,
    );

    _log.fine('master upgraded to version ${channelVersion('master')}');
  }

  void _copy(String from, String to) {
    _log.fine('copying $from -> $to');
    Process.runSync('xcopy', ['/E', '/I', '/H', from, to]);
  }
}

const patchString = '''
@ECHO off
SET fcs_cmd=%1

IF /I "%fcs_cmd%"=="channel" (
    ECHO Please use "fcs channel" command instead
    EXIT /B
)

IF /I "%fcs_cmd%"=="upgrade" (
    ECHO Please use "fcs upgrade" command instead
    EXIT /B
)
''';
