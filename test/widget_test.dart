import 'package:flutter_test/flutter_test.dart';
import 'package:portless/models/port_process.dart';

void main() {
  test('PortProcess.fromJson maps camelCase fields', () {
    final p = PortProcess.fromJson({
      'port': 5173,
      'protocol': 'tcp',
      'address': '127.0.0.1',
      'pid': 22104,
      'processName': 'node',
      'stack': 'Vite',
      'projectName': 'demo',
      'isDev': true,
      'state': 'listen',
    });
    expect(p.port, 5173);
    expect(p.displayName, 'Vite');
    expect(p.copyAddress, 'localhost:5173');
    expect(p.isDev, isTrue);
  });
}
