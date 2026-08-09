import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/port_process.dart';
import '../models/process_insight.dart';
import '../theme/app_theme.dart';
import 'insight_card.dart';

/// AI 解读的加载阶段。
enum AiPhase { idle, loading, done, error }

/// 右侧详情抽屉：点击列表条目后在右侧滑出的详情面板。
class DetailDrawer extends StatelessWidget {
  const DetailDrawer({
    super.key,
    required this.item,
    required this.onClose,
    required this.onOpenBrowser,
    required this.onOpenFolder,
    required this.onRevealExe,
    required this.onStop,
    required this.onForceKill,
    required this.onCopy,
    this.aiPhase = AiPhase.idle,
    this.aiInsight,
    this.aiError,
    this.aiFromCache = false,
    this.onExplain,
    this.onRetry,
  });

  final PortProcess item;
  final VoidCallback onClose;
  final VoidCallback onOpenBrowser;
  final VoidCallback onOpenFolder;
  final VoidCallback onRevealExe;
  final VoidCallback onStop;
  final VoidCallback onForceKill;
  final VoidCallback onCopy;

  final AiPhase aiPhase;
  final ProcessInsight? aiInsight;
  final String? aiError;
  final bool aiFromCache;
  final VoidCallback? onExplain;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final p = item;
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: AppTheme.surface,
        border: Border(left: BorderSide(color: AppTheme.border)),
      ),
      child: Column(
        children: [
          _header(),
          const Divider(height: 1, color: AppTheme.border),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
              children: [
                _titleBlock(p),
                const SizedBox(height: 14),
                _infoBlock(p),
                const SizedBox(height: 18),
                _aiSection(p),
              ],
            ),
          ),
          _actions(p),
        ],
      ),
    );
  }

  Widget _header() {
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: const BoxDecoration(
        color: AppTheme.surface,
        border: Border(bottom: BorderSide(color: AppTheme.border)),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline_rounded, size: 15, color: AppTheme.textMuted),
          const SizedBox(width: 6),
          const Text(
            '详情',
            style: TextStyle(color: AppTheme.text, fontSize: 12, fontWeight: FontWeight.w600),
          ),
          const Spacer(),
          IconButton(
            tooltip: '关闭详情',
            visualDensity: VisualDensity.compact,
            onPressed: onClose,
            icon: const Icon(Icons.close_rounded, size: 16, color: AppTheme.textMuted),
          ),
        ],
      ),
    );
  }

  Widget _titleBlock(PortProcess p) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Text(
                p.copyAddress,
                style: const TextStyle(
                  color: AppTheme.text,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  fontFamily: AppTheme.mono,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
            ),
            _stateBadge(p.state),
          ],
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _chip(p.displayName, AppTheme.dev),
            if (p.projectName != null) _chip(p.projectName!, AppTheme.accent),
          ],
        ),
      ],
    );
  }

  Widget _infoBlock(PortProcess p) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _kv('PID', '${p.pid}', mono: true),
        _kv('协议', p.protocol == PortProtocol.tcp ? 'TCP' : 'UDP', mono: true),
        _kv('监听地址', p.address, mono: true),
        _kv('CPU', p.cpuUsage != null ? '${p.cpuUsage!.toStringAsFixed(1)}%' : '—', mono: true),
        _kv('内存', _fmtMem(p.memoryUsage), mono: true),
        _kv('进程', p.processName),
        if (p.workingDirectory != null) ...[
          const SizedBox(height: 4),
          _pathLabel('工作目录', p.workingDirectory!),
        ],
        if (p.executablePath != null) ...[
          const SizedBox(height: 4),
          _pathLabel('可执行文件', p.executablePath!),
        ],
        if (p.commandLine != null) ...[
          const SizedBox(height: 4),
          _pathLabel('命令行', p.commandLine!),
        ],
        if (p.stack?.isNotEmpty ?? false) ...[
          const SizedBox(height: 4),
          _pathLabel('技术栈', p.stack!),
        ],
      ],
    );
  }

  Widget _aiSection(PortProcess p) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              'AI 解读',
              style: TextStyle(color: AppTheme.textMuted, fontSize: 11, fontWeight: FontWeight.w600),
            ),
            if (aiFromCache && aiPhase == AiPhase.done) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: AppTheme.accentSoft,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  '已缓存',
                  style: TextStyle(color: AppTheme.accent, fontSize: 9, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 8),
        switch (aiPhase) {
          AiPhase.idle => _aiIdle(p),
          AiPhase.loading => _aiLoading(p),
          AiPhase.done => aiInsight == null ? _aiErrorBox('解读失败：无数据') : InsightCard(insight: aiInsight!),
          AiPhase.error => _aiErrorBox(aiError ?? '解读失败'),
        },
      ],
    );
  }

  Widget _aiIdle(PortProcess p) {
    return OutlinedButton.icon(
      onPressed: onExplain,
      style: OutlinedButton.styleFrom(
        foregroundColor: AppTheme.accent,
        side: const BorderSide(color: AppTheme.accent, width: 1),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      ),
      icon: const Icon(Icons.auto_awesome_rounded, size: 15),
      label: Text('用 DeepSeek 解读 :${p.port}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
    );
  }

  Widget _aiLoading(PortProcess p) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      decoration: BoxDecoration(
        color: AppTheme.surface2,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.border),
      ),
      child: Row(
        children: [
          const SizedBox(
            width: 15,
            height: 15,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '正在用 DeepSeek 解读 :${p.port}…',
              style: const TextStyle(color: AppTheme.textMuted, fontSize: 11),
            ),
          ),
        ],
      ),
    );
  }

  Widget _aiErrorBox(String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.surface2,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.danger.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.error_outline_rounded, size: 15, color: AppTheme.danger),
              const SizedBox(width: 6),
              const Text('解读失败', style: TextStyle(color: AppTheme.danger, fontSize: 12, fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            message,
            style: const TextStyle(color: AppTheme.textMuted, fontSize: 10, height: 1.4),
          ),
          if (onRetry != null) ...[
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded, size: 14),
              label: const Text('重试', style: TextStyle(fontSize: 11)),
            ),
          ],
        ],
      ),
    );
  }

  Widget _kv(String label, String value, {bool mono = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 72,
            child: Text(
              label,
              style: const TextStyle(color: AppTheme.textMuted, fontSize: 11),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: AppTheme.text,
                fontSize: 11,
                fontFamily: mono ? AppTheme.mono : null,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _pathLabel(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: AppTheme.textMuted, fontSize: 11)),
          const SizedBox(height: 3),
          SelectableText(
            value,
            style: const TextStyle(color: AppTheme.text, fontSize: 11, fontFamily: AppTheme.mono),
          ),
        ],
      ),
    );
  }

  Widget _actions(PortProcess p) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
      decoration: const BoxDecoration(
        color: AppTheme.surface,
        border: Border(top: BorderSide(color: AppTheme.border)),
      ),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          _action('浏览器打开', Icons.open_in_browser_rounded, onOpenBrowser),
          _action('打开目录', Icons.folder_open_rounded, onOpenFolder),
          _action('复制地址', Icons.copy_rounded, onCopy),
          if (p.executablePath != null)
            _action('定位程序', Icons.my_location_rounded, onRevealExe),
          _action('停止进程', Icons.stop_circle_outlined, onStop, tone: AppTheme.warn),
          _action('强制结束', Icons.dangerous_outlined, onForceKill, tone: AppTheme.danger),
        ],
      ),
    );
  }

  Widget _stateBadge(PortState s) {
    final (label, color) = switch (s) {
      PortState.listen => ('LISTEN', AppTheme.success),
      PortState.established => ('ESTABLISHED', AppTheme.accent),
      PortState.closeWait => ('CLOSE_WAIT', AppTheme.warn),
      PortState.timeWait => ('TIME_WAIT', AppTheme.textMuted),
      PortState.other => ('OTHER', AppTheme.textMuted),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _chip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _action(
    String label,
    IconData icon,
    VoidCallback onTap, {
    Color tone = AppTheme.text,
  }) {
    return Material(
      color: AppTheme.surface2,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 14, color: tone),
              const SizedBox(width: 6),
              Text(label, style: TextStyle(color: tone, fontSize: 11, fontWeight: FontWeight.w500)),
            ],
          ),
        ),
      ),
    );
  }

  String _fmtMem(int? bytes) {
    if (bytes == null) return '—';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(0)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(0)} MB';
  }
}

Future<void> copyText(String text) async {
  await Clipboard.setData(ClipboardData(text: text));
}
