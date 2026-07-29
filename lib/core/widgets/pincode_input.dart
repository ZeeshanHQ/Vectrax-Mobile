import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

class GlowingPinCodeInput extends StatefulWidget {
  final int length;
  final ValueChanged<String> onChanged;
  final VoidCallback onCompleted;
  final TextEditingController controller;
  final Color baseColor;
  final Color glowingColor;
  final Color textColor;

  const GlowingPinCodeInput({
    super.key,
    this.length = 6,
    required this.onChanged,
    required this.onCompleted,
    required this.controller,
    required this.baseColor,
    required this.glowingColor,
    required this.textColor,
  });

  @override
  State<GlowingPinCodeInput> createState() => _GlowingPinCodeInputState();
}

class _GlowingPinCodeInputState extends State<GlowingPinCodeInput>
    with SingleTickerProviderStateMixin {
  late FocusNode _focusNode;
  late AnimationController _pulseController;
  late Animation<double> _glowAnimation;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();
    _focusNode.addListener(() {
      if (mounted) setState(() {});
    });

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat(reverse: true);

    _glowAnimation = Tween<double>(begin: 2.0, end: 8.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    widget.controller.addListener(() {
      if (mounted) {
        setState(() {});
        if (widget.controller.text.length == widget.length) {
          widget.onCompleted();
        }
      }
    });

    // Auto-request focus on first build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _focusNode.requestFocus();
      }
    });
  }

  void _requestKeyboard() {
    if (!_focusNode.hasFocus) {
      FocusScope.of(context).requestFocus(_focusNode);
    } else {
      // Already has focus but keyboard may be dismissed — unfocus then refocus
      _focusNode.unfocus();
      Future.delayed(const Duration(milliseconds: 50), () {
        if (mounted) FocusScope.of(context).requestFocus(_focusNode);
      });
    }
  }

  @override
  void dispose() {
    _focusNode.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque, // Captures taps even on transparent areas
      onTap: _requestKeyboard,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Hidden TextField — handles keyboard input
          SizedBox(
            width: 1,
            height: 1,
            child: TextField(
              controller: widget.controller,
              focusNode: _focusNode,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              maxLength: widget.length,
              autofocus: true,
              showCursor: false,
              onChanged: widget.onChanged,
              decoration: const InputDecoration(
                counterText: '',
                border: InputBorder.none,
              ),
              style: const TextStyle(color: Colors.transparent, fontSize: 1),
            ),
          ),

          // Visual PIN boxes
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: List.generate(widget.length, (index) {
              final isFocused =
                  _focusNode.hasFocus && widget.controller.text.length == index;
              final isFilled = index < widget.controller.text.length;
              final char = isFilled ? widget.controller.text[index] : '';

              return AnimatedBuilder(
                animation: _glowAnimation,
                builder: (context, child) {
                  return Container(
                    width: 48,
                    height: 56,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: widget.baseColor,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isFocused
                            ? widget.glowingColor
                            : Colors.white.withOpacity(0.1),
                        width: isFocused ? 2.0 : 1.0,
                      ),
                      boxShadow: [
                        if (isFocused)
                          BoxShadow(
                            color: widget.glowingColor.withOpacity(0.5),
                            blurRadius: _glowAnimation.value,
                            spreadRadius: _glowAnimation.value * 0.2,
                          ),
                      ],
                    ),
                    child: Text(
                      char,
                      style: GoogleFonts.outfit(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        color: widget.textColor,
                      ),
                    ),
                  );
                },
              );
            }),
          ),
        ],
      ),
    );
  }
}
