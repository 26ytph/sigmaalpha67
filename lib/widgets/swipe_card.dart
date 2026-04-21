import 'dart:math' as math;

import 'package:flutter/cupertino.dart';

enum SwipeDirection { left, right }

class SwipeCard extends StatefulWidget {
  const SwipeCard({
    super.key,
    required this.child,
    required this.onSwipe,
    this.disabled = false,
  });

  final Widget child;
  final void Function(SwipeDirection dir) onSwipe;
  final bool disabled;

  @override
  State<SwipeCard> createState() => _SwipeCardState();
}

class _SwipeCardState extends State<SwipeCard> {
  Offset _delta = Offset.zero;
  SwipeDirection? _animating;

  double get _rotateDeg => (_delta.dx.clamp(-220.0, 220.0) / 220.0) * 10.0;

  double get _likeOpacity => (_delta.dx / 140).clamp(0.0, 1.0);

  double get _nopeOpacity => (-_delta.dx / 140).clamp(0.0, 1.0);

  void _commit(SwipeDirection dir) {
    if (widget.disabled) return;
    if (_animating != null) return;
    setState(() => _animating = dir);
    final targetX = dir == SwipeDirection.right ? 520.0 : -520.0;
    setState(() => _delta = Offset(targetX, _delta.dy));
    Future<void>.delayed(const Duration(milliseconds: 210), () {
      if (!mounted) return;
      widget.onSwipe(dir);
      setState(() {
        _delta = Offset.zero;
        _animating = null;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned(
          left: 24,
          top: 24,
          child: IgnorePointer(
            child: Row(
              children: [
                Opacity(
                  opacity: _likeOpacity,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE8F8EE),
                      border: Border.all(color: const Color(0xFF86EFAC)),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Text(
                      '有興趣',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF166534),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Opacity(
                  opacity: _nopeOpacity,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF1F2),
                      border: Border.all(color: const Color(0xFFFCA5A5)),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Text(
                      '沒興趣',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF9F1239),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onPanStart: widget.disabled || _animating != null ? null : (_) {},
          onPanUpdate: widget.disabled || _animating != null
              ? null
              : (d) {
                  setState(() => _delta += d.delta);
                },
          onPanEnd: widget.disabled || _animating != null
              ? null
              : (_) {
                  const threshold = 130.0;
                  if (_delta.dx > threshold) {
                    _commit(SwipeDirection.right);
                    return;
                  }
                  if (_delta.dx < -threshold) {
                    _commit(SwipeDirection.left);
                    return;
                  }
                  setState(() => _delta = Offset.zero);
                },
          child: Transform.translate(
            offset: _delta,
            child: Transform.rotate(
              angle: _rotateDeg * math.pi / 180,
              child: Opacity(
                opacity: widget.disabled ? 0.6 : 1,
                child: widget.child,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
