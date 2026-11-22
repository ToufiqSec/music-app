import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../core/utils/numeric_utils.dart';
import '../providers/auth_provider.dart';
import '../screens/profile_screen.dart';
import '../screens/login_screen.dart';
import '../theme/app_colors.dart';

/// Universal Twilight Calm Profile Avatar Widget.
/// Placed consistently across Home, Library, Search, Albums, and Moods headers.
class AppProfileAvatar extends StatelessWidget {
  final double size;

  const AppProfileAvatar({
    super.key,
    this.size = 38.0,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, authProvider, _) {
        final isAuthenticated = authProvider.isAuthenticated;
        final avatarUrl = authProvider.avatarUrl.trim();
        final displayName = authProvider.displayName.trim();
        final initial = (displayName.isNotEmpty && displayName != 'Guest' && displayName != 'Music Lover')
            ? displayName[0].toUpperCase()
            : (authProvider.email.isNotEmpty && authProvider.email != 'Guest'
                ? authProvider.email[0].toUpperCase()
                : '');

        Widget fallbackContent;
        if (isAuthenticated && initial.isNotEmpty) {
          fallbackContent = Text(
            initial,
            style: TextStyle(
              color: Colors.white,
              fontSize: size * 0.42,
              fontWeight: FontWeight.bold,
            ),
          );
        } else {
          fallbackContent = Icon(
            Icons.person_rounded,
            size: size * 0.55,
            color: Colors.white70,
          );
        }

        Widget content;
        if (isAuthenticated && avatarUrl.isNotEmpty) {
          content = ClipOval(
            child: CachedNetworkImage(
              imageUrl: avatarUrl,
              width: size,
              height: size,
              fit: BoxFit.cover,
              memCacheWidth: safeInt(size * 2, fallback: 76),
              memCacheHeight: safeInt(size * 2, fallback: 76),
              placeholder: (_, __) => Center(child: fallbackContent),
              errorWidget: (_, __, ___) => Center(child: fallbackContent),
            ),
          );
        } else {
          content = Center(child: fallbackContent);
        }

        return Semantics(
          button: true,
          label: 'Profile',
          child: Tooltip(
            message: 'Profile',
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(size / 2),
                onTap: () {
                  if (isAuthenticated) {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const ProfileScreen()),
                    );
                  } else {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const LoginScreen()),
                    );
                  }
                },
                child: Container(
                  width: size,
                  height: size,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.surface2.withValues(alpha: 0.85),
                    border: Border.all(
                      color: isAuthenticated
                          ? AppColors.primarySoft.withValues(alpha: 0.7)
                          : AppColors.primarySoft.withValues(alpha: 0.35),
                      width: 1.2,
                    ),
                  ),
                  child: content,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
