import 'package:flutter/material.dart';
import '../core/theme/colors.dart';

class CommonLoader extends StatefulWidget {
  final double size;
  final Color color;

  const CommonLoader({
    super.key,
    this.size = 48,
    this.color = AppColors.primaryEmerald,
  });

  @override
  State<CommonLoader> createState() => _CommonLoaderState();
}

class _CommonLoaderState extends State<CommonLoader>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _glow;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);

    _glow = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _glow,
      builder: (context, child) {
        return Container(
          width: widget.size + 16,
          height: widget.size + 16,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: widget.color.withOpacity(0.4 * _glow.value),
                blurRadius: 24,
                spreadRadius: 4,
              ),
            ],
          ),
          child: CircularProgressIndicator(
            strokeWidth: 3,
            valueColor: AlwaysStoppedAnimation<Color>(
              widget.color.withOpacity(0.7 + 0.3 * _glow.value),
            ),
          ),
        );
      },
    );
  }
}
