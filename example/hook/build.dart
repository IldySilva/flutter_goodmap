import 'package:flutter_gpu_shaders/build.dart';
import 'package:hooks/hooks.dart';

// Compiles shaders/globe.shaderbundle.json into
// build/shaderbundles/globe.shaderbundle during the app build.
void main(List<String> args) async {
  await build(args, (config, output) async {
    await buildShaderBundleJson(
      buildInput: config,
      buildOutput: output,
      manifestFileName: 'shaders/globe.shaderbundle.json',
    );
  });
}
