import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

enum SocialPlatform {
  tiktok,
  instagram,
  youtube,
  twitter,
  facebook,
  unknown;

  static SocialPlatform fromString(String? name) {
    switch (name?.toLowerCase().trim()) {
      case 'tiktok':
        return SocialPlatform.tiktok;
      case 'instagram':
      case 'ig':
        return SocialPlatform.instagram;
      case 'youtube':
      case 'yt':
        return SocialPlatform.youtube;
      case 'twitter':
      case 'x':
        return SocialPlatform.twitter;
      case 'facebook':
      case 'fb':
        return SocialPlatform.facebook;
      default:
        return SocialPlatform.unknown;
    }
  }

  String get displayName {
    switch (this) {
      case SocialPlatform.tiktok:
        return 'TikTok';
      case SocialPlatform.instagram:
        return 'Instagram';
      case SocialPlatform.youtube:
        return 'YouTube';
      case SocialPlatform.twitter:
        return 'X (Twitter)';
      case SocialPlatform.facebook:
        return 'Facebook';
      case SocialPlatform.unknown:
        return 'Media';
    }
  }

  Color get brandColor {
    switch (this) {
      case SocialPlatform.tiktok:
        return AppColors.tiktok;
      case SocialPlatform.instagram:
        return AppColors.instagram;
      case SocialPlatform.youtube:
        return AppColors.youtube;
      case SocialPlatform.twitter:
        return AppColors.twitter;
      case SocialPlatform.facebook:
        return AppColors.facebook;
      case SocialPlatform.unknown:
        return AppColors.primaryPurple;
    }
  }

  IconData get iconData {
    switch (this) {
      case SocialPlatform.tiktok:
        return Icons.music_note_rounded;
      case SocialPlatform.instagram:
        return Icons.camera_alt_rounded;
      case SocialPlatform.youtube:
        return Icons.play_arrow_rounded;
      case SocialPlatform.twitter:
        return Icons.tag_rounded;
      case SocialPlatform.facebook:
        return Icons.thumb_up_alt_rounded;
      case SocialPlatform.unknown:
        return Icons.link_rounded;
    }
  }
}
