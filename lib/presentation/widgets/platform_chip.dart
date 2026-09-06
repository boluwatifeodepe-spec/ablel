import 'package:flutter/material.dart';
import '../../core/utils/platform_utils.dart';

class PlatformChip extends StatelessWidget {
  final SocialPlatform platform;
  final VoidCallback? onTap;
  final bool isSelected;

  const PlatformChip({
    super.key,
    required this.platform,
    this.onTap,
    this.isSelected = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = platform.brandColor;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(30),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? color.withOpacity(0.25) : color.withOpacity(0.12),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(
              color: isSelected ? color : color.withOpacity(0.3),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                platform.iconData,
                size: 16,
                color: color,
              ),
              const SizedBox(width: 6),
              Text(
                platform.displayName,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
