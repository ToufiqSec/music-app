import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../theme/app_radii.dart';
import '../theme/app_spacing.dart';
import '../providers/auth_provider.dart';
import '../providers/audio_provider.dart';
import '../core/services/supabase_service.dart';
import '../core/services/app_update_service.dart';
import '../core/services/audio_cache_service.dart';
import '../core/services/taste_engine.dart';
import '../core/services/mood_recommendation_engine.dart';
import '../widgets/update_dialog.dart';
import 'login_screen.dart';
import 'artist_onboarding_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _isSyncing = false;
  String _cacheSizeDisplay = 'Calculating...';

  @override
  void initState() {
    super.initState();
    _calculateCacheSize();
  }

  Future<void> _calculateCacheSize() async {
    try {
      final sizeMb = await AudioCacheService.getTotalCacheSizeMb();
      if (mounted) {
        setState(() {
          _cacheSizeDisplay = '${sizeMb.toStringAsFixed(1)} MB';
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _cacheSizeDisplay = '0.0 MB';
        });
      }
    }
  }

  Future<void> _handleManualSync() async {
    setState(() => _isSyncing = true);
    try {
      await SupabaseService.syncDownAllUserData();
      if (!mounted) return;
      await context.read<AudioProvider>().reloadUserLibrary();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cloud sync completed! All library data is up to date.'),
          backgroundColor: AppColors.surface2,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Sync error: $e'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSyncing = false);
    }
  }

  void _showEditProfileDialog(BuildContext context, AuthProvider auth) {
    final nameCtrl = TextEditingController(text: auth.displayName);
    final avatarCtrl = TextEditingController(text: auth.avatarUrl);

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: AppColors.surface1,
          shape: const RoundedRectangleBorder(borderRadius: AppRadii.borderLarge),
          title: Text('Edit Profile', style: AppTextStyles.h3),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                style: const TextStyle(color: AppColors.textPrimary),
                decoration: InputDecoration(
                  labelText: 'Display Name',
                  labelStyle: const TextStyle(color: AppColors.textSecondary),
                  enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: AppColors.surface2),
                  ),
                  focusedBorder: const UnderlineInputBorder(
                    borderSide: BorderSide(color: AppColors.primary),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: avatarCtrl,
                style: const TextStyle(color: AppColors.textPrimary),
                decoration: InputDecoration(
                  labelText: 'Avatar Image URL (Optional)',
                  labelStyle: const TextStyle(color: AppColors.textSecondary),
                  enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: AppColors.surface2),
                  ),
                  focusedBorder: const UnderlineInputBorder(
                    borderSide: BorderSide(color: AppColors.primary),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                shape: const RoundedRectangleBorder(borderRadius: AppRadii.borderPill),
              ),
              onPressed: () async {
                Navigator.pop(ctx);
                final updated = await auth.updateProfile(
                  displayName: nameCtrl.text.trim().isEmpty ? auth.displayName : nameCtrl.text.trim(),
                  avatarUrl: avatarCtrl.text.trim().isEmpty ? null : avatarCtrl.text.trim(),
                );
                if (mounted && updated) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Profile updated successfully!'),
                      backgroundColor: AppColors.surface2,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              },
              child: const Text('Save', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  void _showSignOutDialog(BuildContext context, AuthProvider auth) {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: AppColors.surface1,
          shape: const RoundedRectangleBorder(borderRadius: AppRadii.borderLarge),
          title: const Text('Sign Out', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          content: const Text(
            'Are you sure you want to sign out? Your cached offline tracks will remain on this device.',
            style: TextStyle(color: AppColors.textSecondary),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.error,
                shape: const RoundedRectangleBorder(borderRadius: AppRadii.borderPill),
              ),
              onPressed: () async {
                Navigator.pop(ctx);
                await auth.signOut();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Signed out successfully.'),
                      backgroundColor: AppColors.surface2,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              },
              child: const Text('Sign Out', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final audioProvider = context.watch<AudioProvider>();
    final isAuthenticated = authProvider.isAuthenticated;
    final settings = authProvider.settings;

    return Scaffold(
      backgroundColor: AppColors.bgDeep,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.iconIdle, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text('Account & Settings', style: AppTextStyles.screenTitle.copyWith(fontSize: 20)),
        centerTitle: true,
      ),
      body: Stack(
        children: [
          // Background Gradient
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: AppColors.pageGradient,
              ),
            ),
          ),

          // Ambient Glow
          Positioned(
            top: -40,
            left: 0,
            right: 0,
            height: MediaQuery.of(context).size.height * 0.3,
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  center: Alignment.topCenter,
                  radius: 0.8,
                  colors: [
                    AppColors.primarySoft.withValues(alpha: 0.18),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),

          SafeArea(
            child: ListView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.x16, vertical: AppSpacing.x12),
              children: [
                // 1. User Profile Header Card
                _buildProfileHeader(context, authProvider, isAuthenticated),

                const SizedBox(height: 16),

                // 2. Library Stats Row
                _buildStatsRow(context, audioProvider),

                const SizedBox(height: 20),

                // 3. Cloud Sync Section
                if (isAuthenticated) ...[
                  _buildCloudSyncCard(context),
                  const SizedBox(height: 20),
                ],

                // 4. Playback & Streaming Preferences
                _buildSectionHeader('Streaming & Playback Preferences'),
                const SizedBox(height: 10),
                _buildPreferencesCard(context, authProvider, settings),

                const SizedBox(height: 20),

                // 5. Storage & Cache
                _buildSectionHeader('Storage & Offline'),
                const SizedBox(height: 10),
                _buildStorageCard(context),

                const SizedBox(height: 20),

                // 6. App Info & Updates
                _buildSectionHeader('App & Updates'),
                const SizedBox(height: 10),
                _buildAppInfoCard(context),

                const SizedBox(height: 24),

                // 7. Sign Out / Sign In Button
                if (isAuthenticated)
                  Center(
                    child: TextButton.icon(
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.error,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      ),
                      icon: const Icon(Icons.logout_rounded, size: 20),
                      label: const Text('Sign Out', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                      onPressed: () => _showSignOutDialog(context, authProvider),
                    ),
                  )
                else
                  Center(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                        shape: const RoundedRectangleBorder(borderRadius: AppRadii.borderPill),
                      ),
                      icon: const Icon(Icons.login_rounded, size: 20),
                      label: const Text('Sign In or Register', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const LoginScreen()),
                        );
                      },
                    ),
                  ),

                const SizedBox(height: 40),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileHeader(BuildContext context, AuthProvider auth, bool isAuthenticated) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.x16),
      decoration: BoxDecoration(
        color: AppColors.surface1,
        borderRadius: AppRadii.borderLarge,
        border: Border.all(color: AppColors.primarySoft.withValues(alpha: 0.15)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              // Avatar
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: [AppColors.primary, AppColors.sunsetViolet],
                  ),
                  border: Border.all(color: AppColors.primarySoft, width: 2),
                ),
                child: Center(
                  child: auth.avatarUrl.isNotEmpty
                      ? ClipOval(
                          child: Image.network(
                            auth.avatarUrl,
                            width: 60,
                            height: 60,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => const Icon(Icons.person, color: Colors.white, size: 32),
                          ),
                        )
                      : Text(
                          auth.displayName.isNotEmpty ? auth.displayName[0].toUpperCase() : 'M',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 26,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),

              const SizedBox(width: 16),

              // User Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            auth.displayName,
                            style: AppTextStyles.cardTitle.copyWith(fontSize: 18),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        if (isAuthenticated)
                          GestureDetector(
                            onTap: () => _showEditProfileDialog(context, auth),
                            child: const Icon(Icons.edit_outlined, size: 16, color: AppColors.primarySoft),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      auth.email,
                      style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    // Status Badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: isAuthenticated
                            ? AppColors.success.withValues(alpha: 0.15)
                            : AppColors.warning.withValues(alpha: 0.15),
                        borderRadius: AppRadii.borderPill,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isAuthenticated ? AppColors.success : AppColors.warning,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            isAuthenticated ? 'Supabase Synced Member' : 'Guest Mode (Local Vault)',
                            style: TextStyle(
                              color: isAuthenticated ? AppColors.success : AppColors.warning,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          if (!isAuthenticated) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.surface2,
                borderRadius: AppRadii.borderMedium,
              ),
              child: Row(
                children: [
                  const Icon(Icons.cloud_off_rounded, color: AppColors.primarySoft, size: 22),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Sign in to sync your playlists and favorites across all devices with Supabase Cloud.',
                      style: AppTextStyles.caption.copyWith(color: AppColors.textPrimary),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatsRow(BuildContext context, AudioProvider audio) {
    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            icon: Icons.favorite_rounded,
            iconColor: AppColors.sunsetPink,
            count: audio.favoriteIds.length.toString(),
            label: 'Liked Songs',
            onTap: () {
              Navigator.pop(context);
              // Switch to Library tab (Index 3)
            },
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildStatCard(
            icon: Icons.queue_music_rounded,
            iconColor: AppColors.primarySoft,
            count: audio.userPlaylists.length.toString(),
            label: 'Playlists',
            onTap: () {
              Navigator.pop(context);
            },
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildStatCard(
            icon: Icons.history_rounded,
            iconColor: AppColors.warning,
            count: audio.historyTracks.length.toString(),
            label: 'History',
            onTap: () {
              _showHistorySheet(context, audio);
            },
          ),
        ),
      ],
    );
  }

  void _showHistorySheet(BuildContext context, AudioProvider audio) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        final history = audio.historyTracks;
        return Container(
          height: MediaQuery.of(context).size.height * 0.65,
          padding: const EdgeInsets.all(AppSpacing.x16),
          decoration: const BoxDecoration(
            color: AppColors.surface1,
            borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadii.xlarge)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Listening History (${history.length})', style: AppTextStyles.h3),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: AppColors.iconIdle),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Expanded(
                child: history.isEmpty
                    ? Center(
                        child: Text(
                          'No recently played tracks yet.',
                          style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
                        ),
                      )
                    : ListView.builder(
                        itemCount: history.length,
                        itemBuilder: (context, idx) {
                          final track = history[idx];
                          return ListTile(
                            leading: ClipRRect(
                              borderRadius: AppRadii.borderSmall,
                              child: Image.network(
                                track.thumbnailUrl,
                                width: 44,
                                height: 44,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Container(
                                  width: 44,
                                  height: 44,
                                  color: AppColors.surface2,
                                  child: const Icon(Icons.music_note, color: AppColors.primarySoft),
                                ),
                              ),
                            ),
                            title: Text(track.title, style: AppTextStyles.bodyMedium, maxLines: 1, overflow: TextOverflow.ellipsis),
                            subtitle: Text(track.artist, style: AppTextStyles.caption, maxLines: 1, overflow: TextOverflow.ellipsis),
                            onTap: () {
                              Navigator.pop(ctx);
                              audio.playTrack(track, history);
                            },
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required Color iconColor,
    required String count,
    required String label,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
        decoration: BoxDecoration(
          color: AppColors.surface1,
          borderRadius: AppRadii.borderMedium,
          border: Border.all(color: AppColors.surface2),
        ),
        child: Column(
          children: [
            Icon(icon, color: iconColor, size: 22),
            const SizedBox(height: 6),
            Text(
              count,
              style: AppTextStyles.cardTitle.copyWith(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: AppTextStyles.meta.copyWith(color: AppColors.textSecondary, fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCloudSyncCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.x16),
      decoration: BoxDecoration(
        color: AppColors.surface1,
        borderRadius: AppRadii.borderLarge,
        border: Border.all(color: AppColors.surface2),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.primarySoft.withValues(alpha: 0.15),
            ),
            child: const Icon(Icons.cloud_sync_rounded, color: AppColors.primarySoft, size: 26),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Cloud Sync Status', style: AppTextStyles.cardTitle.copyWith(fontSize: 15)),
                const SizedBox(height: 2),
                Text(
                  'Connected to Supabase PostgreSQL',
                  style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          OutlinedButton(
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: AppColors.primarySoft),
              shape: const RoundedRectangleBorder(borderRadius: AppRadii.borderPill),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            ),
            onPressed: _isSyncing ? null : _handleManualSync,
            child: _isSyncing
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primarySoft),
                  )
                : Text(
                    'Sync Now',
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.primarySoft,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Text(
        title,
        style: AppTextStyles.sectionTitle.copyWith(
          fontSize: 14,
          color: AppColors.primarySoft,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildPreferencesCard(BuildContext context, AuthProvider auth, UserSettingsData settings) {
    final audio = context.watch<AudioProvider>();

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface1,
        borderRadius: AppRadii.borderLarge,
        border: Border.all(color: AppColors.surface2),
      ),
      child: Column(
        children: [
          // Favorite Artists & Taste Profile (Issue 4)
          ListTile(
            leading: const Icon(Icons.people_alt_rounded, color: AppColors.primarySoft),
            title: const Text('Favorite Artists & Taste', style: TextStyle(color: AppColors.textPrimary, fontSize: 14)),
            subtitle: Text(
              '${TasteEngine.favoriteArtists.length} Artists Selected',
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
            ),
            trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.iconIdle),
            onTap: () async {
              await Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const ArtistOnboardingScreen(isModal: true)),
              );
              setState(() {});
            },
          ),
          Divider(color: AppColors.surface2, height: 1),

          // Audio Quality
          ListTile(
            leading: const Icon(Icons.high_quality_rounded, color: AppColors.primarySoft),
            title: const Text('Streaming Audio Quality', style: TextStyle(color: AppColors.textPrimary, fontSize: 14)),
            subtitle: Text(
              settings.audioQuality == '320k' ? 'High Lossless (320 kbps)' : 'Standard (160 kbps)',
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
            ),
            trailing: DropdownButton<String>(
              value: settings.audioQuality,
              dropdownColor: AppColors.surface2,
              underline: const SizedBox(),
              icon: const Icon(Icons.arrow_drop_down, color: AppColors.iconIdle),
              style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
              items: const [
                DropdownMenuItem(value: '320k', child: Text('320 kbps')),
                DropdownMenuItem(value: '160k', child: Text('160 kbps')),
              ],
              onChanged: (val) {
                if (val != null) {
                  auth.updateSettings(audioQuality: val);
                }
              },
            ),
          ),
          Divider(color: AppColors.surface2, height: 1),

          // Search Cache Timer (Issue 1 & 3)
          ListTile(
            leading: const Icon(Icons.timer_outlined, color: AppColors.primarySoft),
            title: const Text('Search & Mood Cache Timer', style: TextStyle(color: AppColors.textPrimary, fontSize: 14)),
            subtitle: Text(
              '${settings.searchCacheHours} hours (Fast local repeat & offline)',
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
            ),
            trailing: DropdownButton<int>(
              value: settings.searchCacheHours,
              dropdownColor: AppColors.surface2,
              underline: const SizedBox(),
              icon: const Icon(Icons.arrow_drop_down, color: AppColors.iconIdle),
              style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
              items: const [
                DropdownMenuItem(value: 1, child: Text('1 hour')),
                DropdownMenuItem(value: 6, child: Text('6 hours (Default)')),
                DropdownMenuItem(value: 12, child: Text('12 hours')),
                DropdownMenuItem(value: 24, child: Text('24 hours')),
                DropdownMenuItem(value: 72, child: Text('3 days')),
              ],
              onChanged: (val) {
                if (val != null) {
                  auth.updateSettings(searchCacheHours: val);
                }
              },
            ),
          ),
          Divider(color: AppColors.surface2, height: 1),

          // Autoplay (Issue 8)
          SwitchListTile(
            secondary: const Icon(Icons.all_inclusive_rounded, color: AppColors.primarySoft),
            title: const Text('Autoplay Next Related Track', style: TextStyle(color: AppColors.textPrimary, fontSize: 14)),
            subtitle: const Text('Continuous dynamic audio stream when current track ends', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
            value: audio.autoplayEnabled,
            activeColor: AppColors.primary,
            onChanged: (val) {
              audio.toggleAutoplay();
              auth.updateSettings(autoplay: val);
            },
          ),
          Divider(color: AppColors.surface2, height: 1),

          // Crossfade Duration (Issue 8)
          ListTile(
            leading: const Icon(Icons.graphic_eq_rounded, color: AppColors.primarySoft),
            title: const Text('Audio Crossfade Transition', style: TextStyle(color: AppColors.textPrimary, fontSize: 14)),
            subtitle: Text(
              audio.crossfadeSeconds > 0
                  ? '${audio.crossfadeSeconds.toStringAsFixed(1)}s natural overlap'
                  : 'Disabled (Cut transitions)',
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
            ),
            trailing: DropdownButton<double>(
              value: audio.crossfadeSeconds,
              dropdownColor: AppColors.surface2,
              underline: const SizedBox(),
              icon: const Icon(Icons.arrow_drop_down, color: AppColors.iconIdle),
              style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
              items: const [
                DropdownMenuItem(value: 0.0, child: Text('Off')),
                DropdownMenuItem(value: 1.0, child: Text('1.0s')),
                DropdownMenuItem(value: 2.0, child: Text('2.0s')),
                DropdownMenuItem(value: 3.0, child: Text('3.0s')),
                DropdownMenuItem(value: 4.0, child: Text('4.0s')),
              ],
              onChanged: (val) {
                if (val != null) {
                  audio.setCrossfadeSeconds(val);
                }
              },
            ),
          ),
          Divider(color: AppColors.surface2, height: 1),

          // Lyrics Script
          ListTile(
            leading: const Icon(Icons.lyrics_rounded, color: AppColors.primarySoft),
            title: const Text('Lyrics Preference', style: TextStyle(color: AppColors.textPrimary, fontSize: 14)),
            subtitle: Text(
              settings.preferredLyricsScript == 'roman' ? 'Romanized / English transliteration' : 'Original Native Script',
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
            ),
            trailing: DropdownButton<String>(
              value: settings.preferredLyricsScript,
              dropdownColor: AppColors.surface2,
              underline: const SizedBox(),
              icon: const Icon(Icons.arrow_drop_down, color: AppColors.iconIdle),
              style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
              items: const [
                DropdownMenuItem(value: 'roman', child: Text('Romanized')),
                DropdownMenuItem(value: 'native', child: Text('Native')),
              ],
              onChanged: (val) {
                if (val != null) {
                  auth.updateSettings(lyricsScript: val);
                }
              },
            ),
          ),
          Divider(color: AppColors.surface2, height: 1),

          // Groq AI API Key (Issue 7 Step 2 & 3)
          ListTile(
            leading: const Icon(Icons.auto_awesome_rounded, color: AppColors.primarySoft),
            title: const Text('AI Vibe Companion Key (Groq)', style: TextStyle(color: AppColors.textPrimary, fontSize: 14)),
            subtitle: Text(
              MoodRecommendationEngine.hasGroqKey
                  ? 'Configured • Llama 3.3 70B'
                  : 'Tap to configure Groq API Key',
              style: TextStyle(
                color: MoodRecommendationEngine.hasGroqKey ? AppColors.success : AppColors.textSecondary,
                fontSize: 12,
              ),
            ),
            trailing: const Icon(Icons.edit_rounded, color: AppColors.iconIdle, size: 18),
            onTap: () => _showGroqKeyDialog(context),
          ),
        ],
      ),
    );
  }

  void _showGroqKeyDialog(BuildContext context) {
    final ctrl = TextEditingController(text: MoodRecommendationEngine.groqApiKey);
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: AppColors.surface1,
          shape: const RoundedRectangleBorder(borderRadius: AppRadii.borderLarge),
          title: const Text('Groq AI API Key', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Powers the real-time AI companion in Vibe Hub using Llama 3.3. Key is stored securely on device.',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: ctrl,
                obscureText: true,
                style: const TextStyle(color: AppColors.textPrimary),
                decoration: const InputDecoration(
                  hintText: 'gsk_...',
                  hintStyle: TextStyle(color: AppColors.textMuted),
                  enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: AppColors.surface2)),
                  focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: AppColors.primary)),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                shape: const RoundedRectangleBorder(borderRadius: AppRadii.borderPill),
              ),
              onPressed: () {
                MoodRecommendationEngine.groqApiKey = ctrl.text.trim();
                Navigator.pop(ctx);
                setState(() {});
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Groq AI Key saved successfully!'),
                    backgroundColor: AppColors.surface2,
                    duration: Duration(seconds: 2),
                  ),
                );
              },
              child: const Text('Save', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  Widget _buildStorageCard(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface1,
        borderRadius: AppRadii.borderLarge,
        border: Border.all(color: AppColors.surface2),
      ),
      child: Column(
        children: [
          ListTile(
            leading: const Icon(Icons.disc_full_rounded, color: AppColors.primarySoft),
            title: const Text('Audio Cache & Offline Storage', style: TextStyle(color: AppColors.textPrimary, fontSize: 14)),
            subtitle: Text(
              'Current usage: $_cacheSizeDisplay',
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
            ),
            trailing: TextButton(
              style: TextButton.styleFrom(foregroundColor: AppColors.primarySoft),
              onPressed: () async {
                await AudioCacheService.clearAllCache();
                await _calculateCacheSize();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Audio cache cleared!'),
                      backgroundColor: AppColors.surface2,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              },
              child: const Text('Clear Cache', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppInfoCard(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface1,
        borderRadius: AppRadii.borderLarge,
        border: Border.all(color: AppColors.surface2),
      ),
      child: Column(
        children: [
          ListTile(
            leading: const Icon(Icons.info_outline_rounded, color: AppColors.primarySoft),
            title: const Text('Music App Engine', style: TextStyle(color: AppColors.textPrimary, fontSize: 14)),
            subtitle: Text(
              'Version ${AppUpdateService.currentVersion} • Release Channel',
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
            ),
            trailing: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppColors.primarySoft),
                shape: const RoundedRectangleBorder(borderRadius: AppRadii.borderPill),
              ),
              icon: const Icon(Icons.system_update_rounded, size: 16, color: AppColors.primarySoft),
              label: const Text('Check Updates', style: TextStyle(color: AppColors.primarySoft, fontSize: 12)),
              onPressed: () async {
                final info = await AppUpdateService.checkForUpdate(force: true);
                if (mounted) {
                  if (info != null) {
                    UpdateDialog.show(context, info);
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Music App is up to date!'),
                        backgroundColor: AppColors.surface1,
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  }
                }
              },
            ),
          ),
        ],
      ),
    );
  }
}
