import 'dart:ui' show lerpDouble;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// Drives the session's open/minimize/restore/close motion entirely at the
/// render layer (doc §6.2). It interpolates the session between [collapsedRect]
/// (the pill slot) and [fullRect] (full screen) and applies a fade + slight
/// shrink as it closes — all in [RenderSessionTransform.paint], driven directly
/// by the controller's [expansion]/[closeProgress] animations.
///
/// The child is laid out once at full size and only its *paint* is updated per
/// frame, so the content subtree is never rebuilt or relaid out during an
/// animation — the whole point of this widget.
class SessionTransform extends SingleChildRenderObjectWidget {
  const SessionTransform({
    super.key,
    required this.expansion,
    required this.closeProgress,
    required this.collapsedRect,
    required this.fullRect,
    required this.collapsedRadius,
    required this.curve,
    required Widget super.child,
  });

  /// Expansion animation: `0` = collapsed (pill rect), `1` = expanded (full).
  final Animation<double> expansion;

  /// Close animation: `0` = present, `1` = closed (fade + shrink).
  final Animation<double> closeProgress;

  /// Screen rect of the pill slot (expansion == 0).
  final Rect collapsedRect;

  /// Screen rect of the full-screen session (expansion == 1).
  final Rect fullRect;

  /// Corner radius when fully collapsed; lerps to 0 when expanded.
  final double collapsedRadius;

  /// Curve applied to the raw expansion value for the rect interpolation.
  final Curve curve;

  @override
  RenderSessionTransform createRenderObject(BuildContext context) {
    return RenderSessionTransform(
      expansion: expansion,
      closeProgress: closeProgress,
      collapsedRect: collapsedRect,
      fullRect: fullRect,
      collapsedRadius: collapsedRadius,
      curve: curve,
    );
  }

  @override
  void updateRenderObject(
    BuildContext context,
    RenderSessionTransform renderObject,
  ) {
    renderObject
      ..expansion = expansion
      ..closeProgress = closeProgress
      ..collapsedRect = collapsedRect
      ..fullRect = fullRect
      ..collapsedRadius = collapsedRadius
      ..curve = curve;
  }
}

/// The render object behind [SessionTransform]. Lays its child out tight to
/// [fullRect] and paints it translated/scaled/clipped/faded per the current
/// animation values, repainting (never relaying out or rebuilding) each tick.
class RenderSessionTransform extends RenderProxyBox {
  RenderSessionTransform({
    required Animation<double> expansion,
    required Animation<double> closeProgress,
    required Rect collapsedRect,
    required Rect fullRect,
    required double collapsedRadius,
    required Curve curve,
  })  : _expansion = expansion,
        _closeProgress = closeProgress,
        _collapsedRect = collapsedRect,
        _fullRect = fullRect,
        _collapsedRadius = collapsedRadius,
        _curve = curve;

  Animation<double> _expansion;
  set expansion(Animation<double> value) {
    if (identical(value, _expansion)) return;
    if (attached) _expansion.removeListener(_onTick);
    _expansion = value;
    if (attached) _expansion.addListener(_onTick);
    markNeedsPaint();
  }

  Animation<double> _closeProgress;
  set closeProgress(Animation<double> value) {
    if (identical(value, _closeProgress)) return;
    if (attached) _closeProgress.removeListener(_onTick);
    _closeProgress = value;
    if (attached) _closeProgress.addListener(_onTick);
    markNeedsPaint();
  }

  Rect _collapsedRect;
  set collapsedRect(Rect value) {
    if (value == _collapsedRect) return;
    _collapsedRect = value;
    markNeedsPaint();
  }

  Rect _fullRect;
  set fullRect(Rect value) {
    if (value == _fullRect) return;
    _fullRect = value;
    markNeedsLayout();
  }

  double _collapsedRadius;
  set collapsedRadius(double value) {
    if (value == _collapsedRadius) return;
    _collapsedRadius = value;
    markNeedsPaint();
  }

  Curve _curve;
  set curve(Curve value) {
    if (value == _curve) return;
    _curve = value;
    markNeedsPaint();
  }

  void _onTick() => markNeedsPaint();

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _expansion.addListener(_onTick);
    _closeProgress.addListener(_onTick);
  }

  @override
  void detach() {
    _expansion.removeListener(_onTick);
    _closeProgress.removeListener(_onTick);
    super.detach();
  }

  // Lay the child out at full size always; the shrink to the pill happens only
  // in paint, so the content never relays out (preserving scroll/layout).
  @override
  void performLayout() {
    size = constraints.constrain(_fullRect.size);
    child?.layout(BoxConstraints.tight(size));
  }

  /// The translate×scale applied to the child for the current animation values.
  Matrix4 _currentTransform() {
    // Guard against a zero-size full rect (e.g. a transient empty layout),
    // which would otherwise divide by zero and produce a NaN transform.
    if (_fullRect.isEmpty) return Matrix4.identity();
    final t = _curve.transform(_expansion.value.clamp(0.0, 1.0));
    final rect = Rect.lerp(_collapsedRect, _fullRect, t)!;
    final closeScale = 1 - 0.06 * _closeProgress.value;
    final scaleX = rect.width / _fullRect.width * closeScale;
    final scaleY = rect.height / _fullRect.height * closeScale;
    return Matrix4.translationValues(
      rect.left - _fullRect.left,
      rect.top - _fullRect.top,
      0,
    )..multiply(Matrix4.diagonal3Values(scaleX, scaleY, 1));
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final child = this.child;
    if (child == null || size.isEmpty) return;

    final t = _curve.transform(_expansion.value.clamp(0.0, 1.0));
    final radius = lerpDouble(_collapsedRadius, 0, t)!;
    final opacity = (1 - _closeProgress.value).clamp(0.0, 1.0);
    if (opacity <= 0) return;

    // Paint the (built-once) child through: transform → optional rounded clip →
    // optional opacity. Layers are not cached across frames — recreating them
    // per paint keeps the conditional nesting correct (a cached child layer can
    // be disposed with a recreated parent and must not be reused).
    void paintContent(PaintingContext ctx, Offset o) {
      if (opacity < 1) {
        ctx.pushOpacity(
          o,
          (opacity * 255).round(),
          (c, innerOffset) => c.paintChild(child, innerOffset),
        );
      } else {
        ctx.paintChild(child, o);
      }
    }

    void paintClipped(PaintingContext ctx, Offset o) {
      if (radius > 0) {
        ctx.pushClipRRect(
          needsCompositing,
          o,
          o & size,
          RRect.fromRectAndRadius(o & size, Radius.circular(radius)),
          paintContent,
        );
      } else {
        paintContent(ctx, o);
      }
    }

    final transform = _currentTransform();
    if (transform.isIdentity()) {
      paintClipped(context, offset);
    } else {
      context.pushTransform(needsCompositing, offset, transform, paintClipped);
    }
  }

  @override
  void applyPaintTransform(RenderBox child, Matrix4 transform) {
    transform.multiply(_currentTransform());
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    if (child == null) return false;
    return result.addWithPaintTransform(
      transform: _currentTransform(),
      position: position,
      hitTest: (result, transformed) =>
          child!.hitTest(result, position: transformed),
    );
  }
}
