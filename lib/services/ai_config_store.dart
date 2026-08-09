import 'dart:convert';
import 'dart:io';

/// AI（DeepSeek）配置的 UI 模型。
class AiUiConfig {
  const AiUiConfig({
    this.apiKey = '',
    this.baseUrl = 'https://api.deepseek.com',
    this.model = 'deepseek-v4-flash',
    this.thinking = false,
  });

  final String apiKey;
  final String baseUrl;
  final String model;
  final bool thinking;
}

/// 读写 DeepSeek 配置文件，与 Rust 端 `ai::AiConfigFile` 字段一致（snake_case）。
/// 保存到用户级 `~/.portless/config.json`（优先级高于项目本地配置）。
class AiConfigStore {
  static const defaultBase = 'https://api.deepseek.com';
  static const defaultModel = 'deepseek-v4-flash';

  File get _homeFile {
    final home = Platform.environment['HOME'] ??
        Platform.environment['USERPROFILE'] ??
        '.';
    return File('$home/.portless/config.json');
  }

  File get _localFile => File('.portless.local.json');

  /// 读取 local + home 合并后的当前生效配置（home 优先），用于回显。
  Future<AiUiConfig> load() async {
    final local = await _readJson(_localFile);
    final home = await _readJson(_homeFile);
    return AiUiConfig(
      apiKey: _str(_pick(home, 'api_key'), _str(_pick(local, 'api_key'), '')),
      baseUrl: _str(_pick(home, 'base_url'), _str(_pick(local, 'base_url'), defaultBase)),
      model: _str(_pick(home, 'model'), _str(_pick(local, 'model'), defaultModel)),
      thinking: (_pick(home, 'thinking') == true) || (_pick(local, 'thinking') == true),
    );
  }

  /// 写入用户级配置文件（保留目录自动创建，snake_case 与 Rust 端一致）。
  Future<void> save(AiUiConfig cfg) async {
    final dir = _homeFile.parent;
    if (!await dir.exists()) await dir.create(recursive: true);
    final map = <String, dynamic>{
      'api_key': cfg.apiKey,
      'base_url': cfg.baseUrl,
      'model': cfg.model,
      'thinking': cfg.thinking,
    };
    await _homeFile.writeAsString(
      const JsonEncoder.withIndent('  ').convert(map),
      flush: true,
    );
  }

  Future<Map<String, dynamic>> _readJson(File f) async {
    try {
      if (!await f.exists()) return const {};
      final json = jsonDecode(await f.readAsString());
      if (json is Map<String, dynamic>) return json;
      return const {};
    } catch (_) {
      return const {};
    }
  }

  /// snake_case 优先，兼容 camelCase 遗留字段。
  static dynamic _pick(Map<String, dynamic> m, String key) {
    final v = m[key];
    if (v != null) return v;
    if (key == 'api_key') return m['apiKey'];
    if (key == 'base_url') return m['baseUrl'];
    if (key == 'model') return m['model'];
    if (key == 'thinking') return m['thinking'];
    return null;
  }

  static String _str(dynamic v, String fallback) {
    if (v is String && v.trim().isNotEmpty) return v.trim();
    return fallback;
  }
}
