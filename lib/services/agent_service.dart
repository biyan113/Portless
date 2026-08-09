import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

import '../models/port_process.dart';
import '../models/process_insight.dart';

/// Talks to the Rust `portless_agent` binary over JSON stdout.
/// Architecture keeps Flutter free of OS-level port/process logic.
class AgentService {
  AgentService({String? agentPath}) : _overridePath = agentPath;

  final String? _overridePath;
  String? _resolved;

  Future<String> resolveAgentPath() async {
    if (_resolved != null) return _resolved!;
    if (_overridePath != null) {
      _resolved = _overridePath;
      return _resolved!;
    }

    final candidates = <String>[];

    // 1) Next to the running executable (release packaging)
    try {
      final exe = File(Platform.resolvedExecutable);
      final exeDir = exe.parent.path;
      if (Platform.isMacOS) {
        // App.app/Contents/MacOS/portless → Resources/portless_agent
        candidates.add(p.join(exeDir, 'portless_agent'));
        candidates.add(p.join(exeDir, '..', 'Resources', 'portless_agent'));
        candidates.add(p.join(exeDir, '..', 'Helpers', 'portless_agent'));
      } else if (Platform.isWindows) {
        candidates.add(p.join(exeDir, 'portless_agent.exe'));
      }
    } catch (_) {}

    // 2) Dev: walk up from cwd / script looking for native/target/release
    var dir = Directory.current;
    for (var i = 0; i < 8; i++) {
      final release = p.join(
        dir.path,
        'native',
        'target',
        'release',
        Platform.isWindows ? 'portless_agent.exe' : 'portless_agent',
      );
      candidates.add(release);
      final debug = p.join(
        dir.path,
        'native',
        'target',
        'debug',
        Platform.isWindows ? 'portless_agent.exe' : 'portless_agent',
      );
      candidates.add(debug);
      final parent = dir.parent;
      if (parent.path == dir.path) break;
      dir = parent;
    }

    // 3) Explicit env
    final env = Platform.environment['PORTLESS_AGENT'];
    if (env != null && env.isNotEmpty) candidates.insert(0, env);

    for (final c in candidates) {
      final f = File(c);
      if (await f.exists()) {
        _resolved = f.absolute.path;
        debugPrint('Portless agent: $_resolved');
        return _resolved!;
      }
    }

    throw AgentException(
      'portless_agent not found. Build with:\n'
      '  cd native && cargo build --release\n'
      'Or set PORTLESS_AGENT to the binary path.\n'
      'Tried:\n${candidates.map((e) => '  - $e').join('\n')}',
    );
  }

  Future<PortSnapshot> list() async {
    final json = await _run(['list']);
    return PortSnapshot.fromJson(json);
  }

  Future<List<PortProcess>> findPort(int port) async {
    final json = await _run(['find', '--port', '$port']);
    final items = json['items'] as List<dynamic>? ?? const [];
    return items
        .map((e) => PortProcess.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<FreePortResult> findFree({int from = 3000, int count = 5}) async {
    final json = await _run([
      'free',
      '--from',
      '$from',
      '--count',
      '$count',
    ]);
    return FreePortResult.fromJson(json);
  }

  Future<({bool ok, String message})> kill(int pid, {bool force = false}) async {
    final args = ['kill', '--pid', '$pid'];
    if (force) args.add('--force');
    final json = await _run(args);
    return (
      ok: json['ok'] as bool? ?? false,
      message: json['message'] as String? ?? '',
    );
  }

  Future<({bool ok, String message})> reveal(String path) async {
    final json = await _run(['reveal', '--path', path]);
    return (
      ok: json['ok'] as bool? ?? false,
      message: json['message'] as String? ?? '',
    );
  }

  /// DeepSeek 解读指定端口的进程。
  Future<ExplainResult> explain(int port) async {
    final json = await _run(['explain', '--port', '$port']);
    return ExplainResult.fromJson(json);
  }

  Future<Map<String, dynamic>> _run(List<String> args) async {
    final agent = await resolveAgentPath();
    final result = await Process.run(
      agent,
      args,
      stdoutEncoding: utf8,
      stderrEncoding: utf8,
    );
    if (result.exitCode != 0) {
      final err = (result.stderr as String).trim();
      final out = (result.stdout as String).trim();
      throw AgentException(
        err.isNotEmpty ? err : (out.isNotEmpty ? out : 'agent exit ${result.exitCode}'),
      );
    }
    final out = (result.stdout as String).trim();
    if (out.isEmpty) {
      throw AgentException('agent returned empty output');
    }
    final decoded = jsonDecode(out);
    if (decoded is! Map<String, dynamic>) {
      throw AgentException('agent returned non-object JSON');
    }
    if (decoded.containsKey('error')) {
      throw AgentException('${decoded['error']}');
    }
    return decoded;
  }
}

class AgentException implements Exception {
  AgentException(this.message);
  final String message;
  @override
  String toString() => message;
}
