import 'package:flutter/material.dart';
import 'package:sakiengine/src/config/saki_engine_config.dart';

class GameStyleDropdownItem<T> {
  final T value;
  final String label;
  final IconData? icon;

  const GameStyleDropdownItem({
    required this.value,
    required this.label,
    this.icon,
  });
}

class GameStyleDropdown<T> extends StatefulWidget {
  final List<GameStyleDropdownItem<T>> items;
  final T value;
  final ValueChanged<T> onChanged;
  final double scale;
  final double textScale;
  final SakiEngineConfig config;
  final double? width;

  const GameStyleDropdown({
    super.key,
    required this.items,
    required this.value,
    required this.onChanged,
    required this.scale,
    required this.textScale,
    required this.config,
    this.width,
  });

  @override
  State<GameStyleDropdown<T>> createState() => _GameStyleDropdownState<T>();
}

class _GameStyleDropdownState<T> extends State<GameStyleDropdown<T>> {
  bool _isHovered = false;
  bool _isOpen = false;

  GameStyleDropdownItem<T> get _selectedItem {
    final index = widget.items.indexWhere((item) => item.value == widget.value);
    if (index == -1) {
      return widget.items.first;
    }
    return widget.items[index];
  }

  @override
  Widget build(BuildContext context) {
    final config = widget.config;
    final scale = widget.scale;
    final textScale = widget.textScale;
    final selectedItem = _selectedItem;

    final backgroundColor = _isOpen
        ? config.themeColors.background.withOpacity(0.95)
        : config.themeColors.background.withOpacity(_isHovered ? 0.85 : 0.8);

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: PopupMenuButton<T>(
        padding: EdgeInsets.zero,
        tooltip: '',
        onOpened: () => setState(() => _isOpen = true),
        onCanceled: () => setState(() => _isOpen = false),
        onSelected: (value) {
          setState(() => _isOpen = false);
          widget.onChanged(value);
        },
        itemBuilder: (context) {
          return widget.items.map((item) {
            final isSelected = item.value == selectedItem.value;
            return PopupMenuItem<T>(
              value: item.value,
              padding: EdgeInsets.symmetric(
                horizontal: 16 * scale,
                vertical: 8 * scale,
              ),
              child: Row(
                children: [
                  if (item.icon != null) ...[
                    Icon(
                      item.icon,
                      size: 18 * scale,
                      color: isSelected
                          ? config.themeColors.primary
                          : config.themeColors.onSurfaceVariant,
                    ),
                    SizedBox(width: 12 * scale),
                  ],
                  Expanded(
                    child: Text(
                      item.label,
                      style: config.dialogueTextStyle.copyWith(
                        fontSize: config.dialogueTextStyle.fontSize! * textScale * 0.6,
                        color: isSelected
                            ? config.themeColors.primary
                            : config.themeColors.onSurfaceVariant,
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                      ),
                    ),
                  ),
                  if (isSelected)
                    Icon(
                      Icons.check_rounded,
                      size: 18 * scale,
                      color: config.themeColors.primary,
                    ),
                ],
              ),
            );
          }).toList();
        },
        offset: Offset(0, 40 * scale),
        color: config.themeColors.surface.withOpacity(0.92),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(4 * scale),
          side: BorderSide(
            color: config.themeColors.primary.withOpacity(0.2),
            width: 1,
          ),
        ),
        child: Container(
          width: widget.width ?? 180 * scale,
          padding: EdgeInsets.symmetric(
            horizontal: 16 * scale,
            vertical: 10 * scale,
          ),
          decoration: BoxDecoration(
            color: backgroundColor,
            border: Border.all(
              color: config.themeColors.primary.withOpacity(_isHovered ? 0.6 : 0.4),
              width: 1,
            ),
            boxShadow: _isHovered
                ? [
                    BoxShadow(
                      color: config.themeColors.primary.withOpacity(0.1),
                      blurRadius: 8 * scale,
                      offset: Offset(0, 4 * scale),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (selectedItem.icon != null) ...[
                Icon(
                  selectedItem.icon,
                  size: 18 * scale,
                  color: config.themeColors.primary,
                ),
                SizedBox(width: 12 * scale),
              ],
              Expanded(
                child: Text(
                  selectedItem.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: config.dialogueTextStyle.copyWith(
                    fontSize: config.dialogueTextStyle.fontSize! * textScale * 0.6,
                    color: config.themeColors.primary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              SizedBox(width: 12 * scale),
              Icon(
                _isOpen ? Icons.expand_less : Icons.expand_more,
                size: 20 * scale,
                color: config.themeColors.primary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
