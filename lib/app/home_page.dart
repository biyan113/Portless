import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/port_process.dart';
import '../models/process_insight.dart';
import '../services/agent_service.dart';
import '../services/favorites_store.dart';
import '../theme/app_theme.dart';
import '../widgets/detail_drawer.dart';
import '../widgets/find_port_dialog.dart';
import '../widgets/port_table.dart';
import '../widgets/settings_dialog.dart';
import '../widgets/sidebar.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key, required this.agent});

  final AgentService agent;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _favorites = FavoritesStore();
  final _search = TextEditingController();
  final _searchFocus = FocusNode();

  List<PortProcess> _items = const [];
  Set<int> _favPorts = {};
  SidebarFilter _filter = SidebarFilter.all;
  String? _selectedKey;
  PortProcess? _selected;
  String? _error;
  bool _loading = true;
  bool _autoRefresh = true;
  Timer? _timer;
  DateTime? _lastScan;

  // AI 解读状态（绑定到当前选中端口）
  AiPhase _aiPhase = AiPhase.idle;
  ProcessInsight? _aiInsight;
  String? _aiError;
  bool _aiFromCache = false;

  // AI 解读缓存：按端口缓存，TTL 内重复打开不重新请求 DeepSeek
  static const _aiCacheTtl = Duration(minutes: 30);
  final Map<int, _AiCacheEntry> _aiCache = {};

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    _favPorts = await _favorites.load();
    final prefs = await SharedPreferences.getInstance();
    _autoRefresh = prefs.getBool('auto_refresh') ?? true;
    await _refresh();
    _timer = Timer.periodic(const Duration(seconds: 2), (_) {
      if (_autoRefresh) _refresh(silent: true);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _search.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  Future<void> _refresh({bool silent = false}) async {
    if (!silent) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final snap = await widget.agent.list();
      if (!mounted) return;
      setState(() {
        _items = snap.items;
        _lastScan = DateTime.fromMillisecondsSinceEpoch(snap.scannedAtMs);
        _loading = false;
        _error = null;
        if (_selectedKey != null) {
          final still = snap.items.where((e) => e.key == _selectedKey).toList();
          if (still.isEmpty) {
            _selected = null;
            _selectedKey = null;
          } else {
            _selected = still.first;
          }
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '$e';
        _loading = false;
      });
    }
  }

  List<PortProcess> get _filtered {
    final q = _search.text.trim().toLowerCase();
    Iterable<PortProcess> list = _items;

    switch (_filter) {
      case SidebarFilter.all:
        break;
      case SidebarFilter.dev:
        list = list.where((e) => e.isDev);
      case SidebarFilter.system:
        list = list.where((e) => !e.isDev);
      case SidebarFilter.favorites:
        list = list.where((e) => _favPorts.contains(e.port));
      case SidebarFilter.tcp:
        list = list.where((e) => e.protocol == PortProtocol.tcp);
      case SidebarFilter.udp:
        list = list.where((e) => e.protocol == PortProtocol.udp);
    }

    if (q.isNotEmpty) {
      list = list.where((e) {
        return '${e.port}'.contains(q) ||
            '${e.pid}'.contains(q) ||
            e.processName.toLowerCase().contains(q) ||
            (e.stack?.toLowerCase().contains(q) ?? false) ||
            (e.projectName?.toLowerCase().contains(q) ?? false) ||
            (e.commandLine?.toLowerCase().contains(q) ?? false) ||
            e.address.toLowerCase().contains(q);
      });
    }

    final out = list.toList()
      ..sort((a, b) {
        final c = a.port.compareTo(b.port);
        if (c != 0) return c;
        return a.pid.compareTo(b.pid);
      });
    return out;
  }

  int get _devCount => _items.where((e) => e.isDev).length;
  int get _systemCount => _items.where((e) => !e.isDev).length;
  int get _tcpCount => _items.where((e) => e.protocol == PortProtocol.tcp).length;
  int get _udpCount => _items.where((e) => e.protocol == PortProtocol.udp).length;
  int get _favCount => _items.where((e) => _favPorts.contains(e.port)).length;

  Future<void> _toggleFav(PortProcess p) async {
    final next = await _favorites.toggle(p.port);
    setState(() => _favPorts = next);
  }

  /// 对指定进程发起 DeepSeek 解读；TTL 内缓存命中则直接展示，不再调 API。
  Future<void> _explain(PortProcess p) async {
    final cached = _aiCache[p.port];
    if (cached != null && DateTime.now().difference(cached.at) < _aiCacheTtl) {
      setState(() {
        _aiPhase = AiPhase.done;
        _aiInsight = cached.insight;
        _aiError = null;
        _aiFromCache = true;
      });
      return;
    }
    setState(() {
      _aiPhase = AiPhase.loading;
      _aiError = null;
      _aiInsight = null;
      _aiFromCache = false;
    });
    try {
      final r = await widget.agent.explain(p.port);
      if (!mounted) return;
      if (r.data != null) {
        _aiCache[p.port] = _AiCacheEntry(r.data!, DateTime.now());
      }
      setState(() {
        _aiPhase = AiPhase.done;
        _aiInsight = r.data;
        _aiError = r.message;
        _aiFromCache = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _aiPhase = AiPhase.error;
        _aiError = '$e';
        _aiFromCache = false;
      });
    }
  }

  Future<void> _openBrowser(PortProcess p) async {
    final uri = Uri.parse(p.localhostUrl);
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _openFolder(PortProcess p) async {
    final path = p.workingDirectory ?? p.executablePath;
    if (path == null) {
      _toast('没有可打开的路径');
      return;
    }
    if (Platform.isMacOS) {
      await Process.run('open', [path]);
    } else if (Platform.isWindows) {
      await Process.run('explorer', [path]);
    }
  }

  Future<void> _revealExe(PortProcess p) async {
    final path = p.executablePath;
    if (path == null) {
      _toast('没有可执行文件路径');
      return;
    }
    try {
      final r = await widget.agent.reveal(path);
      if (!r.ok) _toast(r.message);
    } catch (e) {
      _toast('$e');
    }
  }

  Future<void> _kill(PortProcess p, {required bool force}) async {
    final label = force ? '强制结束' : '停止';
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: Text('$label PID ${p.pid}？'),
        content: Text(
          '${p.displayName} · :${p.port}\n'
          '${force ? '将发送 SIGKILL / TerminateProcess' : '将发送 SIGTERM（优雅停止）'}',
          style: const TextStyle(color: AppTheme.textMuted, fontSize: 13),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: force ? AppTheme.danger : AppTheme.warn,
            ),
            child: Text(label),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      final r = await widget.agent.kill(p.pid, force: force);
      _toast(r.message);
      await Future<void>.delayed(const Duration(milliseconds: 300));
      await _refresh();
    } catch (e) {
      _toast('$e');
    }
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppTheme.surface2,
      ),
    );
  }

  Future<void> _showSettings() async {
    await showDialog<void>(
      context: context,
      builder: (ctx) => SettingsDialog(
        autoRefresh: _autoRefresh,
        onAutoRefreshChanged: (v) async {
          setState(() => _autoRefresh = v);
          final prefs = await SharedPreferences.getInstance();
          await prefs.setBool('auto_refresh', v);
        },
        cachedCount: _aiCache.length,
        onClearCache: () => setState(_aiCache.clear),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyK, meta: true): () {
          _searchFocus.requestFocus();
        },
        const SingleActivator(LogicalKeyboardKey.keyK, control: true): () {
          _searchFocus.requestFocus();
        },
        const SingleActivator(LogicalKeyboardKey.keyF, meta: true): () {
          showFindPortDialog(context, widget.agent);
        },
        const SingleActivator(LogicalKeyboardKey.keyR, meta: true): () {
          _refresh();
        },
      },
      child: Focus(
        autofocus: true,
        child: Scaffold(
          body: Column(
            children: [
              _toolbar(filtered.length),
              Expanded(
                child: Row(
                  children: [
                    Sidebar(
                      selected: _filter,
                      onSelect: (f) => setState(() => _filter = f),
                      total: _items.length,
                      devCount: _devCount,
                      systemCount: _systemCount,
                      favCount: _favCount,
                      tcpCount: _tcpCount,
                      udpCount: _udpCount,
                    ),
                    Expanded(
                      child: Column(
                        children: [
                          if (_error != null)
                            MaterialBanner(
                              content: Text(_error!, style: const TextStyle(color: AppTheme.danger)),
                              backgroundColor: AppTheme.surface2,
                              actions: [
                                TextButton(onPressed: _refresh, child: const Text('重试')),
                              ],
                            ),
                          Expanded(
                            child: Row(
                              children: [
                                Expanded(
                                  child: _loading && _items.isEmpty
                                      ? const Center(child: CircularProgressIndicator())
                                      : PortTable(
                                          items: filtered,
                                          selectedKey: _selectedKey,
                                          favorites: _favPorts,
                                          onSelect: (p) {
                                            setState(() {
                                              if (p.key != _selectedKey) {
                                                final cached = _aiCache[p.port];
                                                if (cached != null &&
                                                    DateTime.now().difference(cached.at) < _aiCacheTtl) {
                                                  _aiPhase = AiPhase.done;
                                                  _aiInsight = cached.insight;
                                                  _aiError = null;
                                                  _aiFromCache = true;
                                                } else {
                                                  _aiPhase = AiPhase.idle;
                                                  _aiInsight = null;
                                                  _aiError = null;
                                                  _aiFromCache = false;
                                                }
                                              }
                                              _selected = p;
                                              _selectedKey = p.key;
                                            });
                                          },
                                          onToggleFavorite: _toggleFav,
                                        ),
                                ),
                                AnimatedSize(
                                  duration: const Duration(milliseconds: 220),
                                  curve: Curves.easeOutCubic,
                                  alignment: Alignment.centerLeft,
                                  child: _selected == null
                                      ? const SizedBox(width: 0, height: double.infinity)
                                      : SizedBox(
                                          width: 340,
                                          child: DetailDrawer(
                                            item: _selected!,
                                            aiPhase: _aiPhase,
                                            aiInsight: _aiInsight,
                                            aiError: _aiError,
                                            aiFromCache: _aiFromCache,
                                            onExplain: () => _explain(_selected!),
                                            onRetry: () => _explain(_selected!),
                                            onClose: () => setState(() {
                                              _selected = null;
                                              _selectedKey = null;
                                              _aiPhase = AiPhase.idle;
                                              _aiInsight = null;
                                              _aiError = null;
                                              _aiFromCache = false;
                                            }),
                                            onOpenBrowser: () {
                                              if (_selected != null) _openBrowser(_selected!);
                                            },
                                            onOpenFolder: () {
                                              if (_selected != null) _openFolder(_selected!);
                                            },
                                            onRevealExe: () {
                                              if (_selected != null) _revealExe(_selected!);
                                            },
                                            onStop: () {
                                              if (_selected != null) _kill(_selected!, force: false);
                                            },
                                            onForceKill: () {
                                              if (_selected != null) _kill(_selected!, force: true);
                                            },
                                            onCopy: () async {
                                              if (_selected == null) return;
                                              await copyText(_selected!.copyAddress);
                                              _toast('已复制 ${_selected!.copyAddress}');
                                            },
                                          ),
                                        ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _toolbar(int visibleCount) {
    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: const BoxDecoration(
        color: AppTheme.surface,
        border: Border(bottom: BorderSide(color: AppTheme.border)),
      ),
      child: Row(
        children: [
          const Text(
            'Portless',
            style: TextStyle(
              color: AppTheme.text,
              fontSize: 14,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: AppTheme.surface2,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: AppTheme.border),
            ),
            child: Text(
              '$visibleCount Listening',
              style: const TextStyle(color: AppTheme.textMuted, fontSize: 10),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: TextField(
                controller: _search,
                focusNode: _searchFocus,
                onChanged: (_) => setState(() {}),
                style: const TextStyle(color: AppTheme.text, fontSize: 12),
                decoration: InputDecoration(
                  hintText: '搜索端口 / 进程 / PID / 项目  ⌘K',
                  prefixIcon: const Icon(Icons.search, size: 16, color: AppTheme.textMuted),
                  suffixIcon: _search.text.isEmpty
                      ? null
                      : IconButton(
                          icon: const Icon(Icons.close, size: 14),
                          onPressed: () {
                            _search.clear();
                            setState(() {});
                          },
                        ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          IconButton(
            tooltip: 'Find Port (⌘F)',
            onPressed: () => showFindPortDialog(context, widget.agent),
            icon: const Icon(Icons.travel_explore_rounded, color: AppTheme.textMuted, size: 17),
          ),
          IconButton(
            tooltip: _autoRefresh ? '自动刷新：开 (2s)' : '自动刷新：关',
            onPressed: () => setState(() => _autoRefresh = !_autoRefresh),
            icon: Icon(
              _autoRefresh ? Icons.autorenew_rounded : Icons.pause_circle_outline,
              color: _autoRefresh ? AppTheme.accent : AppTheme.textMuted,
              size: 17,
            ),
          ),
          IconButton(
            tooltip: '立即刷新 (⌘R)',
            onPressed: _refresh,
            icon: const Icon(Icons.refresh_rounded, color: AppTheme.textMuted, size: 17),
          ),
          if (_lastScan != null)
            Padding(
              padding: const EdgeInsets.only(left: 4),
              child: Text(
                _fmtTime(_lastScan!),
                style: const TextStyle(color: AppTheme.textMuted, fontSize: 10),
              ),
            ),
          const SizedBox(width: 4),
          IconButton(
            tooltip: '设置',
            onPressed: _showSettings,
            icon: const Icon(Icons.settings_outlined, color: AppTheme.textMuted, size: 17),
          ),
        ],
      ),
    );
  }

  String _fmtTime(DateTime t) {
    final h = t.hour.toString().padLeft(2, '0');
    final m = t.minute.toString().padLeft(2, '0');
    final s = t.second.toString().padLeft(2, '0');
    return '$h:$m:$s';
  }
}

/// AI 解读缓存条目：保留解读结果与写入时间，TTL 内复用。
class _AiCacheEntry {
  _AiCacheEntry(this.insight, this.at);

  final ProcessInsight insight;
  final DateTime at;
}
