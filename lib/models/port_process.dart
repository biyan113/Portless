enum PortProtocol { tcp, udp }

enum PortState { listen, established, closeWait, timeWait, other }

class PortProcess {
  final int port;
  final PortProtocol protocol;
  final String address;
  final int pid;
  final String processName;
  final String? executablePath;
  final String? commandLine;
  final String? workingDirectory;
  final double? cpuUsage;
  final int? memoryUsage;
  final PortState state;
  final String? stack;
  final String? projectName;
  final bool isDev;

  const PortProcess({
    required this.port,
    required this.protocol,
    required this.address,
    required this.pid,
    required this.processName,
    this.executablePath,
    this.commandLine,
    this.workingDirectory,
    this.cpuUsage,
    this.memoryUsage,
    this.state = PortState.listen,
    this.stack,
    this.projectName,
    this.isDev = false,
  });

  String get displayName => stack?.isNotEmpty == true ? stack! : processName;

  String get localhostUrl {
    final host = _browserHost;
    return 'http://$host:$port';
  }

  String get copyAddress {
    final host = _copyHost;
    return '$host:$port';
  }

  String get _browserHost {
    final a = address.replaceAll(RegExp(r'^\[|\]$'), '');
    if (a == '0.0.0.0' || a == '*' || a == '::' || a == '::0') {
      return '127.0.0.1';
    }
    return a;
  }

  String get _copyHost {
    final a = address.replaceAll(RegExp(r'^\[|\]$'), '');
    if (a == '0.0.0.0' ||
        a == '*' ||
        a == '::' ||
        a == '::0' ||
        a == '127.0.0.1' ||
        a == '::1') {
      return 'localhost';
    }
    return a;
  }

  String get key => '$protocol:$port:$pid';

  factory PortProcess.fromJson(Map<String, dynamic> json) {
    return PortProcess(
      port: json['port'] as int,
      protocol: (json['protocol'] as String?) == 'udp'
          ? PortProtocol.udp
          : PortProtocol.tcp,
      address: json['address'] as String? ?? '0.0.0.0',
      pid: json['pid'] as int,
      processName: json['processName'] as String? ?? 'unknown',
      executablePath: json['executablePath'] as String?,
      commandLine: json['commandLine'] as String?,
      workingDirectory: json['workingDirectory'] as String?,
      cpuUsage: (json['cpuUsage'] as num?)?.toDouble(),
      memoryUsage: json['memoryUsage'] as int?,
      state: _parseState(json['state'] as String?),
      stack: json['stack'] as String?,
      projectName: json['projectName'] as String?,
      isDev: json['isDev'] as bool? ?? false,
    );
  }

  static PortState _parseState(String? s) {
    switch (s) {
      case 'listen':
        return PortState.listen;
      case 'established':
        return PortState.established;
      case 'closewait':
      case 'close_wait':
        return PortState.closeWait;
      case 'timewait':
      case 'time_wait':
        return PortState.timeWait;
      default:
        return PortState.other;
    }
  }
}

class PortSnapshot {
  final int scannedAtMs;
  final int count;
  final List<PortProcess> items;

  const PortSnapshot({
    required this.scannedAtMs,
    required this.count,
    required this.items,
  });

  factory PortSnapshot.fromJson(Map<String, dynamic> json) {
    final raw = json['items'] as List<dynamic>? ?? const [];
    return PortSnapshot(
      scannedAtMs: json['scannedAtMs'] as int? ?? 0,
      count: json['count'] as int? ?? raw.length,
      items: raw
          .map((e) => PortProcess.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

class FreePortResult {
  final int requested;
  final List<int> available;
  final int? nearest;

  const FreePortResult({
    required this.requested,
    required this.available,
    this.nearest,
  });

  factory FreePortResult.fromJson(Map<String, dynamic> json) {
    return FreePortResult(
      requested: json['requested'] as int,
      available: (json['available'] as List<dynamic>? ?? const [])
          .map((e) => e as int)
          .toList(),
      nearest: json['nearest'] as int?,
    );
  }
}
