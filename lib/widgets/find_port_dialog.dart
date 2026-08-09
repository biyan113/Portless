import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/port_process.dart';
import '../services/agent_service.dart';
import '../theme/app_theme.dart';

Future<void> showFindPortDialog(BuildContext context, AgentService agent) async {
  await showDialog<void>(
    context: context,
    builder: (ctx) => _FindPortDialog(agent: agent),
  );
}

class _FindPortDialog extends StatefulWidget {
  const _FindPortDialog({required this.agent});
  final AgentService agent;

  @override
  State<_FindPortDialog> createState() => _FindPortDialogState();
}

class _FindPortDialogState extends State<_FindPortDialog> {
  final _controller = TextEditingController(text: '3000');
  bool _loading = false;
  String? _error;
  List<PortProcess> _occupied = const [];
  FreePortResult? _free;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _lookup() async {
    final port = int.tryParse(_controller.text.trim());
    if (port == null || port < 1 || port > 65535) {
      setState(() => _error = '请输入 1–65535 之间的端口');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final occupied = await widget.agent.findPort(port);
      final free = await widget.agent.findFree(from: port, count: 5);
      if (!mounted) return;
      setState(() {
        _occupied = occupied;
        _free = free;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '$e';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppTheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppTheme.border),
      ),
      title: const Text('Find Port', style: TextStyle(color: AppTheme.text, fontSize: 16)),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    style: const TextStyle(color: AppTheme.text),
                    decoration: const InputDecoration(hintText: '例如 3000'),
                    onSubmitted: (_) => _lookup(),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: _loading ? null : _lookup,
                  child: _loading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('查询'),
                ),
              ],
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: const TextStyle(color: AppTheme.danger, fontSize: 12)),
            ],
            if (_occupied.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(
                'Port ${_occupied.first.port} is occupied',
                style: const TextStyle(color: AppTheme.warn, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              ..._occupied.map(
                (p) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.surface2,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppTheme.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(p.displayName, style: const TextStyle(color: AppTheme.text, fontWeight: FontWeight.w600)),
                        Text('PID ${p.pid}', style: const TextStyle(color: AppTheme.textMuted, fontSize: 12)),
                        if (p.workingDirectory != null)
                          Text(p.workingDirectory!, style: const TextStyle(color: AppTheme.textMuted, fontSize: 12)),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          children: [
                            TextButton(
                              onPressed: () async {
                                await widget.agent.kill(p.pid);
                                if (context.mounted) _lookup();
                              },
                              child: const Text('Kill & Retry'),
                            ),
                            TextButton(
                              onPressed: () async {
                                await widget.agent.kill(p.pid, force: true);
                                if (context.mounted) _lookup();
                              },
                              child: const Text('Force Kill', style: TextStyle(color: AppTheme.danger)),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ] else if (_free != null && _occupied.isEmpty && !_loading) ...[
              const SizedBox(height: 16),
              Text(
                'Port ${_controller.text} is free',
                style: const TextStyle(color: AppTheme.success, fontWeight: FontWeight.w600),
              ),
            ],
            if (_free != null) ...[
              const SizedBox(height: 12),
              Text(
                'Nearest available: ${_free!.nearest ?? '—'}',
                style: const TextStyle(color: AppTheme.textMuted, fontSize: 12),
              ),
              const SizedBox(height: 6),
              Text(
                'Available: ${_free!.available.join(', ')}',
                style: const TextStyle(color: AppTheme.textMuted, fontSize: 12),
              ),
              if (_free!.nearest != null)
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: () async {
                      await Clipboard.setData(ClipboardData(text: '${_free!.nearest}'));
                    },
                    icon: const Icon(Icons.copy, size: 14),
                    label: const Text('复制空闲端口'),
                  ),
                ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('关闭')),
      ],
    );
  }
}
