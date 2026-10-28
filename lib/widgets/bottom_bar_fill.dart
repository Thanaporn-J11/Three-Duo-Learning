import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// Lifts [child] above the system navigation bar (the three-button bar) and
/// paints the strip under it in the same colour as the bottom edge of the
/// screen, so every page looks as if it simply reaches the bottom.
///
/// The colour is read a few times a second from the picture of the app
/// itself, so it follows whatever page or sheet is showing.
class BottomBarFill extends StatefulWidget {
  const BottomBarFill({super.key, required this.bar, required this.child});

  /// Height of the system bar in logical pixels.
  final double bar;
  final Widget child;

  @override
  State<BottomBarFill> createState() => _BottomBarFillState();
}

class _BottomBarFillState extends State<BottomBarFill> {
  final GlobalKey _key = GlobalKey();
  Timer? _timer;
  bool _busy = false;
  Color _color = const Color(0xFFFFFFFF);

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(milliseconds: 250), (_) => _sample());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _sample() async {
    if (_busy || !mounted) return;
    _busy = true;
    try {
      final object = _key.currentContext?.findRenderObject();
      if (object is! RenderRepaintBoundary) return;
      final image = await object.toImage(pixelRatio: 0.15);
      final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      final w = image.width;
      final h = image.height;
      image.dispose();
      if (data == null || w < 5 || h < 5) return;

      // A few points along the bottom edge; the most common colour wins.
      final counts = <int, int>{};
      final row = h - 3;
      for (final f in const [0.08, 0.25, 0.5, 0.75, 0.92]) {
        final i = (row * w + (w * f).floor()) * 4;
        final a = data.getUint8(i + 3);
        if (a < 200) continue;
        final argb = (0xFF << 24) |
            (data.getUint8(i) << 16) |
            (data.getUint8(i + 1) << 8) |
            data.getUint8(i + 2);
        counts[argb] = (counts[argb] ?? 0) + 1;
      }
      if (counts.isEmpty) return;
      var best = counts.keys.first;
      for (final e in counts.entries) {
        if (e.value > counts[best]!) best = e.key;
      }
      if (mounted && best != _color.toARGB32()) {
        setState(() => _color = Color(best));
      }
    } catch (_) {
      // Keep the last colour.
    } finally {
      _busy = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          height: widget.bar,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            color: _color,
          ),
        ),
        Positioned.fill(
          bottom: widget.bar,
          child: RepaintBoundary(key: _key, child: widget.child),
        ),
      ],
    );
  }
}
