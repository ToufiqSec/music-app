import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/services/app_update_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_radii.dart';
import '../theme/app_text_styles.dart';

class UpdateDialog extends StatefulWidget {
  final UpdateInfo updateInfo;

  const UpdateDialog({super.key, required this.updateInfo});

  static Future<void> show(BuildContext context, UpdateInfo info) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => UpdateDialog(updateInfo: info),
    );
  }

  @override
  State<UpdateDialog> createState() => _UpdateDialogState();
}

class _UpdateDialogState extends State<UpdateDialog> {
  bool _isDownloading = false;
  double _progress = 0.0;
  String _statusText = '';

  void _startUpdate() {
    HapticFeedback.mediumImpact();
    setState(() {
      _isDownloading = true;
      _statusText = 'Downloading update...';
    });

    AppUpdateService.downloadAndInstall(widget.updateInfo).listen(
      (progress) {
        if (mounted) {
          setState(() {
            _progress = progress;
            _statusText = 'Downloading: ${(progress * 100).toInt()}%';
          });
        }
      },
      onDone: () {
        if (mounted) {
          setState(() {
            _statusText = 'Installing update...';
          });
          Navigator.of(context).pop();
        }
      },
      onError: (err) {
        if (mounted) {
          setState(() {
            _isDownloading = false;
            _statusText = 'Download failed. Please check internet connection.';
          });
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.surface1,
      shape: RoundedRectangleBorder(
        borderRadius: AppRadii.borderLarge,
        side: BorderSide(
          color: AppColors.primarySoft.withValues(alpha: 0.3),
          width: 1.5,
        ),
      ),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.surface2,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.system_update_rounded,
              color: AppColors.primarySoft,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Update Available',
                  style: AppTextStyles.h3.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  'v${AppUpdateService.currentVersion}  ➔  v${widget.updateInfo.latestVersion}',
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.primarySoft,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.updateInfo.formattedSize.isNotEmpty) ...[
            Text(
              'Download Size: ${widget.updateInfo.formattedSize}',
              style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 8),
          ],
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.surface2.withValues(alpha: 0.6),
              borderRadius: AppRadii.borderSmall,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "What's New:",
                  style: AppTextStyles.caption.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  widget.updateInfo.releaseNotes.trim().isEmpty
                      ? '• Performance optimizations and bug fixes.'
                      : widget.updateInfo.releaseNotes,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          if (_isDownloading) ...[
            const SizedBox(height: 16),
            LinearProgressIndicator(
              value: _progress > 0 ? _progress : null,
              backgroundColor: AppColors.surface2,
              valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primarySoft),
              minHeight: 6,
              borderRadius: BorderRadius.circular(3),
            ),
            const SizedBox(height: 8),
            Center(
              child: Text(
                _statusText,
                style: AppTextStyles.caption.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ],
      ),
      actions: [
        if (!_isDownloading) ...[
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              'Later',
              style: AppTextStyles.bodySmall.copyWith(color: AppColors.textMuted),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primarySoft,
              shape: RoundedRectangleBorder(
                borderRadius: AppRadii.borderPill,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            ),
            onPressed: _startUpdate,
            child: Text(
              'Update Now',
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ],
    );
  }
}
