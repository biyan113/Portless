import 'package:flutter/material.dart';

import '../models/port_process.dart';
import '../theme/app_theme.dart';

class PortTable extends StatelessWidget {
  const PortTable({
    super.key,
    required this.items,
    required this.selectedKey,
    required this.favorites,
    required this.onSelect,
    required this.onToggleFavorite,
  });

  final List<PortProcess> items;
  final String? selectedKey;
  final Set<int> favorites;
  final ValueChanged<PortProcess> onSelect;
  final ValueChanged<PortProcess> onToggleFavorite;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          height: 36,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: const BoxDecoration(
            color: AppTheme.surface,
            border: Border(bottom: BorderSide(color: AppTheme.border)),
          ),
          child: const Row(
            children: [
              _H('PORT', 72),
              Expanded(flex: 3, child: _H('PROCESS', 0)),
              Expanded(flex: 2, child: _H('PROJECT', 0)),
              _H('PID', 72),
              _H('PROTO', 56),
              _H('CPU', 64),
              _H('MEMORY', 80),
              Expanded(flex: 4, child: _H('ADDRESS', 0)),
            ],
          ),
        ),
        Expanded(
          child: items.isEmpty
              ? const Center(
                  child: Text(
                    '没有匹配的监听端口',
                    style: TextStyle(color: AppTheme.textMuted),
                  ),
                )
              : ListView.builder(
                  itemCount: items.length,
                  itemBuilder: (context, i) {
                    final item = items[i];
                    final selected = item.key == selectedKey;
                    final fav = favorites.contains(item.port);
                    return _Row(
                      item: item,
                      selected: selected,
                      favorite: fav,
                      onTap: () => onSelect(item),
                      onFav: () => onToggleFavorite(item),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _H extends StatelessWidget {
  const _H(this.label, this.width);
  final String label;
  final double width;

  @override
  Widget build(BuildContext context) {
    final child = Text(
      label,
      style: const TextStyle(
        color: AppTheme.textMuted,
        fontSize: 10,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.6,
      ),
    );
    if (width <= 0) return child;
    return SizedBox(width: width, child: child);
  }
}

class _Row extends StatefulWidget {
  const _Row({
    required this.item,
    required this.selected,
    required this.favorite,
    required this.onTap,
    required this.onFav,
  });

  final PortProcess item;
  final bool selected;
  final bool favorite;
  final VoidCallback onTap;
  final VoidCallback onFav;

  @override
  State<_Row> createState() => _RowState();
}

class _RowState extends State<_Row> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final bg = widget.selected
        ? AppTheme.accentSoft
        : _hover
            ? AppTheme.surface2
            : Colors.transparent;

    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: bg,
            border: const Border(bottom: BorderSide(color: AppTheme.border, width: 0.5)),
          ),
          child: Row(
            children: [
              SizedBox(
                width: 72,
                child: Row(
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      margin: const EdgeInsets.only(right: 8),
                      decoration: BoxDecoration(
                        color: item.isDev ? AppTheme.dev : AppTheme.success,
                        shape: BoxShape.circle,
                      ),
                    ),
                    Text(
                      '${item.port}',
                      style: const TextStyle(
                        color: AppTheme.text,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        fontFamily: AppTheme.mono,
                        fontFeatures: [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                flex: 3,
                child: Text(
                  item.displayName,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppTheme.text,
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                    fontFamily: AppTheme.mono,
                  ),
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  item.projectName ?? '—',
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: AppTheme.textMuted, fontSize: 12),
                ),
              ),
              SizedBox(
                width: 72,
                child: Text(
                  '${item.pid}',
                  style: const TextStyle(
                    color: AppTheme.textMuted,
                    fontSize: 12,
                    fontFamily: AppTheme.mono,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
              ),
              SizedBox(
                width: 56,
                child: Text(
                  item.protocol == PortProtocol.tcp ? 'TCP' : 'UDP',
                  style: const TextStyle(color: AppTheme.textMuted, fontSize: 11),
                ),
              ),
              SizedBox(
                width: 64,
                child: Text(
                  item.cpuUsage != null ? '${item.cpuUsage!.toStringAsFixed(1)}%' : '—',
                  style: const TextStyle(
                    color: AppTheme.textMuted,
                    fontSize: 12,
                    fontFamily: AppTheme.mono,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
              ),
              SizedBox(
                width: 80,
                child: Text(
                  _fmtMem(item.memoryUsage),
                  style: const TextStyle(
                    color: AppTheme.textMuted,
                    fontSize: 12,
                    fontFamily: AppTheme.mono,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
              ),
              Expanded(
                flex: 4,
                child: Text(
                  item.copyAddress,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppTheme.textMuted,
                    fontSize: 11,
                    fontFamily: AppTheme.mono,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                tooltip: widget.favorite ? '取消收藏' : '收藏端口',
                onPressed: widget.onFav,
                icon: Icon(
                  widget.favorite ? Icons.star_rounded : Icons.star_outline_rounded,
                  size: 16,
                  color: widget.favorite ? AppTheme.warn : AppTheme.textMuted,
                ),
              ),
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
