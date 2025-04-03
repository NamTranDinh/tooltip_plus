import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

enum TooltipAlignment {
  topLeftOfParent,
  topCenterOfParent,
  topRightOfParent,
  rightTopOfParent,
  rightBottomOfParent,
  rightCenterOfParent,
  leftTopOfParent,
  centerLeftOfParent,
  leftBottomOfParent,
  bottomLeftOfParent,
  bottomCenterOfParent,
  bottomRightOfParent,
}

/// A function that builds the offset of the tooltip.
///
/// [currentOffset] is the current offset of the tooltip.
/// [parentSize] is the size of the parent widget.
/// [tooltipSize] is the size of the tooltip widget.
typedef BuildTooltipOffset = Offset Function(Offset currentOffset, Size parentSize, Size tooltipSize);

/// A callback that is called when the tooltip is triggered.
typedef TooltipTriggeredCallback = void Function();

/// Represents an offset from each edge of a rectangle.
class EdgeOffset {
  EdgeOffset({this.top, this.left, this.right, this.bottom});

  /// The distance from the top edge.
  /// The distance from the left edge.
  /// The distance from the right edge.
  double? top;
  double? left;
  double? right;
  double? bottom;
}

class _ExclusiveMouseRegion extends MouseRegion {
  const _ExclusiveMouseRegion({
    super.onEnter,
    super.onExit,
    super.child,
  });

  @override
  _RenderExclusiveMouseRegion createRenderObject(BuildContext context) {
    return _RenderExclusiveMouseRegion(
      onEnter: onEnter,
      onExit: onExit,
    );
  }
}

class _RenderExclusiveMouseRegion extends RenderMouseRegion {
  _RenderExclusiveMouseRegion({
    super.onEnter,
    super.onExit,
  });

  static bool isOutermostMouseRegion = true;
  static bool foundInnermostMouseRegion = false;

  @override
  bool hitTest(BoxHitTestResult result, {required Offset position}) {
    var isHit = false;
    final outermost = isOutermostMouseRegion;
    isOutermostMouseRegion = false;
    if (size.contains(position)) {
      isHit = hitTestChildren(result, position: position) || hitTestSelf(position);
      if ((isHit || behavior == HitTestBehavior.translucent) && !foundInnermostMouseRegion) {
        foundInnermostMouseRegion = true;
        result.add(BoxHitTestEntry(this, position));
      }
    }

    if (outermost) {
      isOutermostMouseRegion = true;
      foundInnermostMouseRegion = false;
    }
    return isHit;
  }
}

class TooltipPlus extends StatefulWidget {
  const TooltipPlus({
    super.key,
    required this.messageWidget,
    this.height,
    this.waitDuration,
    this.showDuration,
    this.exitDuration,
    this.triggerMode,
    this.enableFeedback,
    this.onTriggered,
    required this.child,
    this.alignment = TooltipAlignment.rightTopOfParent,
    this.buildTooltipOffset,
  });

  /// The alignment of the tooltip relative to its parent.
  final TooltipAlignment? alignment;

  /// A function that builds the offset of the tooltip.
  ///
  /// If this is null, the default offset will be used.
  final BuildTooltipOffset? buildTooltipOffset;

  /// The widget that will be displayed as the tooltip message.
  final Widget messageWidget;

  /// The widget that will trigger the tooltip.
  final Widget child;

  /// The height of the tooltip.
  final double? height;

  /// The duration to wait before showing the tooltip.
  final Duration? waitDuration;

  /// The duration to show the tooltip.
  final Duration? showDuration;

  /// The duration to wait before hiding the tooltip when the mouse exits.
  final Duration? exitDuration;

  /// The mode that will trigger the tooltip.
  final TooltipTriggerMode? triggerMode;

  /// Whether to enable feedback when the tooltip is triggered.
  final bool? enableFeedback;

  /// A callback that is called when the tooltip is triggered.
  final TooltipTriggeredCallback? onTriggered;

  /// A list of all currently opened tooltips.
  static final List<TooltipPlusState> _openedTooltips = <TooltipPlusState>[];

  /// Dismisses all currently opened tooltips.
  ///
  /// Returns `true` if any tooltips were dismissed, `false` otherwise.
  static bool dismissAllToolTips() {
    if (_openedTooltips.isNotEmpty) {
      final openedTooltips = _openedTooltips.toList();
      for (final state in openedTooltips) {
        state._scheduleDismissTooltip(withDelay: Duration.zero);
      }
      return true;
    }
    return false;
  }

  @override
  State<TooltipPlus> createState() => TooltipPlusState();
}

class TooltipPlusState extends State<TooltipPlus> with SingleTickerProviderStateMixin {
  static const _fadeInDuration = Duration(milliseconds: 250);
  static const _fadeOutDuration = Duration(milliseconds: 175);
  static const _defaultShowDuration = Duration(milliseconds: 1000);
  static const _defaultHoverExitDuration = Duration(milliseconds: 200);
  static const _defaultWaitDuration = Duration.zero;
  static const _defaultTriggerMode = TooltipTriggerMode.longPress;
  static const _defaultEnableFeedback = true;
  final _overlayController = OverlayPortalController();

  late bool _visible;

  Duration get _showDuration => widget.showDuration ?? _defaultShowDuration;

  Duration get _hoverExitDuration => widget.exitDuration ?? _defaultHoverExitDuration;

  Duration get _waitDuration => widget.waitDuration ?? _defaultWaitDuration;

  TooltipTriggerMode get _triggerMode => widget.triggerMode ?? _defaultTriggerMode;

  bool get _enableFeedback => widget.enableFeedback ?? _defaultEnableFeedback;

  Timer? _timer;
  AnimationController? _backingController;

  AnimationController get _controller {
    return _backingController ??= AnimationController(
      duration: _fadeInDuration,
      reverseDuration: _fadeOutDuration,
      vsync: this,
    )..addStatusListener(_handleStatusChanged);
  }

  LongPressGestureRecognizer? _longPressRecognizer;
  TapGestureRecognizer? _tapRecognizer;

  final Set<int> _activeHoveringPointerDevices = <int>{};

  static bool _isTooltipVisible(AnimationStatus status) {
    return switch (status) {
      AnimationStatus.completed || AnimationStatus.forward || AnimationStatus.reverse => true,
      AnimationStatus.dismissed => false,
    };
  }

  AnimationStatus _animationStatus = AnimationStatus.dismissed;

  void _handleStatusChanged(AnimationStatus status) {
    switch ((_isTooltipVisible(_animationStatus), _isTooltipVisible(status))) {
      case (true, false):
        TooltipPlus._openedTooltips.remove(this);
        _overlayController.hide();
      case (false, true):
        _overlayController.show();
        TooltipPlus._openedTooltips.add(this);
      case (true, true) || (false, false):
        break;
    }
    _animationStatus = status;
  }

  void _scheduleShowTooltip({required Duration withDelay, Duration? showDuration}) {
    void show() {
      if (!_visible) return;
      _controller.forward();
      _timer?.cancel();
      _timer = showDuration == null ? null : Timer(showDuration, _controller.reverse);
    }

    assert(
      !(_timer?.isActive ?? false) || _controller.status != AnimationStatus.reverse,
      'timer must not be active when the tooltip is fading out',
    );

    switch (_controller.status) {
      case AnimationStatus.dismissed when withDelay.inMicroseconds > 0:
        _timer?.cancel();
        _timer = Timer(withDelay, show);

      case AnimationStatus.dismissed:
      case AnimationStatus.forward:
      case AnimationStatus.reverse:
      case AnimationStatus.completed:
        show();
    }
  }

  void _scheduleDismissTooltip({required Duration withDelay}) {
    assert(
      !(_timer?.isActive ?? false) || _backingController?.status != AnimationStatus.reverse,
      'timer must not be active when the tooltip is fading out',
    );

    _timer?.cancel();
    _timer = null;

    switch (_backingController?.status) {
      case null:
      case AnimationStatus.reverse:
      case AnimationStatus.dismissed:
        break;

      case AnimationStatus.forward:
      case AnimationStatus.completed:
        if (withDelay.inMicroseconds > 0) {
          _timer = Timer(withDelay, _controller.reverse);
        } else {
          _controller.reverse();
        }
    }
  }

  void _handlePointerDown(PointerDownEvent event) {
    const triggerModeDeviceKinds = <PointerDeviceKind>{
      PointerDeviceKind.invertedStylus,
      PointerDeviceKind.stylus,
      PointerDeviceKind.touch,
      PointerDeviceKind.unknown,
      PointerDeviceKind.trackpad,
    };
    switch (_triggerMode) {
      case TooltipTriggerMode.longPress:
        final recognizer = _longPressRecognizer ??= LongPressGestureRecognizer(
          debugOwner: this,
          supportedDevices: triggerModeDeviceKinds,
        );
        recognizer
          ..onLongPress = _handleLongPress
          ..onLongPressUp = _handlePressUp
          ..addPointer(event);
      case TooltipTriggerMode.tap:
        final recognizer = _tapRecognizer ??= TapGestureRecognizer(
          debugOwner: this,
          supportedDevices: triggerModeDeviceKinds,
        );
        recognizer
          ..onTap = _handleTap
          ..addPointer(event);
      case TooltipTriggerMode.manual:
        break;
    }
  }

  void _handleGlobalPointerEvent(PointerEvent event) {
    /// Dismisses the tooltip if:
    /// 1. The event pointer is not the same as the one that triggered the tap or long press.
    ///    This prevents the tooltip from being dismissed when the user is still interacting
    ///    with the widget.
    /// 2. The timer is null, and the controller is dismissed.
    ///    This prevents the tooltip from being dismissed when it is already dismissed.
    /// 3. The event is not a pointer down event.
    ///    This prevents the tooltip from being dismissed when the user is moving the mouse.
    ///    or the pointer is up.
    if (_tapRecognizer?.primaryPointer == event.pointer || _longPressRecognizer?.primaryPointer == event.pointer) {
      return;
    }
    if ((_timer == null && _controller.status == AnimationStatus.dismissed) || event is! PointerDownEvent) {
      return;
    }
  }

  /// Handles a tap event on the tooltip trigger.
  ///
  /// This method is called when the user taps on the tooltip trigger. It
  /// displays the tooltip and provides haptic feedback if enabled.
  void _handleTap() {
    if (!_visible) return;

    final tooltipCreated = _controller.status == AnimationStatus.dismissed;
    if (tooltipCreated && _enableFeedback) {
      assert(_triggerMode == TooltipTriggerMode.tap, '');
      Feedback.forTap(context);
    }
    widget.onTriggered?.call();
    _scheduleShowTooltip(
      withDelay: Duration.zero,
      showDuration: _activeHoveringPointerDevices.isEmpty ? _showDuration : null,
    );
  }

  /// Handles a long press event on the tooltip trigger.
  ///
  /// This method is called when the user long presses on the tooltip trigger.
  /// It displays the tooltip, provides haptic feedback if enabled, and
  /// dismisses the tooltip after a certain duration.
  void _handleLongPress() {
    if (!_visible) return;

    final tooltipCreated = _visible && _controller.status == AnimationStatus.dismissed;
    if (tooltipCreated && _enableFeedback) {
      assert(_triggerMode == TooltipTriggerMode.longPress, '');
      Feedback.forLongPress(context);
    }
    widget.onTriggered?.call();
    _scheduleShowTooltip(withDelay: Duration.zero);
  }

  /// Handles the press up event on the tooltip trigger.
  ///
  /// This method is called when the user releases a long press on the tooltip
  /// trigger. It dismisses the tooltip after a certain duration.
  void _handlePressUp() {
    if (_activeHoveringPointerDevices.isNotEmpty) return;
    _scheduleDismissTooltip(withDelay: _showDuration);
  }

  /// Handles the mouse enter event on the tooltip trigger.
  ///
  /// This method is called when the mouse enters the tooltip trigger area. It
  /// adds the device to the list of active hovering devices and shows the
  /// tooltip.
  void _handleMouseEnter(PointerEnterEvent event) {
    _activeHoveringPointerDevices.add(event.device);

    final tooltipsToDismiss = TooltipPlus._openedTooltips
        .where((TooltipPlusState tooltip) => tooltip._activeHoveringPointerDevices.isEmpty)
        .toList();
    for (final tooltip in tooltipsToDismiss) {
      tooltip._scheduleDismissTooltip(withDelay: Duration.zero);
    }
    _scheduleShowTooltip(withDelay: tooltipsToDismiss.isNotEmpty ? Duration.zero : _waitDuration);
  }

  /// Handles the mouse exit event on the tooltip trigger.
  ///
  /// This method is called when the mouse exits the tooltip trigger area. It
  /// removes the device from the list of active hovering devices and dismisses
  /// the tooltip if no other devices are hovering.
  void _handleMouseExit(PointerExitEvent event) {
    if (_activeHoveringPointerDevices.isEmpty) return;

    _activeHoveringPointerDevices.remove(event.device);
    if (_activeHoveringPointerDevices.isEmpty) {
      _scheduleDismissTooltip(withDelay: _hoverExitDuration);
    }
  }

  bool ensureTooltipVisible() {
    if (!_visible) return false;
    _timer?.cancel();
    _timer = null;
    switch (_controller.status) {
      case AnimationStatus.dismissed:
      case AnimationStatus.reverse:
        _scheduleShowTooltip(withDelay: Duration.zero);
        return true;
      case AnimationStatus.forward:
      case AnimationStatus.completed:
        return false;
    }
  }

  @override
  void initState() {
    super.initState();
    GestureBinding.instance.pointerRouter.addGlobalRoute(_handleGlobalPointerEvent);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _visible = TooltipVisibility.of(context);
  }

  Widget _buildTooltipOverlay(BuildContext context) {
    final overlayState = Overlay.of(context);
    final box = this.context.findRenderObject()! as RenderBox;
    final target = box.localToGlobal(
      box.size.center(Offset.zero),
      ancestor: overlayState.context.findRenderObject(),
    );

    final overlayChild = _TooltipOverlay(
      target: target,
      box: box,
      alignment: widget.alignment!,
      onEnter: _handleMouseEnter,
      onExit: _handleMouseExit,
      animation: CurvedAnimation(parent: _controller, curve: Curves.fastOutSlowIn),
      buildTooltipOffset: widget.buildTooltipOffset,
      child: SizedBox(
        key: GlobalKey(debugLabel: widget.messageWidget.hashCode.toString()),
        child: widget.messageWidget,
      ),
    );

    return SelectionContainer.maybeOf(context) == null
        ? overlayChild
        : SelectionContainer.disabled(child: overlayChild);
  }

  @override
  void dispose() {
    GestureBinding.instance.pointerRouter.removeGlobalRoute(_handleGlobalPointerEvent);
    TooltipPlus._openedTooltips.remove(this);
    _longPressRecognizer?.onLongPressCancel = null;
    _longPressRecognizer?.dispose();
    _tapRecognizer?.onTapCancel = null;
    _tapRecognizer?.dispose();
    _timer?.cancel();
    _backingController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    var result = widget.child;

    if (_visible) {
      result = _ExclusiveMouseRegion(
        onEnter: _handleMouseEnter,
        onExit: _handleMouseExit,
        child: Listener(
          onPointerDown: _handlePointerDown,
          behavior: HitTestBehavior.opaque,
          child: result,
        ),
      );
    }
    return OverlayPortal(
      controller: _overlayController,
      overlayChildBuilder: _buildTooltipOverlay,
      child: result,
    );
  }
}

/// A widget that displays a tooltip.
///
/// This widget is used internally by [TooltipPlus] to display the tooltip.
/// It handles the positioning, animation, and mouse events of the tooltip.
///
/// The [child] is the widget that will be displayed as the tooltip message.
///
/// The [box] is the [RenderBox] of the parent widget.
///
/// The [animation] is the animation that controls the tooltip's visibility.
///
/// The [target] is the position of the parent widget.
///
/// The [alignment] is the alignment of the tooltip relative to its parent.
///
/// The [onEnter] and [onExit] are the callbacks that are called when the mouse
/// enters or exits the tooltip.
///
/// The [buildTooltipOffset] is a function that builds the offset of the tooltip.
class _TooltipOverlay extends StatefulWidget {
  const _TooltipOverlay({
    required this.child,
    required this.box,
    required this.animation,
    required this.target,
    required this.alignment,
    this.onEnter,
    this.onExit,
    this.buildTooltipOffset,
  });

  final Widget child;
  final RenderBox box;
  final Offset target;
  final Animation<double> animation;
  final PointerExitEventListener? onExit;
  final PointerEnterEventListener? onEnter;
  final TooltipAlignment alignment;
  final BuildTooltipOffset? buildTooltipOffset;

  @override
  State<_TooltipOverlay> createState() => _TooltipOverlayState();
}

class _TooltipOverlayState extends State<_TooltipOverlay> {
  Size childSize = Size.infinite;
  Offset offset = const Offset(-1000, -1000);
  bool visible = false;

  @override
  void initState() {
    WidgetsBinding.instance.addPostFrameCallback(
      (timeStamp) => setState(() {
        childSize = getSize(widget.child.key! as GlobalKey);
        offset = widget.target;
        if (widget.buildTooltipOffset != null) {
          offset = widget.buildTooltipOffset?.call(offset, widget.box.size, childSize) ?? offset;
        } else {
          switch (widget.alignment) {
            case TooltipAlignment.topLeftOfParent:
              offset = topLeftOfParent(offset, widget.box);
            case TooltipAlignment.topCenterOfParent:
              offset = topCenterOfParent(offset, widget.box);
            case TooltipAlignment.topRightOfParent:
              offset = topRightOfParent(offset, widget.box);
            case TooltipAlignment.rightTopOfParent:
              offset = rightTopOfParent(offset, widget.box);
            case TooltipAlignment.rightBottomOfParent:
              offset = rightBottomOfParent(offset, widget.box);
            case TooltipAlignment.rightCenterOfParent:
              offset = rightCenterOfParent(offset, widget.box);
            case TooltipAlignment.leftTopOfParent:
              offset = leftTopOfParent(offset, widget.box);
            case TooltipAlignment.centerLeftOfParent:
              offset = centerLeftOfParent(offset, widget.box);
            case TooltipAlignment.leftBottomOfParent:
              offset = leftBottomOfParent(offset, widget.box);
            case TooltipAlignment.bottomLeftOfParent:
              offset = bottomLeftOfParent(offset, widget.box);
            case TooltipAlignment.bottomCenterOfParent:
              offset = bottomCenterOfParent(offset, widget.box);
            case TooltipAlignment.bottomRightOfParent:
              offset = bottomRightOfParent(offset, widget.box);
          }
        }
        visible = true;
      }),
    );
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    Widget result = FadeTransition(opacity: widget.animation, child: widget.child);
    if (widget.onEnter != null || widget.onExit != null) {
      result = _ExclusiveMouseRegion(onEnter: widget.onEnter, onExit: widget.onExit, child: result);
    }

    return Positioned.fill(
      child: Transform.translate(
        offset: offset,
        child: Container(
          width: childSize.width,
          height: childSize.height,
          alignment: Alignment.topLeft,
          child: result,
        ),
      ),
    );
  }

  /// Calculates the offset for the tooltip when it is aligned to the top left of its parent.
  ///
  /// [target] The target offset relative to the overlay.
  /// [box] The [RenderBox] of the parent widget.
  /// Returns the calculated [Offset].
  Offset topLeftOfParent(Offset target, RenderBox box) {
    return Offset(target.dx - box.size.width / 2, target.dy - box.size.width / 2 - childSize.height);
  }

  /// Calculates the offset for the tooltip when it is aligned to the top center of its parent.
  ///
  /// [target] The target offset relative to the overlay.
  /// [box] The [RenderBox] of the parent widget.
  /// Returns the calculated [Offset].
  Offset topCenterOfParent(Offset target, RenderBox box) {
    return Offset(target.dx - childSize.width / 2, target.dy - box.size.width / 2 - childSize.height);
  }

  /// Calculates the offset for the tooltip when it is aligned to the top right of its parent.
  ///
  /// [target] The target offset relative to the overlay.
  /// [box] The [RenderBox] of the parent widget.
  /// Returns the calculated [Offset].
  Offset topRightOfParent(Offset target, RenderBox box) {
    return Offset(target.dx + box.size.width / 2, target.dy - box.size.width / 2 - childSize.height);
  }

  /// Calculates the offset for the tooltip when it is aligned to the top right of its parent.
  ///
  /// [target] The target offset relative to the overlay.
  /// [box] The [RenderBox] of the parent widget.
  /// Returns the calculated [Offset].
  Offset rightTopOfParent(Offset target, RenderBox box) {
    return Offset(target.dx + box.size.width / 2, target.dy - (box.size.height / 2));
  }

  /// Calculates the offset for the tooltip when it is aligned to the bottom right of its parent.
  ///
  /// [target] The target offset relative to the overlay.
  /// [box] The [RenderBox] of the parent widget.
  /// Returns the calculated [Offset].
  Offset rightBottomOfParent(Offset target, RenderBox box) {
    return Offset(target.dx + box.size.width / 2, target.dy + (box.size.height / 2));
  }

  /// Calculates the offset for the tooltip when it is aligned to the center right of its parent.
  ///
  /// [target] The target offset relative to the overlay.
  /// [box] The [RenderBox] of the parent widget.
  /// Returns the calculated [Offset].
  Offset rightCenterOfParent(Offset target, RenderBox box) {
    return Offset(target.dx + box.size.width / 2, target.dy);
  }

  /// Calculates the offset for the tooltip when it is aligned to the top left of its parent.
  ///
  /// [target] The target offset relative to the overlay.
  /// [box] The [RenderBox] of the parent widget.
  /// Returns the calculated [Offset].
  Offset leftTopOfParent(Offset target, RenderBox box) {
    return Offset(target.dx - (box.size.width / 2) - childSize.width, target.dy - (box.size.height / 2));
  }

  /// Calculates the offset for the tooltip when it is aligned to the center left of its parent.
  ///
  /// [target] The target offset relative to the overlay.
  /// [box] The [RenderBox] of the parent widget.
  /// Returns the calculated [Offset].
  Offset centerLeftOfParent(Offset target, RenderBox box) {
    return Offset(target.dx - (box.size.width / 2) - childSize.width, target.dy);
  }

  /// Calculates the offset for the tooltip when it is aligned to the bottom left of its parent.
  ///
  /// [target] The target offset relative to the overlay.
  /// [box] The [RenderBox] of the parent widget.
  /// Returns the calculated [Offset].
  Offset leftBottomOfParent(Offset target, RenderBox box) {
    return Offset(target.dx - (box.size.width / 2) - childSize.width, target.dy + box.size.height / 2);
  }

  /// Calculates the offset for the tooltip when it is aligned to the bottom left of its parent.
  ///
  /// [target] The target offset relative to the overlay.
  /// [box] The [RenderBox] of the parent widget.
  /// Returns the calculated [Offset].
  Offset bottomLeftOfParent(Offset target, RenderBox box) {
    return Offset(target.dx - box.size.width / 2, target.dy + box.size.width / 2);
  }

  Offset bottomCenterOfParent(Offset target, RenderBox box) {
    return Offset(target.dx, target.dy + box.size.width / 2);
  }

  /// Calculates the offset for the tooltip when it is aligned to the bottom right of its parent.
  ///
  /// [target] The target offset relative to the overlay.
  /// [box] The [RenderBox] of the parent widget.
  /// Returns the calculated [Offset].
  Offset bottomRightOfParent(Offset target, RenderBox box) {
    return Offset(target.dx + box.size.width / 2, target.dy + (box.size.height / 2));
  }

  Size getSize(GlobalKey key) {
    final renderBox = key.currentContext?.findRenderObject() as RenderBox?;

    if (renderBox != null) {
      final size = renderBox.size;
      debugPrint('Size of message widget: ${size.width} x ${size.height}');
      return size;
    } else {
      debugPrint('Widget is not rendered yet.');
      return Size.infinite;
    }
  }
}
