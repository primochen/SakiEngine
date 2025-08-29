import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sakiengine/src/config/saki_engine_config.dart';
import 'package:sakiengine/src/utils/scaling_manager.dart';
import 'package:sakiengine/src/widgets/common/close_button.dart';
import 'package:sakiengine/src/widgets/common/window_background_widget.dart';

class OverlayScaffold extends StatelessWidget {
  final String title;
  final Widget content;
  final Widget? footer;
  final VoidCallback onClose;

  const OverlayScaffold({
    super.key,
    required this.title,
    required this.content,
    this.footer,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final config = SakiEngineConfig();
    final uiScale = context.scaleFor(ComponentType.ui);
    final textScale = context.scaleFor(ComponentType.text);

    return Shortcuts(
      shortcuts: <LogicalKeySet, Intent>{
        LogicalKeySet(LogicalKeyboardKey.escape): const _CloseIntent(),
      },
      child: Actions(
        actions: <Type, Action<Intent>>{
          _CloseIntent: _CloseAction(onClose),
        },
        child: Focus(
          autofocus: true,
          child: GestureDetector(
            onTap: onClose,
            child: Container(
              width: double.infinity,
              height: double.infinity,
              decoration: BoxDecoration(
                color: config.themeColors.primaryDark.withOpacity(0.5 * config.baseWindowAlpha),
              ),
              child: GestureDetector(
                onTap: () {},
                child: Center(
                  child: WindowBackgroundWidget(
                    config: config,
                    child: Container(
                      width: screenSize.width * 0.85,
                      height: screenSize.height * 0.8,
                      decoration: BoxDecoration(
                        color: config.themeColors.background.withOpacity(0.95 * config.baseWindowAlpha),
                        borderRadius: BorderRadius.circular(config.baseWindowBorder),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.3),
                            blurRadius: 20 * uiScale,
                            offset: Offset(0, 8 * uiScale),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(config.baseWindowBorder),
                        child: Column(
                          children: [
                            _buildHeader(uiScale, textScale, config),
                            Expanded(child: content),
                            if (footer != null) footer!,
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(double uiScale, double textScale, SakiEngineConfig config) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: 32 * uiScale,
        vertical: 20 * uiScale,
      ),
      decoration: BoxDecoration(
        color: config.themeColors.primary.withOpacity(0.1),
        border: Border(
          bottom: BorderSide(
            color: config.themeColors.primary.withOpacity(0.3),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          Text(
            title,
            style: config.reviewTitleTextStyle.copyWith(
              fontSize: config.reviewTitleTextStyle.fontSize! * textScale,
              color: config.themeColors.primary,
              letterSpacing: 2.0,
            ),
          ),
          const Spacer(),
          CommonCloseButton(
            scale: uiScale,
            onClose: onClose,
          ),
        ],
      ),
    );
  }
}

class _CloseIntent extends Intent {
  const _CloseIntent();
}

class _CloseAction extends Action<_CloseIntent> {
  final VoidCallback onClose;

  _CloseAction(this.onClose);

  @override
  Object? invoke(_CloseIntent intent) {
    onClose();
    return null;
  }
}