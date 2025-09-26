import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:sakiengine/src/config/asset_manager.dart';
import 'package:sakiengine/src/utils/character_layer_parser.dart';
import 'package:sakiengine/src/utils/expression_offset_manager.dart';
import 'package:sakiengine/src/utils/image_loader.dart';

class CharacterCompositeCache {
  CharacterCompositeCache._();
  static final CharacterCompositeCache instance = CharacterCompositeCache._();

  final Map<String, ui.Image> _imageCache = {};
  final Map<String, Future<ui.Image?>> _pendingTasks = {};

  String _buildKey(String resourceId, String pose, String expression) {
    return '$resourceId::$pose::$expression';
  }

  ui.Image? getCached(String resourceId, String pose, String expression) {
    return _imageCache[_buildKey(resourceId, pose, expression)];
  }

  Future<ui.Image?> preload(String resourceId, String pose, String expression) {
    final key = _buildKey(resourceId, pose, expression);
    final cached = _imageCache[key];
    if (cached != null) {
      return SynchronousFuture(cached);
    }

    final pending = _pendingTasks[key];
    if (pending != null) {
      return pending;
    }

    final task = _compose(resourceId, pose, expression).then((image) {
      if (image != null) {
        _imageCache[key] = image;
      }
      _pendingTasks.remove(key);
      return image;
    });

    _pendingTasks[key] = task;
    return task;
  }

  Future<ui.Image?> _compose(String resourceId, String pose, String expression) async {
    try {
      final layerInfos = await CharacterLayerParser.parseCharacterLayers(
        resourceId: resourceId,
        pose: pose,
        expression: expression,
      );

      if (layerInfos.isEmpty) {
        return null;
      }

      final images = <_CompositeLayer>[];
      ui.Image? baseImage;

      for (final info in layerInfos) {
        final assetPath = await AssetManager().findAsset(info.assetName);
        if (assetPath == null) {
          continue;
        }
        final image = await ImageLoader.loadImage(assetPath);
        if (image == null) {
          continue;
        }

        final (xOffset, yOffset, alpha, scale) =
            ExpressionOffsetManager().getExpressionOffset(
          characterId: resourceId,
          pose: pose,
          layerType: info.layerType,
        );

        images.add(_CompositeLayer(
          image: image,
          xOffset: xOffset,
          yOffset: yOffset,
          alpha: alpha,
          scale: scale,
        ));

        baseImage ??= image;
      }

      final base = baseImage;
      if (base == null) {
        return null;
      }

      final recorder = ui.PictureRecorder();
      final canvas = ui.Canvas(recorder);
      final paint = ui.Paint()
        ..isAntiAlias = true
        ..filterQuality = ui.FilterQuality.high;

      final width = base.width.toDouble();
      final height = base.height.toDouble();

      for (final layer in images) {
        canvas.save();
        final dx = layer.xOffset * width;
        final dy = layer.yOffset * height;
        canvas.translate(dx, dy);
        if (layer.scale != 1.0) {
          canvas.scale(layer.scale, layer.scale);
        }
        paint.color = ui.Color.fromRGBO(
          255,
          255,
          255,
          layer.alpha.clamp(0.0, 1.0),
        );
        canvas.drawImage(layer.image, ui.Offset.zero, paint);
        canvas.restore();
        layer.image.dispose();
      }

      final picture = recorder.endRecording();
      final composed = await picture.toImage(base.width, base.height);
      picture.dispose();
      return composed;
    } catch (_) {
      return null;
    }
  }

  void clear() {
    for (final image in _imageCache.values) {
      image.dispose();
    }
    _imageCache.clear();
    _pendingTasks.clear();
  }

  void invalidate(String resourceId, String pose) {
    final prefix = '$resourceId::$pose::';
    final keysToRemove = _imageCache.keys
        .where((key) => key.startsWith(prefix))
        .toList(growable: false);
    for (final key in keysToRemove) {
      _imageCache.remove(key)?.dispose();
      _pendingTasks.remove(key);
    }
  }
}

class _CompositeLayer {
  _CompositeLayer({
    required this.image,
    required this.xOffset,
    required this.yOffset,
    required this.alpha,
    required this.scale,
  });

  final ui.Image image;
  final double xOffset;
  final double yOffset;
  final double alpha;
  final double scale;
}
