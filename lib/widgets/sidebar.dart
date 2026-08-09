import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

enum SidebarFilter {
  all,
  dev,
  system,
  favorites,
  tcp,
  udp,
}

class Sidebar extends StatelessWidget {
  const Sidebar({
    super.key,
    required this.selected,
    required this.onSelect,
    required this.total,
    required this.devCount,
    required this.systemCount,
    required this.favCount,
    required this.tcpCount,
    required this.udpCount,
  });

  final SidebarFilter selected;
  final ValueChanged<SidebarFilter> onSelect;
  final int total;
  final int devCount;
  final int systemCount;
  final int favCount;
  final int tcpCount;
  final int udpCount;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 196,
      decoration: const BoxDecoration(
        color: AppTheme.surface,
        border: Border(right: BorderSide(color: AppTheme.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 12),
          _item(SidebarFilter.all, '所有端口', total, Icons.hub_outlined),
          _item(SidebarFilter.dev, '开发服务', devCount, Icons.code_rounded),
          _item(SidebarFilter.system, '系统进程', systemCount, Icons.memory_rounded),
          _item(SidebarFilter.favorites, '已收藏', favCount, Icons.star_outline_rounded),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 14, 16, 8),
            child: Divider(height: 1, color: AppTheme.border),
          ),
          _item(SidebarFilter.tcp, 'TCP', tcpCount, Icons.swap_horiz_rounded),
          _item(SidebarFilter.udp, 'UDP', udpCount, Icons.cell_tower_rounded),
          const Spacer(),
          const Padding(
            padding: EdgeInsets.all(14),
            child: Text(
              'Portless  ·  local dev',
              style: TextStyle(color: AppTheme.textMuted, fontSize: 10),
            ),
          ),
        ],
      ),
    );
  }

  Widget _item(SidebarFilter f, String label, int count, IconData icon) {
    final active = selected == f;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      child: Material(
        color: active ? AppTheme.accentSoft : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () => onSelect(f),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
            child: Row(
              children: [
                Icon(
                  icon,
                  size: 15,
                  color: active ? AppTheme.accent : AppTheme.textMuted,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      color: active ? AppTheme.text : AppTheme.textMuted,
                      fontSize: 12,
                      fontWeight: active ? FontWeight.w600 : FontWeight.w500,
                    ),
                  ),
                ),
                Text(
                  '$count',
                  style: TextStyle(
                    color: active ? AppTheme.accent : AppTheme.textMuted,
                    fontSize: 11,
                    fontFamily: AppTheme.mono,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
