import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import '../services/sfx.dart';

/// Plays a soft pop when a button (anything with a tap handler) is tapped.
/// Scrolling, dragging and taps on plain background stay silent.
class SfxTapListener extends StatefulWidget {
  const SfxTapListener({super.key, required this.child});

  final Widget child;

  @override
  State<SfxTapListener> createState() => _SfxTapListenerState();
}

class _SfxTapListenerState extends State<SfxTapListener> {
  int? _pointer;
  Offset _downAt = Offset.zero;
  Duration _downTime = Duration.zero;
  bool _onButton = false;

  bool _hitsButton(PointerDownEvent event) {
    final result = HitTestResult();
    WidgetsBinding.instance.hitTestInView(result, event.position, event.viewId);
    for (final entry in result.path) {
      final target = entry.target;
      // Anything the player can press: buttons and cards with a tap or
      // long-press handler, switches, and anything marked as tappable.
      if (target is RenderSemanticsGestureHandler &&
          (target.onTap != null || target.onLongPress != null)) {
        return true;
      }
      if (target is RenderSemanticsAnnotations &&
          target.properties.onTap != null) {
        return true;
      }
      if (target is RenderMouseRegion &&
          target.cursor == SystemMouseCursors.click) {
        return true;
      }
    }
    return false;
  }

  void _down(PointerDownEvent event) {
    if (_pointer != null) {
      // A second finger: not a simple tap.
      _onButton = false;
      return;
    }
    _pointer = event.pointer;
    _downAt = event.position;
    _downTime = event.timeStamp;
    _onButton = Sfx.soundEnabled && _hitsButton(event);
  }

  void _up(PointerUpEvent event) {
    if (event.pointer != _pointer) return;
    final wasTap = _onButton &&
        (event.position - _downAt).distance < 18 &&
        (event.timeStamp - _downTime) < const Duration(milliseconds: 500);
    _pointer = null;
    _onButton = false;
    if (wasTap) Sfx.tap();
  }

  void _cancel(PointerCancelEvent event) {
    if (event.pointer != _pointer) return;
    _pointer = null;
    _onButton = false;
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: _down,
      onPointerUp: _up,
      onPointerCancel: _cancel,
      child: widget.child,
    );
  }
}
