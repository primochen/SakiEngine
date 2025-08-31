import 'package:flutter/material.dart';

class SceneLayer {
  final String assetName;
  final LayerPosition? position;
  
  SceneLayer({
    required this.assetName,
    this.position,
  });
  
  static SceneLayer? fromString(String layerString) {
    if (layerString.contains(':')) {
      final parts = layerString.split(':');
      final assetName = parts[0];
      final positionString = parts[1];
      
      final position = LayerPosition.fromString(positionString);
      return SceneLayer(assetName: assetName, position: position);
    } else {
      return SceneLayer(assetName: layerString);
    }
  }
}

class LayerPosition {
  final double? left;
  final double? right;
  final double? top;
  final double? bottom;
  final double? width;
  final double? height;
  final double zoom; // 缩放参数，默认1.0
  
  LayerPosition({
    this.left,
    this.right,
    this.top,
    this.bottom,
    this.width,
    this.height,
    this.zoom = 1.0, // 默认不缩放
  });
  
  static LayerPosition? fromString(String positionString) {
    double? left, right, top, bottom, width, height;
    double zoom = 1.0; // 默认缩放
    
    final params = positionString.split(' ');
    for (final param in params) {
      if (param.startsWith('left=')) {
        left = double.tryParse(param.substring(5));
      } else if (param.startsWith('right=')) {
        right = double.tryParse(param.substring(6));
      } else if (param.startsWith('top=')) {
        top = double.tryParse(param.substring(4));
      } else if (param.startsWith('bottom=')) {
        bottom = double.tryParse(param.substring(7));
      } else if (param.startsWith('width=')) {
        width = double.tryParse(param.substring(6));
      } else if (param.startsWith('height=')) {
        height = double.tryParse(param.substring(7));
      } else if (param.startsWith('zoom=')) {
        zoom = double.tryParse(param.substring(5)) ?? 1.0;
      }
    }
    
    return LayerPosition(
      left: left,
      right: right, 
      top: top,
      bottom: bottom,
      width: width,
      height: height,
      zoom: zoom,
    );
  }
}

class MultiLayerRenderer {
  static Widget buildMultiLayerScene({
    required List<SceneLayer> layers,
    required Size screenSize,
  }) {
    return Stack(
      children: layers.map((layer) => _buildLayer(layer, screenSize)).toList(),
    );
  }

  static Widget _buildLayer(SceneLayer layer, Size screenSize) {
    // The base widget is the Image, configured to fill its parent container.
    Widget imageContent = Image.asset(
      'assets/Assets/images/backgrounds/${layer.assetName.replaceAll(' ', '-')}.png',
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) {
        return Image.asset(
          'assets/Assets/gui/${layer.assetName}.png',
          errorBuilder: (context, error2, stackTrace2) {
            return Container(
              color: Colors.transparent,
              child: Center(
                child: Text(
                  'Missing: ${layer.assetName}',
                  style: const TextStyle(color: Colors.red),
                ),
              ),
            );
          },
        );
      },
    );

    final pos = layer.position;

    // Apply the zoom transformation directly to the image content.
    if (pos != null && pos.zoom != 1.0) {
      imageContent = Transform.scale(
        scale: pos.zoom,
        alignment: _determineScaleAlignment(pos),
        child: imageContent,
      );
    }

    // For a layer with no position info, fill the screen.
    if (pos == null) {
      return Positioned.fill(child: imageContent);
    }

    Widget finalChild = imageContent;

    // CRITICAL FIX: If no explicit size is defined in the script (width/height are null),
    // the image would use its static, intrinsic size, which is not responsive.
    // To fix this, we provide a default responsive container that scales with the screen height,
    // mirroring the behavior of character sprites.
    if (pos.width == null && pos.height == null) {
      finalChild = SizedBox(
        height: screenSize.height,
        child: finalChild,
      );
    }

    // Position the final widget. If width/height are specified in the script,
    // they will create a responsive container that overrides the default SizedBox.
    return Positioned(
      left: pos.left != null ? screenSize.width * pos.left! : null,
      right: pos.right != null ? screenSize.width * pos.right! : null,
      top: pos.top != null ? screenSize.height * pos.top! : null,
      bottom: pos.bottom != null ? screenSize.height * pos.bottom! : null,
      width: pos.width != null ? screenSize.width * pos.width! : null,
      height: pos.height != null ? screenSize.height * pos.height! : null,
      child: finalChild,
    );
  }

  static Alignment _determineScaleAlignment(LayerPosition? pos) {
    if (pos == null) return Alignment.center;
    
    final double y = (pos.top != null) ? -1.0 : (pos.bottom != null) ? 1.0 : 0.0;
    final double x = (pos.left != null) ? -1.0 : (pos.right != null) ? 1.0 : 0.0;
    
    return Alignment(x, y);
  }
}