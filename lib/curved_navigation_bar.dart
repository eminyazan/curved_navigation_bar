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
  final Duration animationDuration;
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
    this.animationDuration = const Duration(milliseconds: 600),
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
  // Changed to Mixin to support multiple controllers
  late double _startingPos;
  late int _endingIndex;
  late double _pos;
  double _buttonHide = 0;
  late Widget _icon;
  late AnimationController _animationController;
  late int _length;

  // NEW: Controller for the Flatten/Pop-up animation
  late AnimationController _flattenController;
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

    // Flatten animation (Up <-> Down)
    _flattenController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 400), // Speed of the pop-up
    );
    _flattenController.addListener(() {
      setState(() {});
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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final textDirection = Directionality.of(context);

    // 1. The Container determines the total "Hit Test" area.
    // We keep the extra height (70.0) so the top part captures clicks.
    return Container(
      height: widget.height,
      alignment: Alignment.bottomCenter,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final maxWidth = min(constraints.maxWidth, widget.maxWidth ?? constraints.maxWidth);
          return Align(
            alignment: textDirection == TextDirection.ltr ? Alignment.bottomLeft : Alignment.bottomRight,
            child: SizedBox(
              // Use SizedBox to constrain width, but let height fill parent
              width: maxWidth,
              child: Stack(
                // 2. IMPORTANT: The Stack now fills the entire height (145px)
                // This means clicks anywhere in this area are checked against the children.
                clipBehavior: Clip.none,
                alignment: Alignment.bottomCenter,
                children: <Widget>[
                  // 3. Background Painter (Pinned to the bottom 75px)
                  // We treat this layer specifically as the "Bar"
                  Positioned(
                    bottom: 0 - (75.0 - widget.height),
                    left: 0,
                    right: 0,
                    height: 75.0, // Force the painter to stay in the original 75px box
                    child: CustomPaint(
                      painter: NavCustomPainter(_pos, _length, widget.color, textDirection, _flattenController.value),
                    ),
                  ),

                  // 4. Icons Row (Pinned to the bottom)
                  Positioned(
                    bottom: 0 - (75.0 - widget.height),
                    left: 0,
                    right: 0,
                    height: 100.0, // Keep your original height for buttons
                    child: Row(
                        children: widget.items.map((item) => NavButton(
                        onTap: _buttonTap,
                        position: _pos,
                        length: _length,
                        index: widget.items.indexOf(item),
                        child: Center(child: item),
                      )).toList()),
                  ),

                  // 5. Floating Button (Top Layer)
                  // It is now a child of the tall Stack, so it can be clicked anywhere!
                  Positioned(
                    bottom: -40 - (75.0 - widget.height),
                    left: textDirection == TextDirection.rtl ? null : _pos * maxWidth,
                    right: textDirection == TextDirection.rtl ? _pos * maxWidth : null,
                    width: maxWidth / _length,
                    child: Center(
                      child: Transform.translate(
                        offset: Offset(
                          0,
                          -(1 - _buttonHide) * 80 - (_flattenController.value * 60),
                        ),
                        child: GestureDetector(
                          onTap: () {
                            print('Floating button tapped!'); // This will work now
                            _buttonTap(_endingIndex);
                          },
                          child: Material(
                            color: widget.buttonBackgroundColor ?? widget.color,
                            type: MaterialType.circle,
                            child: Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: _icon,
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

  void _buttonTap(int index) {
    print('Button tapped: $index');
    if (!widget.letIndexChange(index) || _animationController.isAnimating) {
      return;
    }

    // --- TOGGLE LOGIC START ---
    // Assuming your "Main" button is at index 1. Change '1' if it's different.
    if (index == 1) {
      if (_isExpanded) {
        print('Collapsing the button');
        // If already expanded/flat, reverse it (go back to curve)
        _flattenController.reverse();
        _isExpanded = false;
      } else {
        print('Expanding the button');
        // If curved, go forward (flatten and pop up)
        _flattenController.forward();
        _isExpanded = true;
      }
    } else {
      // If user clicks a different button (0 or 2), we should reset the curve
      if (_isExpanded) {
        print('Collapsing the button due to different index tap');
        _flattenController.reverse();
        _isExpanded = false;
      }
    }
    // --- TOGGLE LOGIC END ---

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
