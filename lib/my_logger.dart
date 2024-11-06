import 'package:intl/intl.dart';
import 'package:logger/logger.dart' as lib_logger;

class MyLogger {
  static final formatter = DateFormat('HH:mm:ss.SSS');

  final lib_logger.Logger _libInfoLogger = lib_logger.Logger(
      filter: ReleaseLogsFilter(),
      printer: lib_logger.PrettyPrinter(
        methodCount: 0,
        printEmojis: false,
        excludeBox: {lib_logger.Level.info: true, lib_logger.Level.debug: true},
        levelColors: {
          lib_logger.Level.warning: const lib_logger.AnsiColor.fg(28),
          lib_logger.Level.debug: const lib_logger.AnsiColor.fg(202)
        },
      ));

  void i(final dynamic message, {final String? tag}) {
    String msg = "";
    if (tag != null) {
      msg = "${_getTime()} | $tag | $message";
    } else {
      msg = "${_getTime()} | $message";
    }
    _libInfoLogger.i(msg, time: DateTime.now());
  }

  void w(final dynamic message, {final String? tag}) {
    String msg = "";
    if (tag != null) {
      msg = "${_getTime()} | $tag | $message";
    } else {
      msg = "${_getTime()} | $message";
    }
    _libInfoLogger.w(msg, time: DateTime.now());
  }

  void e(final dynamic message, final dynamic error, final StackTrace? stackTrace, {final String? tag}) {
    String msg = "";
    if (tag != null) {
      msg = "${_getTime()} | $tag | $message";
    } else {
      msg = "${_getTime()} | $message";
    }
    _libInfoLogger.e(msg, time: DateTime.now(), error: error, stackTrace: stackTrace);
  }

  void d(final dynamic message, {final String? tag}) {
    String msg = "";
    if (tag != null) {
      msg = "${_getTime()} | $tag | $message";
    } else {
      msg = "${_getTime()} | $message";
    }
    _libInfoLogger.d(msg, time: DateTime.now());
  }

  static String _getTime() {
    final now = DateTime.now();
    return formatter.format(now);
  }
}

///Allows logs in release mode
class ReleaseLogsFilter extends lib_logger.LogFilter {
  @override
  bool shouldLog(lib_logger.LogEvent event) => true;
}
