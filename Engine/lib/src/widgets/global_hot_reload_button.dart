import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class GlobalHotReloadButton extends StatelessWidget {
  final VoidCallback onReload;

  const GlobalHotReloadButton({
    super.key,
    required this.onReload,
  });

  @override
  Widget build(BuildContext context) {
    if (!kDebugMode) return const SizedBox.shrink();
    
    final mediaQuery = MediaQuery.of(context);
    final size = mediaQuery.size;
    final scaleFactor = size.width / 1920;

    return Positioned(
      left: 16 * scaleFactor,
      bottom: 16 * scaleFactor,
      child: ClipOval(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            width: 56 * scaleFactor,
            height: 56 * scaleFactor,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white,
                width: 1 * scaleFactor,
              ),
            ),
            child: IconButton(
              icon: Icon(
                Icons.refresh,
                color: Colors.white,
                size: 24 * scaleFactor,
              ),
              onPressed: onReload,
            ),
          ),
        ),
      ),
    );
  }
}