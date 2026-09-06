import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';

class GradientButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final String text;
  final Widget? icon;
  final bool isLoading;
  final double height;
  final double borderRadius;
  final Gradient? gradient;
  final bool isFullWidth;
  final Color? textColor;

  const GradientButton({
    super.key,
    required this.onPressed,
    required this.text,
    this.icon,
    this.isLoading = false,
    this.height = 54,
    this.borderRadius = 16,
    this.gradient,
    this.isFullWidth = true,
    this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveGradient = onPressed == null
        ? const LinearGradient(
            colors: [Color(0xFF2C344A), Color(0xFF1E2436)],
          )
        : (gradient ?? AppColors.vibrantPurpleGradient);

    Widget content = Container(
      height: height,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: BoxDecoration(
        gradient: effectiveGradient,
        borderRadius: BorderRadius.circular(borderRadius),
        boxShadow: onPressed != null
            ? [
                BoxShadow(
                  color: AppColors.primaryPurple.withOpacity(0.35),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ]
            : null,
      ),
      child: Center(
        child: isLoading
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : Row(
                mainAxisSize: isFullWidth ? MainAxisSize.max : MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (icon != null) ...[
                    icon!,
                    const SizedBox(width: 10),
                  ],
                  Text(
                    text,
                    style: TextStyle(
                      color: textColor ?? (onPressed == null ? AppColors.textMuted : Colors.white),
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.2,
                    ),
                  ),
                ],
              ),
      ),
    );

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: isLoading ? null : onPressed,
        borderRadius: BorderRadius.circular(borderRadius),
        child: content,
      ),
    );
  }
}
