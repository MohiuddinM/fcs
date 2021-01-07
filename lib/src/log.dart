import 'package:quick_log/quick_log.dart';

class FcsLogger extends Logger {
  const FcsLogger(String name) : super(name, 'fcs');
}

class FcsWriter extends LogWriter {
  FcsWriter([LogLevel minLevel = LogLevel.info])
      : super(['fcs'], null, null, minLevel);

  @override
  Future<void> write(LogMessage msg) async {
    var color = '';
    if (shouldLog(msg)) {
      if (msg.level == LogLevel.fine) {
        color = '\x1b[92m';
      } else if (msg.level == LogLevel.info || msg.level == LogLevel.debug) {
        color = '\x1b[93m';
      } else if (msg.level == LogLevel.warning) {
        color = '\x1b[31m';
      } else if (msg.level == LogLevel.error) {
        color = '\x1b[97;41m';
      }

      print('$color${msg.message}\x1b[0m');
    }
  }
}
