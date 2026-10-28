import 'package:flutter/material.dart';

/// Holds the bottom-nav tabs' navigators (like an IndexedStack, so each tab
/// keeps its state and scroll position) and cross-fades between them: the new
/// tab fades in while scaling up slightly, the old one fades out. Once the
/// switch finishes, hidden tabs are offstage, so they cost nothing and screen
/// readers ignore them.
class AnimatedBranchContainer extends StatefulWidget {
  const AnimatedBranchContainer({super.key, required this.currentIndex, required this.children});

  final int currentIndex;
  final List<Widget> children;

  static const duration = Duration(milliseconds: 280);

  @override
  State<AnimatedBranchContainer> createState() => _AnimatedBranchContainerState();
}

class _AnimatedBranchContainerState extends State<AnimatedBranchContainer> with SingleTickerProviderStateMixin {
  late final AnimationController _controller =
      AnimationController(vsync: this, duration: AnimatedBranchContainer.duration, value: 1);
  late final Animation<double> _fadeIn = CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic);
  late final Animation<double> _fadeOut = ReverseAnimation(
    CurvedAnimation(parent: _controller, curve: const Interval(0, 0.6, curve: Curves.easeOut)),
  );
  late final Animation<double> _scaleIn = Tween<double>(begin: 0.97, end: 1).animate(_fadeIn);

  int? _previous;

  @override
  void didUpdateWidget(AnimatedBranchContainer old) {
    super.didUpdateWidget(old);
    if (old.currentIndex == widget.currentIndex) return;
    _previous = old.currentIndex;
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.value = 1;
    } else {
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final switching = _controller.isAnimating;
        final current = widget.currentIndex;
        // Paint order: hidden tabs, then the outgoing tab, then the incoming one on top.
        final order = [
          for (var i = 0; i < widget.children.length; i++)
            if (i != current && i != _previous) i,
          if (_previous != null && _previous != current) _previous!,
          current,
        ];
        return Stack(
          fit: StackFit.expand,
          children: [
            for (final i in order)
              KeyedSubtree(
                key: ValueKey(i),
                child: _branch(
                  i,
                  visible: i == current || (switching && i == _previous),
                  opacity: i == current ? _fadeIn : _fadeOut,
                  scale: i == current ? _scaleIn : kAlwaysCompleteAnimation,
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _branch(int i, {required bool visible, required Animation<double> opacity, required Animation<double> scale}) {
    final active = i == widget.currentIndex;
    return Offstage(
      offstage: !visible,
      child: TickerMode(
        enabled: visible,
        child: IgnorePointer(
          ignoring: !active,
          child: ExcludeSemantics(
            excluding: !active,
            child: FadeTransition(
              opacity: opacity,
              child: ScaleTransition(scale: scale, child: widget.children[i]),
            ),
          ),
        ),
      ),
    );
  }
}
