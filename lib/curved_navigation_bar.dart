import 'dart:math';

import 'package:flutter/material.dart';
import 'src/nav_button.dart';
import 'src/nav_custom_painter.dart';

typedef _LetIndexPage = bool Function(int value);

class CurvedNavigationBar extends StatefulWidget {
  final List<Widget> items;
  final int index;
  final Color color;
  final Color? buttonBackgroundColor;
  final Color backgroundColor;
  final ValueChanged<int>? onTap;
  final _LetIndexPage letIndexChange;
  final Curve animationCurve;
  final Duration animationDuration, flatDuration;
  final double height;
  final double? maxWidth;

  CurvedNavigationBar({
    Key? key,
    required this.items,
    this.index = 0,
    this.color = Colors.white,
    this.buttonBackgroundColor,
    this.backgroundColor = Colors.blueAccent,
    this.onTap,
    _LetIndexPage? letIndexChange,
    this.animationCurve = Curves.easeOut,
    this.animationDuration = const Duration(milliseconds: 500),
    this.flatDuration = const Duration(milliseconds: 250),
    this.height = 75.0,
    this.maxWidth,
  })  : letIndexChange = letIndexChange ?? ((_) => true),
        assert(items.isNotEmpty),
        assert(0 <= index && index < items.length),
        assert(0 <= height && height <= 75.0),
        assert(maxWidth == null || 0 <= maxWidth),
        super(key: key);

  @override
  CurvedNavigationBarState createState() => CurvedNavigationBarState();
}

class CurvedNavigationBarState extends State<CurvedNavigationBar> with TickerProviderStateMixin {
  late double _startingPos;
  late int _endingIndex;
  late double _pos;
  double _buttonHide = 0;
  late Widget _icon;
  late AnimationController _animationController;
  late int _length;

  late AnimationController _flattenController;
  late AnimationController _widthController;

  bool _isExpanded = false;

  @override
  void initState() {
    super.initState();
    _icon = widget.items[widget.index];
    _length = widget.items.length;
    _pos = widget.index / _length;
    _startingPos = widget.index / _length;
    _endingIndex = widget.index;

    _animationController = AnimationController(vsync: this, value: _pos);
    _animationController.addListener(() {
      setState(() {
        _pos = _animationController.value;
        final endingPos = _endingIndex / widget.items.length;
        final middle = (endingPos + _startingPos) / 2;
        if ((endingPos - _pos).abs() < (_startingPos - _pos).abs()) {
          _icon = widget.items[_endingIndex];
        }
        _buttonHide = (1 - ((middle - _pos) / (_startingPos - middle)).abs()).abs();
      });
    });

    // 1. Vertical Up/Down
    _flattenController = AnimationController(
      vsync: this,
      duration: widget.flatDuration,
    );
    _flattenController.addListener(() => setState(() {}));

    _flattenController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _widthController.forward();
      }
    });

    // 2. Width Stretch & Circle Spawning
    _widthController = AnimationController(
      vsync: this,
      duration: widget.flatDuration,
    );
    _widthController.addListener(() => setState(() {}));

    _widthController.addStatusListener((status) {
      if (status == AnimationStatus.dismissed) {
        _flattenController.reverse();
      }
    });
  }

  @override
  void didUpdateWidget(CurvedNavigationBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.index != widget.index) {
      final newPosition = widget.index / _length;
      _startingPos = _pos;
      _endingIndex = widget.index;
      _animationController.animateTo(newPosition, duration: widget.animationDuration, curve: widget.animationCurve);
    }
    if (!_animationController.isAnimating) {
      _icon = widget.items[_endingIndex];
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    _flattenController.dispose();
    _widthController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final textDirection = Directionality.of(context);
    final double verticalProgress = _flattenController.value;
    final double widthProgress = _widthController.value;

    return Container(
      height: widget.height,
      alignment: Alignment.bottomCenter,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final maxWidth = min(constraints.maxWidth, widget.maxWidth ?? constraints.maxWidth);

          // -- DIMENSIONS --
          final double startWidth = 60.0;
          final double targetWidth = maxWidth * 0.8;
          final double currentWidth = startWidth + (widthProgress * (targetWidth - startWidth));
          final double currentRadius = (startWidth / 2) - (widthProgress * ((startWidth / 2) - 10.0));

          // -- CIRCLE SPAWNING MATH --
          // We need 5 circles total.
          // Spacing distance (delta) between centers.
          final double availableSpace = targetWidth - 20; // Padding
          // Distance between each circle center
          final double delta = availableSpace / 5;

          // Phase 1 (0.0 -> 0.5): Inner circles move out from Center
          double p1 = (widthProgress / 0.5).clamp(0.0, 1.0);

          // Phase 2 (0.5 -> 1.0): Outer circles move out from Inner circles
          double p2 = ((widthProgress - 0.5) / 0.5).clamp(0.0, 1.0);

          // Positions relative to center (0)
          // 1. Inner Pair (Left -1, Right +1)
          double innerPos = p1 * delta;

          // 2. Outer Pair (Left -2, Right +2)
          // They start exactly where Inner Pair is (innerPos), then add their own distance
          double outerPos = innerPos + (p2 * delta);

          // -- CENTER OFFSET CALCULATION --
          final double slotWidth = maxWidth / _length;
          final double activeTabCenter = (_pos * maxWidth) + (slotWidth / 2);
          final double screenCenter = maxWidth / 2;
          final double distFromCenter = activeTabCenter - screenCenter;
          final double currentXOffset = distFromCenter * (1 - widthProgress);
          final double finalXOffset = textDirection == TextDirection.rtl ? -currentXOffset : currentXOffset;

          return Align(
            alignment: textDirection == TextDirection.ltr ? Alignment.bottomLeft : Alignment.bottomRight,
            child: SizedBox(
              width: maxWidth,
              child: Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.bottomCenter,
                children: <Widget>[
                  // 1. Background Painter
                  Positioned(
                    bottom: 0 - (75.0 - widget.height),
                    left: 0,
                    right: 0,
                    height: 75.0,
                    child: CustomPaint(
                      painter: NavCustomPainter(_pos, _length, widget.color, textDirection, verticalProgress),
                    ),
                  ),

                  // 2. Icons Row
                  Positioned(
                    bottom: 0 - (75.0 - widget.height),
                    left: 0,
                    right: 0,
                    height: 100.0,
                    child: Row(
                        children: widget.items
                            .map((item) => NavButton(
                                  onTap: _buttonTap,
                                  position: _pos,
                                  length: _length,
                                  index: widget.items.indexOf(item),
                                  child: Center(child: item),
                                ))
                            .toList()),
                  ),

                  // 3. Floating Button
                  Positioned(
                    bottom: -40 - (75.0 - widget.height),
                    left: 0, right: 0, // Full width for centering logic
                    child: Center(
                      child: Transform.translate(
                        offset: Offset(finalXOffset, -(1 - _buttonHide) * 80 - (verticalProgress * 60)),
                        child: GestureDetector(
                          onTap: () {
                            _buttonTap(_endingIndex);
                          },
                          child: Container(
                            height: startWidth,
                            width: currentWidth,
                            decoration: BoxDecoration(
                              color: widget.buttonBackgroundColor ?? widget.color,
                              borderRadius: BorderRadius.circular(currentRadius),
                              boxShadow: [
                                BoxShadow(color: Colors.black26, blurRadius: 2, offset: Offset(0, 2)),
                              ],
                            ),
                            // -- CHANGED: Using a Stack to manage the 5 circles --
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                // OUTER LEFT (-2)
                                Transform.translate(
                                  offset: Offset(-outerPos, 0),
                                  child: _buildWhiteCircle(opacity: p2), // Fades in during Phase 2
                                ),
                                // OUTER RIGHT (+2)
                                Transform.translate(
                                  offset: Offset(outerPos, 0),
                                  child: _buildWhiteCircle(opacity: p2),
                                ),
                                // INNER LEFT (-1)
                                Transform.translate(
                                  offset: Offset(-innerPos, 0),
                                  child: _buildWhiteCircle(opacity: p1), // Fades in during Phase 1
                                ),
                                // INNER RIGHT (+1)
                                Transform.translate(
                                  offset: Offset(innerPos, 0),
                                  child: _buildWhiteCircle(opacity: p1),
                                ),
                                // CENTER (0) - Contains Original Icon
                                _isExpanded ? _buildWhiteCircle(child: _icon, opacity: 1.0) : _icon,
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // Helper widget for the circles
  Widget _buildWhiteCircle({Widget? child, required double opacity}) => Opacity(
        opacity: opacity,
        child: Container(
          width: 40.0, // Size of the small white circles
          height: 40.0,
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
          ),
          child: child != null ? Center(child: child) : null,
        ),
      );

  void _buttonTap(int index) {
    if (!widget.letIndexChange(index) || _animationController.isAnimating) return;

    if (widget.index == index) {
      if (_isExpanded) {
        _widthController.reverse(); // Close Width first
        _isExpanded = false;
      } else {
        _flattenController.forward(); // Open Up first
        _isExpanded = true;
      }
    } else {
      if (_isExpanded) {
        _widthController.reverse();
        _isExpanded = false;
      }
    }

    if (widget.onTap != null) widget.onTap!(index);

    final newPosition = index / _length;
    setState(() {
      _startingPos = _pos;
      _endingIndex = index;
      _animationController.animateTo(newPosition, duration: widget.animationDuration, curve: widget.animationCurve);
    });
  }
}
