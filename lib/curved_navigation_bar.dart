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

  // 1. Vertical Controller (Pop Up)
  late AnimationController _flattenController;
  // 2. Horizontal Controller (Stretch to 80%)
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

    // Movement animation (Left <-> Right)
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

    // --- SEQUENTIAL ANIMATION SETUP ---

    // 1. Vertical Up/Down
    _flattenController = AnimationController(
      vsync: this,
      duration: widget.flatDuration,
    );
    _flattenController.addListener(() => setState(() {}));

    // When Up finishes -> Start Stretching
    _flattenController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _widthController.forward();
      }
    });

    // 2. Width Stretch
    _widthController = AnimationController(
      vsync: this,
      duration: widget.flatDuration,
    );
    _widthController.addListener(() => setState(() {}));

    // When Shrink finishes -> Start Going Down
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

    // Animation Values
    final double verticalProgress = _flattenController.value;
    final double widthProgress = _widthController.value;

    return Container(
      height: widget.height,
      alignment: Alignment.bottomCenter,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final maxWidth = min(constraints.maxWidth, widget.maxWidth ?? constraints.maxWidth);

          // -- WIDTH CALCULATIONS --
          final double startWidth = 60.0;
          // Target width is 80% of the Page Width
          final double targetWidth = maxWidth * 0.8;

          final double currentWidth = startWidth + (widthProgress * (targetWidth - startWidth));
          final double currentRadius = (startWidth / 2) - (widthProgress * ((startWidth / 2) - 10.0));

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

                  // 3. Floating Button (Top Layer)
                  // FIX: Set left/right to 0 so the constraints allow the button to grow to full screen width.
                  Positioned(
                    bottom: -40 - (75.0 - widget.height),
                    left: 0,
                    right: 0,
                    // Remove 'width: maxWidth / _length' constraint!
                    child: Center(
                      child: Builder(builder: (context) {
                        // -- 1. Calculate Distances --
                        final double slotWidth = maxWidth / _length;
                        // The center X coordinate of the currently selected tab
                        final double activeTabCenter = (_pos * maxWidth) + (slotWidth / 2);
                        // The absolute center of the screen
                        final double screenCenter = maxWidth / 2;

                        // Distance from the screen center to the tab center
                        // (This is how far we need to push the button when it's closed)
                        final double distFromCenter = activeTabCenter - screenCenter;

                        // -- 2. Animate Translation --
                        // When widthProgress is 0 (Closed): Offset = distFromCenter (Button is on the tab)
                        // When widthProgress is 1 (Open): Offset = 0 (Button is in the center of screen)
                        final double currentXOffset = distFromCenter * (1 - widthProgress);

                        // Handle RTL
                        final double finalXOffset = textDirection == TextDirection.rtl ? -currentXOffset : currentXOffset;

                        return Transform.translate(
                          offset: Offset(
                            finalXOffset,
                            -(1 - _buttonHide) * 80 - (verticalProgress * 60),
                          ),
                          child: GestureDetector(
                            onTap: () {
                              _buttonTap(_endingIndex);
                            },
                            child: Container(
                              height: startWidth,
                              width: currentWidth, // Now this 440.0 width can actually render!
                              decoration: BoxDecoration(
                                color: widget.buttonBackgroundColor ?? widget.color,
                                borderRadius: BorderRadius.circular(currentRadius),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black26,
                                    blurRadius: 2,
                                    offset: Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Center(
                                child: Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: _icon,
                                ),
                              ),
                            ),
                          ),
                        );
                      }),
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

  void _buttonTap(int index) {
    if (!widget.letIndexChange(index) || _animationController.isAnimating) {
      return;
    }

    if (widget.index == index) {
      if (_isExpanded) {
        // Close: Shrink Width -> Then Drop Down
        _widthController.reverse();
        _isExpanded = false;
      } else {
        // Open: Pop Up -> Then Stretch Width
        _flattenController.forward();
        _isExpanded = true;
      }
    } else {
      if (_isExpanded) {
        _widthController.reverse();
        _isExpanded = false;
      }
    }

    if (widget.onTap != null) {
      widget.onTap!(index);
    }
    final newPosition = index / _length;
    setState(() {
      _startingPos = _pos;
      _endingIndex = index;
      _animationController.animateTo(newPosition, duration: widget.animationDuration, curve: widget.animationCurve);
    });
  }
}
