import 'dart:math';

import 'package:flutter/material.dart';
import 'src/nav_button.dart';
import 'src/nav_custom_painter.dart';

typedef _LetIndexPage = bool Function(int value);

class CurvedNavigationBar extends StatefulWidget {
  final List<Widget> items;
  final int index, mainIndex; // Added mainIndex support
  final Color color;
  final Color? buttonBackgroundColor;
  final Color backgroundColor;
  final ValueChanged<int>? onTap;
  final _LetIndexPage letIndexChange;
  final Curve animationCurve;
  final Duration animationDuration, flatDuration, iconRevealDuration;
  final double height;
  final double? maxWidth;
  final bool isAdmin;

  CurvedNavigationBar({
    Key? key,
    required this.items,
    this.index = 0,
    this.mainIndex = 1, // Default main action button is index 1
    this.color = Colors.white,
    this.buttonBackgroundColor,
    this.backgroundColor = Colors.blueAccent,
    this.onTap,
    this.isAdmin = false,
    _LetIndexPage? letIndexChange,
    this.animationCurve = Curves.easeOut,
    this.animationDuration = const Duration(milliseconds: 500),
    this.iconRevealDuration = const Duration(milliseconds: 500),
    this.flatDuration = const Duration(milliseconds: 300),
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

  // -- ANIMATION CONTROLLERS --
  late AnimationController _flattenController;
  late AnimationController _widthController;
  late AnimationController _iconsController;

  bool _isExpanded = false;

  // NEW: Stores the index we want to go to after closing the animation
  int? _pendingIndex;

  bool get _menuActive => _flattenController.value > 0 || _widthController.value > 0 || _iconsController.value > 0 || _isExpanded;

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

    // --- SEQUENTIAL ANIMATION CHAIN ---

    // 1. Vertical Up/Down
    _flattenController = AnimationController(
      vsync: this,
      duration: widget.flatDuration,
    );
    _flattenController.addListener(() => setState(() {}));

    _flattenController.addStatusListener((status) {
      // OPEN: When Up finishes -> Start Stretching
      if (status == AnimationStatus.completed) {
        _widthController.forward();
      }

      // CLOSE: When Drop Down finishes -> Check if we need to move to a new tab
      if (status == AnimationStatus.dismissed) {
        if (_pendingIndex != null) {
          // The menu is fully closed, NOW we move to the other tab
          _handleMove(_pendingIndex!);
          _pendingIndex = null; // Reset pending state
        }
      }
    });

    // 2. Width Stretch & Circle Spawning
    _widthController = AnimationController(
      vsync: this,
      duration: widget.flatDuration,
    );
    _widthController.addListener(() => setState(() {}));

    _widthController.addStatusListener((status) {
      // OPEN: When Stretch finishes -> Start Icons
      if (status == AnimationStatus.completed) {
        _iconsController.forward();
      }
      // CLOSE: When Shrink finishes -> Start Going Down
      if (status == AnimationStatus.dismissed) {
        _flattenController.reverse();
      }
    });

    // 3. Icons Reveal
    _iconsController = AnimationController(
      vsync: this,
      duration: widget.iconRevealDuration,
    );
    _iconsController.addListener(() => setState(() {}));

    // CLOSE: When Icons Hide finishes -> Start Shrinking
    _iconsController.addStatusListener((status) {
      if (status == AnimationStatus.dismissed) {
        _widthController.reverse();
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
    _iconsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final textDirection = Directionality.of(context);
    final double widthProgress = _widthController.value;
    final double iconsProgress = _iconsController.value;

    return Container(
      height: widget.height,
      alignment: Alignment.bottomCenter,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final maxWidth = min(constraints.maxWidth, widget.maxWidth ?? constraints.maxWidth);

          // -- DIMENSIONS --
          final double startWidth = 60.0;
          final double targetWidth = widget.isAdmin ? maxWidth * 0.8 : maxWidth * 0.6;
          final double targetRadius = 30.0;

          final double currentWidth = startWidth + (widthProgress * (targetWidth - startWidth));
          final double currentRadius = (startWidth / 2) - (widthProgress * ((startWidth / 2) - targetRadius));
          final int actionCount = widget.isAdmin ? 5 : 4;

// distance available for icon centers (leave some padding)
          final double availableSpace = targetWidth - 20;

// step between adjacent icon centers
          final double step = availableSpace / actionCount;

// base offsets: [-1.5, -0.5, +0.5, +1.5] for 4
// or [-2, -1, 0, +1, +2] for 5
          final List<double> baseOffsets = List.generate(actionCount, (i) {
            final double mid = (actionCount - 1) / 2.0;
            return (i - mid) * step;
          });

// keep your sequential spawn timings:
          final double p1 = (widthProgress / 0.5).clamp(0.0, 1.0);
          final double p2 = ((widthProgress - 0.5) / 0.5).clamp(0.0, 1.0);

// inner group spawns first, then outer group
          double spawnMultiplierForIndex(int i) {
            if (actionCount == 4) {
              // indices 1 & 2 are inner, 0 & 3 are outer
              return (i == 1 || i == 2) ? p1 : p2;
            } else {
              // 5: indices 1,2,3 inner (including center), 0 & 4 outer
              return (i == 1 || i == 2 || i == 3) ? p1 : p2;
            }
          }

          final List<double> iconPositions = List.generate(actionCount, (i) => baseOffsets[i] * spawnMultiplierForIndex(i));

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
                      painter: NavCustomPainter(_pos, _length, widget.color, textDirection, 0.0),
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
                  // 3) Spawned bar + Main circle (two layers)
                  Positioned(
                    bottom: -40 - (75.0 - widget.height),
                    left: 0,
                    right: 0,
                    child: Center(
                      child: Stack(
                        clipBehavior: Clip.none,
                        alignment: Alignment.center,
                        children: [
                          // A) SPAWNED BAR (this is what stretches into pill & shows icons)
                          IgnorePointer(
                            ignoring: !_menuActive,
                            child: Opacity(
                              opacity: _menuActive ? 1.0 : 0.0,
                              child: Transform.translate(
                                // same X tracking, but this one moves UP during spawn
                                offset: Offset(
                                  finalXOffset,
                                  -(1 - _buttonHide) * 80 - (_flattenController.value * 70),
                                ),
                                child: _buildSpawnedBar(
                                  startWidth: startWidth,
                                  currentWidth: currentWidth,
                                  currentRadius: currentRadius,
                                  iconPositions: iconPositions,
                                  iconsProgress: iconsProgress,
                                  isAdmin: widget.isAdmin,
                                ),
                              ),
                            ),
                          ),

                          // B) MAIN CIRCLE (always stays at original position)
                          Transform.translate(
                            offset: Offset(finalXOffset, -(1 - _buttonHide) * 80),
                            child: _buildMainCircle(startWidth),
                          ),
                        ],
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

  Widget _buildAnimatedItem({
    required double spawnOpacity,
    required double revealProgress,
    required IconData icon,
    Widget? fallbackIcon,
    VoidCallback? onPressed, // NEW
  }) {
    final double circleOpacity = (spawnOpacity * (1 - revealProgress)).clamp(0.0, 1.0);
    final double yOffset = 20 * (1 - revealProgress);

    // Fixed hit area (important!)
    const double hitSize = 48.0;

    return SizedBox(
      width: hitSize,
      height: hitSize,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Layer A: spawn circle (visual only)
          IgnorePointer(
            child: Opacity(
              opacity: circleOpacity,
              child: Container(
                width: 40.0,
                height: 40.0,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
                child: fallbackIcon != null && revealProgress < 0.5 ? Center(child: fallbackIcon) : null,
              ),
            ),
          ),

          // Layer B: clickable final icon
          if (revealProgress > 0.01)
            Transform.translate(
              offset: Offset(0, yOffset),
              child: Opacity(
                opacity: revealProgress,
                child: Material(
                  color: Colors.transparent,
                  child: InkResponse(
                    radius: hitSize / 2,
                    containedInkWell: true,
                    onTap: onPressed ??
                        () {
                          print("Clicked $icon");
                        },
                    child: Center(
                      child: Icon(icon, color: Colors.white, size: 28),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMainCircle(double size) {
    final bool showClose = _menuActive;

    return GestureDetector(
      onTap: () {
        // Main circle acts like: open/close when we're on mainIndex,
        // otherwise it just navigates to mainIndex (your existing behavior).
        if (_endingIndex == widget.mainIndex && showClose) {
          // close (reverse chain)
          _iconsController.reverse();
          _isExpanded = false;
          return;
        }
        _buttonTap(_endingIndex);
      },
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: widget.buttonBackgroundColor ?? widget.color,
          shape: BoxShape.circle,
          boxShadow: const [
            BoxShadow(color: Colors.black26, blurRadius: 2, offset: Offset(0, 2)),
          ],
        ),
        child: Center(
          child: AnimatedSwitcher(
            duration: widget.flatDuration,
            transitionBuilder: (child, anim) => FadeTransition(opacity: anim, child: child),
            child: showClose
                ? const Icon(Icons.close, key: ValueKey('main_close'), color: Colors.white, size: 28)
                : SizedBox(key: const ValueKey('main_plus'), child: _icon),
          ),
        ),
      ),
    );
  }

  Widget _buildSpawnedBar({
    required double startWidth,
    required double currentWidth,
    required double currentRadius,
    required List<double> iconPositions, // CHANGED
    required double iconsProgress,
    required bool isAdmin,
  }) {
    // define the icons you want, in order left -> right
    final List<IconData> actions = isAdmin
        ? [
            Icons.campaign,
            Icons.chat_bubble_outline,
            Icons.qr_code_scanner,
            Icons.admin_panel_settings,
            Icons.restaurant,
          ]
        : [
            Icons.campaign,
            Icons.chat_bubble_outline,
            Icons.qr_code_scanner,
            Icons.restaurant,
          ];

    return Container(
      height: startWidth,
      width: currentWidth,
      decoration: BoxDecoration(
        color: widget.buttonBackgroundColor ?? widget.color,
        borderRadius: BorderRadius.circular(currentRadius),
        boxShadow: const [
          BoxShadow(color: Colors.black26, blurRadius: 2, offset: Offset(0, 2)),
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: List.generate(actions.length, (i) {
          final icon = actions[i];

          return Transform.translate(
            offset: Offset(iconPositions[i], 0),
            child: _buildAnimatedItem(
              spawnOpacity: 1.0, // keep spawn circle behavior driven by revealProgress
              revealProgress: iconsProgress,
              icon: icon,
              onPressed: () => print("Clicked $icon"),
            ),
          );
        }),
      ),
    );
  }

  // Replace your existing _buttonTap method with this one:
  void _buttonTap(int index) {
    if (!widget.letIndexChange(index) || _animationController.isAnimating) return;

    // 1. LOGIC FOR MAIN ACTION BUTTON (e.g., Index 1)
    if (widget.mainIndex == index) {
      // CASE A: We are coming from a different tab (Navigating TO the main button)
      if (widget.index != index) {
        // Just move the bubble. Do NOT open the animation yet.
        _handleMove(index);
        return;
      }

      // CASE B: We are ALREADY at the main button (Toggling the menu)
      if (_isExpanded) {
        _iconsController.reverse(); // Close
        _isExpanded = false;
      } else {
        _flattenController.forward(); // Open
        _isExpanded = true;
      }
      return;
    }

    // 2. LOGIC FOR OTHER BUTTONS
    if (_isExpanded) {
      // If expanded, close first, then move (Close First Logic)
      _pendingIndex = index;
      _iconsController.reverse();
      _isExpanded = false;
      return;
    }

    // 3. NORMAL NAVIGATION
    _handleMove(index);
  }

  // NEW: Centralized helper to actually perform the nav bar slide
  void _handleMove(int index) {
    if (widget.onTap != null) widget.onTap!(index);
    final newPosition = index / _length;
    setState(() {
      _startingPos = _pos;
      _endingIndex = index;
      _animationController.animateTo(newPosition, duration: widget.animationDuration, curve: widget.animationCurve);
    });
  }
}
