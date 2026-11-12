import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/services/app_update_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_radii.dart';
import '../theme/app_text_styles.dart';

enum _DialogPhase { notes, downloading, permissionNeeded, readyToInstall, failed }

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

class _UpdateDialogState extends State<UpdateDialog> with WidgetsBindingObserver {
  _DialogPhase _phase = _DialogPhase.notes;
  DownloadProgressState? _progressState;
  StreamSubscription<DownloadProgressState>? _subscription;
  String? _downloadedFilePath;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _subscription?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // When returning from Android Settings screen, check if permission was granted
    if (state == AppLifecycleState.resumed && _phase == _DialogPhase.permissionNeeded) {
      _checkPermissionAndProceed();
    }
  }

  Future<void> _checkPermissionAndProceed() async {
    final granted = await AppUpdateService.canRequestPackageInstalls();
    if (granted && mounted) {
      setState(() => _phase = _DialogPhase.readyToInstall);
      if (_downloadedFilePath != null) {
        _triggerInstall(_downloadedFilePath!);
      }
    }
  }

  void _startUpdate() {
    HapticFeedback.mediumImpact();
    setState(() {
      _phase = _DialogPhase.downloading;
      _errorMessage = '';
    });

    _subscription?.cancel();
    _subscription = AppUpdateService.startDownload(widget.updateInfo).listen(
      (progress) {
        if (!mounted) return;
        setState(() {
          _progressState = progress;
          if (progress.status == 'completed' && progress.filePath != null) {
            _downloadedFilePath = progress.filePath;
            _onDownloadComplete(progress.filePath!);
          } else if (progress.status == 'failed') {
            _phase = _DialogPhase.failed;
            _errorMessage = progress.errorMessage ?? 'Download could not complete. Tap Retry to resume.';
          }
        });
      },
      onError: (_) {
        if (!mounted) return;
        setState(() {
          _phase = _DialogPhase.failed;
          _errorMessage = 'Download interrupted. Please check your network and tap Retry.';
        });
      },
    );
  }

  Future<void> _onDownloadComplete(String filePath) async {
    final canInstall = await AppUpdateService.canRequestPackageInstalls();
    if (!mounted) return;

    if (!canInstall) {
      setState(() => _phase = _DialogPhase.permissionNeeded);
    } else {
      setState(() => _phase = _DialogPhase.readyToInstall);
      _triggerInstall(filePath);
    }
  }

  Future<void> _triggerInstall(String filePath) async {
    HapticFeedback.mediumImpact();
    final ok = await AppUpdateService.installApk(filePath);
    if (!ok && mounted) {
      setState(() {
        _phase = _DialogPhase.readyToInstall;
        _errorMessage = 'Could not open package installer automatically. Tap Install below.';
      });
    }
  }

  void _cancelDownload() {
    HapticFeedback.lightImpact();
    AppUpdateService.cancelActiveDownload();
    _subscription?.cancel();
    setState(() {
      _phase = _DialogPhase.notes;
      _progressState = null;
    });
  }

  void _onLater() {
    HapticFeedback.lightImpact();
    AppUpdateService.snoozeVersion(widget.updateInfo.latestVersion);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _phase == _DialogPhase.notes || _phase == _DialogPhase.downloading,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop && _phase == _DialogPhase.notes) {
          AppUpdateService.snoozeVersion(widget.updateInfo.latestVersion);
        }
        // If downloading, back dismisses the UI popup only; download continues uninterrupted in Android DownloadManager!
      },
      child: Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.surface1,
            borderRadius: AppRadii.borderLarge,
            border: Border.all(
              color: AppColors.primarySoft.withValues(alpha: 0.35),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.primarySoft.withValues(alpha: 0.18),
                blurRadius: 32,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(22.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(),
                const SizedBox(height: 18),
                _buildBody(),
                const SizedBox(height: 20),
                _buildActionButtons(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: AppColors.surface2,
            shape: BoxShape.circle,
            border: Border.all(
              color: AppColors.primarySoft.withValues(alpha: 0.4),
              width: 1.5,
            ),
          ),
          child: const Center(
            child: Icon(
              Icons.system_update_rounded,
              color: AppColors.primarySoft,
              size: 26,
            ),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'New Update Available',
                style: AppTextStyles.h3.copyWith(
                  fontWeight: FontWeight.bold,
                  fontSize: 19,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 3),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.surface2,
                      borderRadius: AppRadii.borderSmall,
                    ),
                    child: Text(
                      'v${widget.updateInfo.currentVersion}',
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w600,
                        fontSize: 11,
                      ),
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 6.0),
                    child: Icon(
                      Icons.arrow_forward_rounded,
                      size: 14,
                      color: AppColors.primarySoft,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.primarySoft.withValues(alpha: 0.2),
                      borderRadius: AppRadii.borderSmall,
                      border: Border.all(
                        color: AppColors.primarySoft.withValues(alpha: 0.4),
                      ),
                    ),
                    child: Text(
                      'v${widget.updateInfo.latestVersion}',
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.primarySoft,
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBody() {
    switch (_phase) {
      case _DialogPhase.notes:
        return _buildNotesView();
      case _DialogPhase.downloading:
        return _buildDownloadingView();
      case _DialogPhase.permissionNeeded:
        return _buildPermissionView();
      case _DialogPhase.readyToInstall:
        return _buildReadyToInstallView();
      case _DialogPhase.failed:
        return _buildFailedView();
    }
  }

  Widget _buildNotesView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.updateInfo.formattedSize.isNotEmpty) ...[
          Row(
            children: [
              const Icon(Icons.download_rounded, size: 16, color: AppColors.textSecondary),
              const SizedBox(width: 6),
              Text(
                'Download Size: ${widget.updateInfo.formattedSize}',
                style: AppTextStyles.caption.copyWith(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
        ],
        ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 200),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.surface2.withValues(alpha: 0.6),
              borderRadius: AppRadii.borderMedium,
              border: Border.all(color: AppColors.surface2),
            ),
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "What's New in This Release:",
                    style: AppTextStyles.bodySmall.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.updateInfo.releaseNotes,
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.textSecondary,
                      height: 1.45,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDownloadingView() {
    final progress = _progressState?.progress ?? 0.0;
    final progressLabel = _progressState?.formattedProgress ?? 'Connecting to GitHub...';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Downloading APK...',
              style: AppTextStyles.bodyMedium.copyWith(
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            Text(
              '${(progress * 100).toInt()}%',
              style: AppTextStyles.caption.copyWith(
                color: AppColors.primarySoft,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: progress > 0 ? progress : null,
            backgroundColor: AppColors.surface2,
            valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primarySoft),
            minHeight: 8,
          ),
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                progressLabel,
                style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary, fontSize: 11),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            GestureDetector(
              onTap: _cancelDownload,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.surface2,
                  borderRadius: AppRadii.borderPill,
                ),
                child: Text(
                  'Cancel',
                  style: AppTextStyles.caption.copyWith(
                    color: const Color(0xFFE53935),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppColors.surface2.withValues(alpha: 0.5),
            borderRadius: AppRadii.borderSmall,
          ),
          child: Row(
            children: [
              const Icon(Icons.info_outline_rounded, size: 16, color: AppColors.primarySoft),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Download continues in background if you leave this screen.',
                  style: AppTextStyles.caption.copyWith(color: AppColors.textMuted, fontSize: 10.5),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPermissionView() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface2.withValues(alpha: 0.7),
        borderRadius: AppRadii.borderMedium,
        border: Border.all(color: AppColors.primarySoft.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.security_rounded, color: AppColors.primarySoft, size: 20),
              const SizedBox(width: 8),
              Text(
                'Permission Required',
                style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'To install updates inside the app, Android requires you to allow "Install unknown apps" for Music App.\n\nTap "Open Settings" below, enable the switch, then return here to complete installation.',
            style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary, height: 1.4),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primarySoft,
                shape: RoundedRectangleBorder(borderRadius: AppRadii.borderPill),
              ),
              icon: const Icon(Icons.settings_rounded, size: 18),
              label: const Text('Open Settings', style: TextStyle(fontWeight: FontWeight.bold)),
              onPressed: () {
                AppUpdateService.openInstallPermissionSettings();
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReadyToInstallView() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface2.withValues(alpha: 0.7),
        borderRadius: AppRadii.borderMedium,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: Color(0xFF4CAF50), size: 22),
              const SizedBox(width: 8),
              Text(
                'Download Complete & Verified',
                style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'The new APK is ready to replace the existing app without losing your downloaded songs or settings.',
            style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
          ),
          if (_errorMessage.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(_errorMessage, style: AppTextStyles.caption.copyWith(color: const Color(0xFFE53935))),
          ],
        ],
      ),
    );
  }

  Widget _buildFailedView() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface2.withValues(alpha: 0.7),
        borderRadius: AppRadii.borderMedium,
        border: Border.all(color: const Color(0xFFE53935).withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.error_outline_rounded, color: Color(0xFFE53935), size: 22),
              const SizedBox(width: 8),
              Text(
                'Download Interrupted',
                style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            _errorMessage,
            style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    switch (_phase) {
      case _DialogPhase.notes:
        return Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            TextButton(
              onPressed: _onLater,
              child: Text(
                'Later',
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.textMuted,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(width: 12),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primarySoft,
                shape: RoundedRectangleBorder(borderRadius: AppRadii.borderPill),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
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
        );

      case _DialogPhase.downloading:
        return const SizedBox.shrink();

      case _DialogPhase.permissionNeeded:
        return Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Close', style: AppTextStyles.bodySmall.copyWith(color: AppColors.textMuted)),
            ),
          ],
        );

      case _DialogPhase.readyToInstall:
        return Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Later', style: AppTextStyles.bodySmall.copyWith(color: AppColors.textMuted)),
            ),
            const SizedBox(width: 12),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primarySoft,
                shape: RoundedRectangleBorder(borderRadius: AppRadii.borderPill),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
              icon: const Icon(Icons.install_mobile_rounded, size: 18),
              label: Text(
                'Install Now',
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.bold,
                ),
              ),
              onPressed: () {
                if (_downloadedFilePath != null) {
                  _triggerInstall(_downloadedFilePath!);
                }
              },
            ),
          ],
        );

      case _DialogPhase.failed:
        return Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Dismiss', style: AppTextStyles.bodySmall.copyWith(color: AppColors.textMuted)),
            ),
            const SizedBox(width: 12),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primarySoft,
                shape: RoundedRectangleBorder(borderRadius: AppRadii.borderPill),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              ),
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: Text(
                'Retry',
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.bold,
                ),
              ),
              onPressed: _startUpdate,
            ),
          ],
        );
    }
  }
}
