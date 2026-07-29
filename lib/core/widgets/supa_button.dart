import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:supa_app/core/theme/app_theme.dart';

class SupaButton extends StatefulWidget {
  final Widget? child;
  final String? text;
  final VoidCallback? onPressed;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final bool isFullWidth;
  final bool isLoading;
  final bool outline;
  final OutlinedBorder? shape;

  const SupaButton({
    super.key,
    this.child,
    this.text,
    this.onPressed,
    this.backgroundColor,
    this.foregroundColor,
    this.isFullWidth = true,
    this.isLoading = false,
    this.outline = false,
    this.shape,
  }) : assert(child != null || text != null);

  @override
  State<SupaButton> createState() => _SupaButtonState();
}

class _SupaButtonState extends State<SupaButton> {
  bool _isPressed = false;

  bool _isDark(Color c) => c.computeLuminance() < 0.4;

  @override
  Widget build(BuildContext context) {
    final bgColor = widget.outline
        ? Colors.transparent
        : (widget.backgroundColor ?? AppTheme.accent);
    final fgColor = widget.outline
        ? (widget.backgroundColor ?? AppTheme.accent)
        : (widget.foregroundColor ?? AppTheme.background);

    final isMorphing = widget.isLoading;
    // When button is dark, use bright loader so it's visible on white screens
    final loaderColor = _isDark(bgColor)
        ? Colors.white
        : (widget.foregroundColor ?? AppTheme.background);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
      transform: Matrix4.identity()
        ..scale(_isPressed && !isMorphing ? 0.96 : 1.0),
      child: Align(
        alignment: Alignment.center,
        child: SizedBox(
          width:
              isMorphing ? 56 : (widget.isFullWidth ? double.infinity : null),
          child: ElevatedButton(
            onPressed: widget.isLoading
                ? null
                : () {
                    HapticFeedback.lightImpact();
                    widget.onPressed?.call();
                  },
            style: ElevatedButton.styleFrom(
              backgroundColor: bgColor,
              foregroundColor: fgColor,
              shape: widget.shape ??
                  RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(isMorphing ? 999 : 12),
                    side: widget.outline
                        ? BorderSide(
                            color: (widget.backgroundColor ?? AppTheme.accent)
                                .withOpacity(0.5),
                          )
                        : BorderSide.none,
                  ),
              minimumSize: const Size(0, 56),
              padding: EdgeInsets.symmetric(
                horizontal: isMorphing ? 0 : 28,
              ),
              elevation: 0,
            ).copyWith(
              overlayColor: WidgetStateProperty.resolveWith((states) {
                if (widget.isLoading) return Colors.transparent;
                if (states.contains(WidgetState.pressed)) {
                  // Neon Blue Ripple Effect
                  return AppTheme.accent.withOpacity(0.3);
                }
                return null;
              }),
            ),
            clipBehavior: Clip.antiAlias,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInCubic,
              child: widget.isLoading
                  ? SizedBox(
                      key: const ValueKey('loader'),
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        valueColor: AlwaysStoppedAnimation<Color>(loaderColor),
                        backgroundColor: loaderColor.withOpacity(0.2),
                      ),
                    )
                  : SingleChildScrollView(
                      key: const ValueKey('label'),
                      scrollDirection: Axis.horizontal,
                      physics: const NeverScrollableScrollPhysics(),
                      child: widget.child ??
                          Text(
                            widget.text!.toUpperCase(),
                            style: const TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 12,
                              letterSpacing: 1,
                            ),
                          ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
