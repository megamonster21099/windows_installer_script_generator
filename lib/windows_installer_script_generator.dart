library windows_installer_script_generator;

import 'dart:io';
import 'package:package_config/package_config.dart';
import 'package:path/path.dart' as path;
import 'package:uuid/uuid.dart';
import 'package:windows_installer_script_generator/my_logger.dart';
import 'package:yaml/yaml.dart';

class WindowsInstallerScriptGenerator {
  static const String _tag = "WindowsInstallerScriptGenerator";
  static const String _outputFileName = "windows_installer_script.iss";
  final MyLogger _logger = MyLogger();
  final String _outputDefaultDir = path.join(path.current, "windows_installer_script_generator");
  final String _windowsIconDefaultPath = path.joinAll([path.current, "windows", "runner", "resources", "app_icon.ico"]);
  final String _releaseDir = path.joinAll([path.current, "build", "windows", "x64", "runner", "Release"]);

  /// Execute with the `windows_installer_script_generator:make` command
  Future<void> make(final List<String> args) async {
    final String pubspecString = await File("pubspec.yaml").readAsString();
    final dynamic pubspec = loadYaml(pubspecString);

    _log("Starting Windows Installer Script Generator");

    final String? appName = _getAppName(pubspec);
    if (appName == null) return;
    _log("appName = $appName");

    final String exeName = "$appName.exe";
    _log("exeName = $exeName");

    final String appVersion = _getAppVersion(pubspec);
    _log("appVersion = $appVersion");

    final dynamic config = pubspec['windows_installer_script_generator_config'] ?? YamlMap();

    final String displayName = _getAppDisplayName(config, appName);
    _log("displayName = $displayName");

    final String publisher = _getPublisher(config);
    _log("publisher = $publisher");

    final String scriptOutputDir = _getScriptOutputDir(config);
    _log("scriptOutputDir = $scriptOutputDir");

    final String installerOutput = _getInstallerOutputPath(config);
    _log("installerOutput = $installerOutput");

    final String projectPath = path.current;
    _log("projectPath = $projectPath");

    final String uuid = const Uuid().v1();
    _log("uuid = $uuid");

    final String iconPath = _getIconPath(config);
    _log("iconPath = $iconPath");

    _log("releaseDir = $_releaseDir");

    final String? assetsPath = await _getAssetsFolderPath();
    if (assetsPath == null) return;

    if (!(await _copyDlls(assetsPath, _releaseDir))) return;

    final List<String>? pluginsDlls = await _getPluginsDlls(_releaseDir);
    if (pluginsDlls == null) return;

    String pluginsDllsSection = "";
    for (var e in pluginsDlls) {
      pluginsDllsSection += "Source: \"{#MyInputDir}\\$e\"; DestDir: \"{app}\"; Flags: ignoreversion\n";
    }

    final String? template = await _loadScriptTemplate(assetsPath);
    if (template == null) return;

    String script = template
        .replaceAll("<APP_NAME>", displayName)
        .replaceAll("<APP_EXE_NAME>", exeName)
        .replaceAll("<APP_VERSION>", appVersion)
        .replaceAll("<PUBLISHER>", publisher)
        .replaceAll("<UUID>", uuid)
        .replaceAll("<INPUT_DIR>", _releaseDir)
        .replaceAll("<ICON>", iconPath)
        .replaceAll("<OUTPUT_DIR>", installerOutput)
        .replaceAll("<PLUGINS_DLLS>", pluginsDllsSection);

    final String? resultPath = await _saveScript(script, scriptOutputDir);

    if (resultPath != null) {
      _logSuccess("Script saved to: $resultPath");
    }
  }

  Future<String?> _saveScript(final String script, final String dir) async {
    _logLongOperation("Saving script");
    final File file;
    try {
      final Directory directory = Directory(dir);
      if (!(await directory.exists())) {
        _log("Creating directory $dir");
        await directory.create();
      }
      file = File(path.join(dir, _outputFileName));
      _log("Writing file to ${file.path}");
      await file.writeAsString(script);
    } catch (e, stackTrace) {
      _logFatalError("Failed to save script", e, stackTrace);
      return null;
    }
    return file.path;
  }

  Future<bool> _copyDlls(final String assetsPath, final String releaseDir) async {
    final Directory releaseDirectory = Directory(releaseDir);
    if (!(await releaseDirectory.exists())) {
      _logFatalError(
          "Release directory not exists. Make sure that you made a build with 'flutter build windows' command before running the script generator",
          null,
          null);
      return false;
    }
    _logLongOperation("Copying DLLs to ${releaseDirectory.path}");
    if (!(await _copyDll("msvcp140.dll", assetsPath, "${releaseDirectory.path}\\"))) return false;
    if (!(await _copyDll("vcruntime140.dll", assetsPath, releaseDirectory.path))) return false;
    if (!(await _copyDll("vcruntime140_1.dll", assetsPath, releaseDirectory.path))) return false;
    return true;
  }

  Future<bool> _copyDll(final String dll, final String assetsPath, final String releaseDir) async {
    _log(dll);
    try {
      final File sourceFile = File(path.join(assetsPath, dll));
      final File destFile = File(path.join(releaseDir, dll));
      if (await destFile.exists()) {
        _log("Rewriting ${destFile.path}");
        await destFile.delete();
      }
      await sourceFile.copy(destFile.path);
      return true;
    } catch (e, stackTrace) {
      _logFatalError("Could not copy $dll", e, stackTrace);
      return false;
    }
  }

  Future<List<String>?> _getPluginsDlls(final String releaseDir) async {
    _logLongOperation("Reading project files");
    List<String> pluginsDlls = [];
    try {
      List<FileSystemEntity> list = Directory(releaseDir).listSync();
      for (var e in list) {
        if (e is! Directory) {
          pluginsDlls.add(path.basename(e.path));
          _log(pluginsDlls.last);
        }
      }
      return pluginsDlls;
    } catch (e, stackTrace) {
      _logFatalError("Could not read project files", e, stackTrace);
      return null;
    }
  }

  String? _getAppName(final dynamic pubspec) {
    if (pubspec['name'] == null || pubspec['name'] is! String) {
      _logFatalError("Could not find app name in pubspec.yaml", null, null);
      return null;
    } else {
      final appName = pubspec['name'];
      if (appName.isEmpty) {
        _logFatalError("App name is empty in pubspec.yaml", null, null);
        return null;
      } else {
        return appName;
      }
    }
  }

  Future<String?> _getAssetsFolderPath() async {
    PackageConfig? packagesConfig = await findPackageConfig(Directory.current);
    if (packagesConfig == null) {
      _logFatalError("Failed to locate or read package config.", null, null);
      return null;
    }

    Package? myPackage = packagesConfig['windows_installer_script_generator'];

    if (myPackage == null) {
      final scriptFile = File.fromUri(Platform.script);
      packagesConfig = await findPackageConfig(scriptFile.parent);
      myPackage = packagesConfig?['windows_installer_script_generator'];
    }

    if (myPackage == null) {
      _logFatalError("Failed to locate plugin assets path.", null, null);
      return null;
    }

    String path = '${myPackage.packageUriRoot.toString().replaceAll('file:///', '')}assets';

    return Uri.decodeFull(path);
  }

  Future<String?> _loadScriptTemplate(final String assetsPath) async {
    final String contents;
    try {
      final File script = File(path.join(assetsPath, "script_template.iss"));
      contents = await script.readAsString();
      return contents;
    } catch (e, stackTrace) {
      _logFatalError("Failed to read script template file.", e, stackTrace);
      return null;
    }
  }

  String _getAppDisplayName(final dynamic yaml, final String appName) {
    if (yaml['app_display_name'] == null || yaml['app_display_name'] is! String) return appName;
    final String displayName = yaml['app_display_name'];
    return displayName;
  }

  String _getAppVersion(final dynamic yaml) {
    if (yaml['version'] == null || yaml['version'] is! String) return "1.0.0";
    final String version = yaml['version'];
    if (version.contains("+")) {
      return version.split("+").first;
    } else {
      return version;
    }
  }

  String _getPublisher(final dynamic yaml) {
    if (yaml['publisher'] == null || yaml['publisher'] is! String) return "Unknown";
    final String publisher = yaml['publisher'];
    return publisher;
  }

  String _getIconPath(final dynamic yaml) {
    if (yaml['icon'] == null || yaml['icon'] is! String) {
      return _windowsIconDefaultPath;
    } else {
      return yaml['icon'];
    }
  }

  String _getScriptOutputDir(final dynamic yaml) {
    if (yaml['script_output_dir'] == null || yaml['script_output_dir'] is! String) {
      return _outputDefaultDir;
    } else {
      String outputDir = yaml['script_output_dir'];
      if (outputDir.endsWith("\\") || outputDir.endsWith("/")) {
        outputDir = outputDir.substring(0, outputDir.length - 1);
      }
      return outputDir;
    }
  }

  String _getInstallerOutputPath(final dynamic yaml) {
    if (yaml['installer_output_dir'] == null || yaml['installer_output_dir'] is! String) {
      return _outputDefaultDir;
    } else {
      String outputDir = yaml['installer_output_dir'];
      if (outputDir.endsWith("\\") || outputDir.endsWith("/")) {
        outputDir = outputDir.substring(0, outputDir.length - 1);
      }
      return outputDir;
    }
  }

  void _logSuccess(final String message) {
    _logger.w(tag: _tag, message);
  }

  void _logLongOperation(final String message) {
    _logger.d(tag: _tag, message);
  }

  void _log(final String message) {
    _logger.i(tag: _tag, message);
  }

  void _logFatalError(final String message, dynamic e, dynamic stackTrace) {
    _logger.e(tag: _tag, "FAILED! Error: $message", e, stackTrace);
  }
}
