import 'dart:io';

import 'package:flutter_app_packager/src/api/app_package_maker.dart';
import 'package:flutter_app_packager/src/makers/exe/inno_setup/inno_setup_compiler.dart';
import 'package:flutter_app_packager/src/makers/exe/inno_setup/inno_setup_script.dart';
import 'package:flutter_app_packager/src/makers/exe/make_exe_config.dart';
import 'package:io/io.dart';
import 'package:path/path.dart' as p;

class AppPackageMakerExe extends AppPackageMaker {
  @override
  String get name => 'exe';
  @override
  String get platform => 'windows';
  @override
  bool get isSupportedOnCurrentPlatform => Platform.isWindows;
  @override
  String get packageFormat => 'exe';

  @override
  MakeConfigLoader get configLoader {
    return MakeExeConfigLoader()
      ..platform = platform
      ..packageFormat = packageFormat;
  }

  @override
  Future<MakeResult> make(MakeConfig config) {
    return _make(
      config.buildOutputDirectory,
      outputDirectory: config.outputDirectory,
      makeConfig: config as MakeExeConfig,
    );
  }

  Future<MakeResult> _make(
    Directory appDirectory, {
    required Directory outputDirectory,
    required MakeExeConfig makeConfig,
  }) async {
    Directory packagingDirectory = makeConfig.packagingDirectory;
    copyPathSync(appDirectory.path, packagingDirectory.path);

    // 将 vc_redist.x64.exe 复制到 .iss 文件所在目录（dist/），
    // 以便 Inno Setup 编译时能找到该文件。
    // 若项目根目录不存在该文件则跳过（不影响现有构建流程）。
    final vcRedistSource = File('vc_redist.x64.exe');
    if (vcRedistSource.existsSync()) {
      final issDir = p.dirname('${packagingDirectory.path}.iss');
      final vcRedistDest = File(p.join(issDir, 'vc_redist.x64.exe'));
      if (!vcRedistDest.existsSync()) {
        vcRedistSource.copySync(vcRedistDest.path);
      }
    }

    InnoSetupScript script = InnoSetupScript.fromMakeConfig(makeConfig);
    InnoSetupCompiler compiler = InnoSetupCompiler();

    bool compiled = await compiler.compile(script);

    if (!compiled) {
      throw MakeError();
    }

    packagingDirectory.deleteSync(recursive: true);

    return MakeResult(makeConfig);
  }
}
