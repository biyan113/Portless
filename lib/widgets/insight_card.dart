import 'package:flutter/material.dart';

import '../models/process_insight.dart';
import '../theme/app_theme.dart';

/// DeepSeek 结构化解读卡 —— 固定模板渲染 `ProcessInsight`。
class InsightCard extends StatelessWidget {
  const InsightCard({super.key, required this.insight});

  final ProcessInsight insight;

  @override
  Widget build(BuildContext context) {
    final i = insight;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.surface2,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.auto_awesome_rounded, size: 14, color: AppTheme.accent),
              const SizedBox(width: 6),
              const Text(
                'AI 解读',
                style: TextStyle(color: AppTheme.textMuted, fontSize: 10, fontWeight: FontWeight.w600),
              ),
              const Spacer(),
              _chip(_categoryLabel(i.category), _categoryColor(i.category)),
              const SizedBox(width: 6),
              Text(
                '${(i.confidence * 100).round()}% 置信',
                style: const TextStyle(color: AppTheme.textMuted, fontSize: 9),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            i.headline,
            style: const TextStyle(color: AppTheme.text, fontSize: 14, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(
            '${i.serviceName} · ${i.stack}',
            style: const TextStyle(color: AppTheme.accent, fontSize: 11, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 8),
          Text(
            i.purpose,
            style: const TextStyle(color: AppTheme.text, fontSize: 11, height: 1.5),
          ),
          const SizedBox(height: 10),
          _stopAdvice(i),
          if (i.actions.isNotEmpty) ...[
            const SizedBox(height: 12),
            const Text('可操作建议', style: TextStyle(color: AppTheme.textMuted, fontSize: 10, fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            for (final a in i.actions) _bullet(a, Icons.check_circle_outline_rounded, AppTheme.success),
          ],
          if (i.risks.isNotEmpty) ...[
            const SizedBox(height: 10),
            const Text('风险点', style: TextStyle(color: AppTheme.textMuted, fontSize: 10, fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            for (final r in i.risks) _bullet(r, Icons.error_outline_rounded, AppTheme.warn),
          ],
          if (i.notes.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              '补充：${i.notes}',
              style: const TextStyle(color: AppTheme.textMuted, fontSize: 10, height: 1.4),
            ),
          ],
        ],
      ),
    );
  }

  Widget _stopAdvice(ProcessInsight i) {
    final (label, color) = switch (i.stopAdvice) {
      'safe' => ('可安全停止', AppTheme.success),
      'do_not' => ('请勿停止', AppTheme.danger),
      _ => ('谨慎停止', AppTheme.warn),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.stop_circle_outlined, size: 15, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '$label — ${i.stopImpact}',
              style: TextStyle(color: color, fontSize: 11, height: 1.4, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  Widget _bullet(String text, IconData icon, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(color: AppTheme.text, fontSize: 11, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }

  String _categoryLabel(String c) {
    return switch (c) {
      'dev' => '开发',
      'system' => '系统',
      'database' => '数据库',
      'proxy' => '代理',
      'runtime' => '运行时',
      _ => '未知',
    };
  }

  Color _categoryColor(String c) {
    return switch (c) {
      'dev' => AppTheme.accent,
      'system' => AppTheme.textMuted,
      'database' => AppTheme.warn,
      'proxy' => AppTheme.dev,
      'runtime' => AppTheme.success,
      _ => AppTheme.textMuted,
    };
  }

  Widget _chip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.w600),
      ),
    );
  }
}
