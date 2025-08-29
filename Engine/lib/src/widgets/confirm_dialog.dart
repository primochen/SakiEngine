import 'package:flutter/material.dart';
import 'package:sakiengine/src/config/saki_engine_config.dart';
import 'package:sakiengine/src/utils/scaling_manager.dart';
import 'package:sakiengine/src/utils/smart_asset_image.dart';

class ConfirmDialog extends StatefulWidget {
  final String title;
  final String content;
  final VoidCallback? onConfirm;
  final VoidCallback? onCancel;
  final bool? confirmResult;
  final bool? cancelResult;

  const ConfirmDialog({
    super.key,
    required this.title,
    required this.content,
    this.onConfirm,
    this.onCancel,
    this.confirmResult = true,
    this.cancelResult = false,
  });

  @override
  State<ConfirmDialog> createState() => _ConfirmDialogState();
}

class _ConfirmDialogState extends State<ConfirmDialog>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;
  late Animation<double> _backdropAnimation;

  @override
  void initState() {
    super.initState();
    
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 350),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(
      begin: 0.7,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.elasticOut,
    ));

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: const Interval(0.0, 0.7, curve: Curves.easeOut),
    ));

    _backdropAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: const Interval(0.0, 0.4, curve: Curves.easeOut),
    ));

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _handleClose([dynamic result]) async {
    await _animationController.reverse();
    if (mounted) {
      Navigator.of(context).pop(result);
    }
  }

  @override
  Widget build(BuildContext context) {
    final config = SakiEngineConfig();
    final uiScale = context.scaleFor(ComponentType.ui);
    final textScale = context.scaleFor(ComponentType.text);

    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return Material(
          type: MaterialType.transparency,
          child: GestureDetector(
            onTap: () => _handleClose(widget.cancelResult),
            child: Container(
              width: double.infinity,
              height: double.infinity,
              decoration: BoxDecoration(
                color: config.themeColors.primaryDark.withOpacity(0.1 * _backdropAnimation.value),
              ),
              child: GestureDetector(
                onTap: () {},
                child: Center(
                  child: Transform.scale(
                    scale: _scaleAnimation.value,
                    child: FadeTransition(
                      opacity: _fadeAnimation,
                      child: Container(
                        width: 480 * uiScale,
                        constraints: const BoxConstraints(),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(config.baseWindowBorder),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.3 * _fadeAnimation.value),
                              blurRadius: 20 * uiScale,
                              offset: Offset(0, 8 * uiScale),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(config.baseWindowBorder),
                          child: IntrinsicHeight(
                            child: Stack(
                              children: [
                                // 底层：纯色背景
                                Positioned.fill(
                                  child: Container(
                                    color: config.themeColors.background,
                                  ),
                                ),
                                // 中层：背景图片
                                if (config.baseWindowBackground != null && config.baseWindowBackground!.isNotEmpty)
                                  Positioned.fill(
                                    child: Opacity(
                                      opacity: config.baseWindowBackgroundAlpha,
                                      child: ColorFiltered(
                                        colorFilter: ColorFilter.mode(
                                          Colors.transparent,
                                          config.baseWindowBackgroundBlendMode,
                                        ),
                                        child: Align(
                                          alignment: Alignment(
                                            (config.baseWindowXAlign - 0.5) * 2,
                                            (config.baseWindowYAlign - 0.5) * 2,
                                          ),
                                          child: Transform.scale(
                                            scale: config.baseWindowBackgroundScale,
                                            child: SmartAssetImage(
                                              assetName: config.baseWindowBackground!,
                                              fit: BoxFit.contain,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                // 上层：半透明控件
                                Container(
                                  color: config.themeColors.background.withOpacity(config.baseWindowAlpha),
                                  padding: EdgeInsets.all(24 * uiScale),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        widget.title,
                                        textAlign: TextAlign.left,
                                        style: config.dialogueTextStyle.copyWith(
                                          fontSize: config.dialogueTextStyle.fontSize! * textScale * 1.2,
                                          fontWeight: FontWeight.bold,
                                          color: config.themeColors.primary,
                                        ),
                                      ),
                                      SizedBox(height: 16 * uiScale),
                                      Flexible(
                                        child: SingleChildScrollView(
                                          child: Text(
                                            widget.content,
                                            textAlign: TextAlign.left,
                                            style: config.dialogueTextStyle.copyWith(
                                              fontSize: config.dialogueTextStyle.fontSize! * textScale,
                                              color: config.themeColors.onSurface,
                                            ),
                                          ),
                                        ),
                                      ),
                                      SizedBox(height: 24 * uiScale),
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.start,
                                        children: [
                                          _buildButton(
                                            context, 
                                            '取消', 
                                            Icons.close_rounded,
                                            () {
                                              _handleClose(widget.cancelResult);
                                              widget.onCancel?.call();
                                            },
                                            uiScale,
                                            textScale,
                                            config,
                                            isNegative: true,
                                          ),
                                          SizedBox(width: 16 * uiScale),
                                          _buildButton(
                                            context, 
                                            '确定', 
                                            Icons.check_rounded,
                                            () {
                                              _handleClose(widget.confirmResult);
                                              widget.onConfirm?.call();
                                            },
                                            uiScale,
                                            textScale,
                                            config,
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
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
      },
    );
  }

  Widget _buildButton(
    BuildContext context, 
    String text, 
    IconData icon,
    VoidCallback onPressed, 
    double uiScale,
    double textScale,
    SakiEngineConfig config,
    {bool isNegative = false}
  ) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: 16 * uiScale,
            vertical: 8 * uiScale,
          ),
          decoration: BoxDecoration(
            color: isNegative 
              ? config.themeColors.background.withOpacity(0.6)
              : config.themeColors.primary.withOpacity(0.1),
            border: Border.all(
              color: isNegative 
                ? config.themeColors.onSurfaceVariant.withOpacity(0.3)
                : config.themeColors.primary.withOpacity(0.5),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                color: isNegative 
                  ? config.themeColors.onSurfaceVariant 
                  : config.themeColors.primary,
                size: config.dialogueTextStyle.fontSize! * textScale * 1.2,
              ),
              SizedBox(width: 8 * uiScale),
              Text(
                text,
                style: config.dialogueTextStyle.copyWith(
                  fontSize: config.dialogueTextStyle.fontSize! * textScale,
                  color: isNegative 
                    ? config.themeColors.onSurfaceVariant 
                    : config.themeColors.primary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}