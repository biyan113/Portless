import 'package:flutter/material.dart';

import '../services/ai_config_store.dart';
import '../theme/app_theme.dart';

/// 设置对话框：常规（自动刷新）、AI 解读配置与缓存管理、关于信息。
class SettingsDialog extends StatefulWidget {
  const SettingsDialog({
    super.key,
    required this.autoRefresh,
    required this.onAutoRefreshChanged,
    required this.cachedCount,
    required this.onClearCache,
  });

  final bool autoRefresh;
  final ValueChanged<bool> onAutoRefreshChanged;
  final int cachedCount;
  final VoidCallback onClearCache;

  @override
  State<SettingsDialog> createState() => _SettingsDialogState();
}

class _SettingsDialogState extends State<SettingsDialog> {
  late bool _autoRefresh;
  late int _cached;

  // AI 配置表单
  final _store = AiConfigStore();
  final _modelCtrl = TextEditingController();
  final _baseUrlCtrl = TextEditingController();
  final _apiKeyCtrl = TextEditingController();
  bool _thinking = false;
  bool _aiLoaded = false;
  bool _obscureKey = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _autoRefresh = widget.autoRefresh;
    _cached = widget.cachedCount;
    _loadAiConfig();
  }

  @override
  void dispose() {
    _modelCtrl.dispose();
    _baseUrlCtrl.dispose();
    _apiKeyCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadAiConfig() async {
    final cfg = await _store.load();
    if (!mounted) return;
    setState(() {
      _modelCtrl.text = cfg.model;
      _baseUrlCtrl.text = cfg.baseUrl;
      _apiKeyCtrl.text = cfg.apiKey;
      _thinking = cfg.thinking;
      _aiLoaded = true;
    });
  }

  Future<void> _saveAi() async {
    setState(() => _saving = true);
    try {
      await _store.save(AiUiConfig(
        apiKey: _apiKeyCtrl.text.trim(),
        baseUrl: _baseUrlCtrl.text.trim().isEmpty
            ? AiConfigStore.defaultBase
            : _baseUrlCtrl.text.trim(),
        model: _modelCtrl.text.trim().isEmpty
            ? AiConfigStore.defaultModel
            : _modelCtrl.text.trim(),
        thinking: _thinking,
      ));
      if (!mounted) return;
      _toast('AI 配置已保存（~/.portless/config.json）');
    } catch (e) {
      if (!mounted) return;
      _toast('保存失败：$e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppTheme.surface2,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppTheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppTheme.border),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _header(),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(18, 12, 18, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _sectionTitle('常规'),
                    _autoRefreshTile(),
                    const SizedBox(height: 18),
                    _sectionTitle('AI 解读'),
                    _aiConfig(),
                    const SizedBox(height: 16),
                    _cacheTile(),
                    const SizedBox(height: 18),
                    _sectionTitle('关于'),
                    _aboutTile(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _header() {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 12, 10, 8),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppTheme.border)),
      ),
      child: Row(
        children: [
          const Icon(Icons.settings_outlined, size: 16, color: AppTheme.text),
          const SizedBox(width: 8),
          const Text(
            '设置',
            style: TextStyle(color: AppTheme.text, fontSize: 13, fontWeight: FontWeight.w600),
          ),
          const Spacer(),
          IconButton(
            tooltip: '关闭',
            visualDensity: VisualDensity.compact,
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.close_rounded, size: 16, color: AppTheme.textMuted),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        title,
        style: const TextStyle(
          color: AppTheme.textMuted,
          fontSize: 10,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.4,
        ),
      ),
    );
  }

  Widget _autoRefreshTile() {
    return SwitchListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      title: const Text(
        '自动刷新',
        style: TextStyle(color: AppTheme.text, fontSize: 12, fontWeight: FontWeight.w500),
      ),
      subtitle: const Text(
        '每 2 秒刷新端口与进程状态',
        style: TextStyle(color: AppTheme.textMuted, fontSize: 10),
      ),
      value: _autoRefresh,
      activeThumbColor: AppTheme.accent,
      onChanged: (v) {
        setState(() => _autoRefresh = v);
        widget.onAutoRefreshChanged(v);
      },
    );
  }

  Widget _aiConfig() {
    if (!_aiLoaded) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 10),
        child: Center(
          child: SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _field(
          _modelCtrl,
          '模型',
          hint: 'deepseek-v4-flash',
          mono: true,
        ),
        _field(
          _baseUrlCtrl,
          'Base URL',
          hint: 'https://api.deepseek.com',
          mono: true,
        ),
        _keyField(),
        SwitchListTile(
          dense: true,
          contentPadding: EdgeInsets.zero,
          title: const Text(
            '深度思考',
            style: TextStyle(color: AppTheme.text, fontSize: 12, fontWeight: FontWeight.w500),
          ),
          subtitle: const Text(
            '启用推理模式（较慢但解读更深入）',
            style: TextStyle(color: AppTheme.textMuted, fontSize: 10),
          ),
          value: _thinking,
          activeThumbColor: AppTheme.accent,
          onChanged: (v) => setState(() => _thinking = v),
        ),
        const SizedBox(height: 4),
        Align(
          alignment: Alignment.centerRight,
          child: FilledButton.icon(
            onPressed: _saving ? null : _saveAi,
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.accent,
              visualDensity: VisualDensity.compact,
            ),
            icon: _saving
                ? const SizedBox(
                    width: 13,
                    height: 13,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.save_outlined, size: 14),
            label: const Text('保存 AI 配置', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
          ),
        ),
      ],
    );
  }

  Widget _field(TextEditingController c, String label, {String? hint, bool mono = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextField(
        controller: c,
        style: TextStyle(
          color: AppTheme.text,
          fontSize: 12,
          fontFamily: mono ? AppTheme.mono : null,
        ),
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          isDense: true,
        ),
      ),
    );
  }

  Widget _keyField() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextField(
        controller: _apiKeyCtrl,
        obscureText: _obscureKey,
        style: const TextStyle(color: AppTheme.text, fontSize: 12, fontFamily: AppTheme.mono),
        decoration: InputDecoration(
          labelText: 'API Key',
          hintText: 'sk-…（可留空沿用环境变量）',
          isDense: true,
          suffixIcon: IconButton(
            tooltip: _obscureKey ? '显示' : '隐藏',
            visualDensity: VisualDensity.compact,
            icon: Icon(
              _obscureKey ? Icons.visibility_outlined : Icons.visibility_off_outlined,
              size: 15,
              color: AppTheme.textMuted,
            ),
            onPressed: () => setState(() => _obscureKey = !_obscureKey),
          ),
        ),
      ),
    );
  }

  Widget _cacheTile() {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'AI 解读缓存',
                style: TextStyle(color: AppTheme.text, fontSize: 12, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 3),
              Text(
                '已缓存 $_cached 个端口的解读（30 分钟内复用）',
                style: const TextStyle(color: AppTheme.textMuted, fontSize: 10),
              ),
            ],
          ),
        ),
        TextButton.icon(
          onPressed: _cached == 0
              ? null
              : () {
                  setState(() => _cached = 0);
                  widget.onClearCache();
                },
          icon: const Icon(Icons.delete_outline_rounded, size: 14),
          label: const Text('清除', style: TextStyle(fontSize: 11)),
        ),
      ],
    );
  }

  Widget _aboutTile() {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Text(
                'Portless',
                style: TextStyle(color: AppTheme.text, fontSize: 12, fontWeight: FontWeight.w500),
              ),
              SizedBox(height: 3),
              Text(
                '本地端口 / 进程 / 开发服务管理器 · v0.1.0',
                style: TextStyle(color: AppTheme.textMuted, fontSize: 10),
              ),
            ],
          ),
        ),
        const Icon(Icons.developer_board_outlined, size: 15, color: AppTheme.textMuted),
      ],
    );
  }
}
