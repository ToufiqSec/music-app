import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../features/music/models/music_models.dart';
import '../providers/audio_provider.dart';
import '../core/services/mood_recommendation_engine.dart';
import '../theme/app_colors.dart';
import '../theme/app_radii.dart';
import '../theme/app_text_styles.dart';
import '../theme/app_shadows.dart';
import '../widgets/generated_cover_art.dart';
import '../widgets/twilight_scene_background.dart';

/// Full-Screen AI Mood & Vibe Recommendation Hub (Issue 7 - Step 1 & 2)
/// Designed strictly in the Twilight Calm design system:
/// Layered landscape, purple-violet glass cards, zero hardcoded songs or fixed lists.
class MoodHubScreen extends StatefulWidget {
  const MoodHubScreen({super.key});

  @override
  State<MoodHubScreen> createState() => _MoodHubScreenState();
}

class _MoodHubScreenState extends State<MoodHubScreen> {
  final TextEditingController _customVibeController = TextEditingController();
  final Set<String> _selectedMoodIds = {'chill'};
  MoodContentStyle _selectedStyle = MoodContentStyle.all;
  bool _showAllMoods = false;

  bool _isGenerating = false;
  List<YoutubeTrack> _recommendedTracks = [];
  String _companionMessage = '';
  String _statusMessage = '';

  late final MoodRecommendationEngine _engine;

  @override
  void initState() {
    super.initState();
    final audio = context.read<AudioProvider>();
    _engine = MoodRecommendationEngine(audio.musicService);
  }

  @override
  void dispose() {
    _customVibeController.dispose();
    super.dispose();
  }

  Future<void> _generateMix() async {
    HapticFeedback.mediumImpact();
    setState(() {
      _isGenerating = true;
      _statusMessage = 'Tuning into your frequency...';
    });

    try {
      final mixResult = await _engine.generateRecommendations(
        selectedMoodIds: _selectedMoodIds,
        customDescription: _customVibeController.text,
        style: _selectedStyle,
      );

      if (mounted) {
        setState(() {
          _recommendedTracks = mixResult.tracks;
          _companionMessage = mixResult.companionMessage;
          _isGenerating = false;
          _statusMessage = mixResult.tracks.isEmpty ? 'No tracks found for this vibe. Try a different mood!' : '';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isGenerating = false;
          _statusMessage = 'Connection hiccup. Tap generate again to retry.';
        });
      }
    }
  }

  void _playAllMix(AudioProvider audio) {
    if (_recommendedTracks.isEmpty) return;
    HapticFeedback.lightImpact();
    audio.playTrack(_recommendedTracks.first, _recommendedTracks);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: AppColors.surface1,
        content: Text(
          'Playing ${_recommendedTracks.length} tracks from your Vibe Mix',
          style: AppTextStyles.bodySmall.copyWith(color: AppColors.primarySoft),
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: AppRadii.borderMedium),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final audio = context.read<AudioProvider>();

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          // Background Landscape
          const Positioned.fill(
            child: TwilightSceneBackground(mode: TwilightSceneMode.header),
          ),

          SafeArea(
            child: ListView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.only(
                left: 16,
                right: 16,
                top: 16,
                bottom: 160,
              ),
              children: [
                // 1. Header with Glowing AI Companion Avatar
                _buildHeader(),
                const SizedBox(height: 20),

                // 2. Multi-Select Mixable Mood Grid
                _buildMoodChipsSection(),
                const SizedBox(height: 20),

                // 3. Custom Vibe Prompt Input
                _buildCustomPromptInput(),
                const SizedBox(height: 16),

                // 4. Content Style Selector (Music, Stories, Podcasts, Ambient)
                _buildStyleSelector(),
                const SizedBox(height: 20),

                // 5. Generate Action Button
                _buildGenerateButton(),
                const SizedBox(height: 24),

                // 6. Generated Mix Results or Shimmer
                if (_isGenerating)
                  _buildLoadingShimmer()
                else if (_recommendedTracks.isNotEmpty)
                  _buildMixResults(audio)
                else if (_statusMessage.isNotEmpty)
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Text(
                        _statusMessage,
                        style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textMuted),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        // Glowing Aura Icon
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              colors: [AppColors.primary, AppColors.primarySoft],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.5),
                blurRadius: 16,
                spreadRadius: 2,
              ),
            ],
          ),
          child: const Icon(
            Icons.auto_awesome_rounded,
            color: Colors.white,
            size: 24,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Vibe Recommendation Hub',
                style: AppTextStyles.heroTitle.copyWith(fontSize: 20),
              ),
              const SizedBox(height: 2),
              Text(
                'How are you feeling right now?',
                style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMoodChipsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Select Moods (Mix & Match)',
              style: AppTextStyles.sectionTitle.copyWith(fontSize: 15),
            ),
            Text(
              '${_selectedMoodIds.length} picked',
              style: AppTextStyles.caption.copyWith(color: AppColors.primarySoft),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: (_showAllMoods
                  ? MoodRecommendationEngine.availableMoods
                  : MoodRecommendationEngine.availableMoods.take(6))
              .map((mood) {
            final isSelected = _selectedMoodIds.contains(mood.id);
            return GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                setState(() {
                  if (isSelected) {
                    if (_selectedMoodIds.length > 1) {
                      _selectedMoodIds.remove(mood.id);
                    }
                  } else {
                    _selectedMoodIds.add(mood.id);
                  }
                });
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  gradient: isSelected
                      ? const LinearGradient(
                          colors: [AppColors.primary, AppColors.primarySoft],
                        )
                      : null,
                  color: isSelected ? null : AppColors.surface1,
                  borderRadius: AppRadii.borderPill,
                  border: Border.all(
                    color: isSelected ? AppColors.primarySoft : AppColors.surface2,
                    width: 1.2,
                  ),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: AppColors.primary.withValues(alpha: 0.35),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                child: Text(
                  mood.label,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: isSelected ? Colors.white : AppColors.textPrimary,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: () {
            HapticFeedback.selectionClick();
            setState(() => _showAllMoods = !_showAllMoods);
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _showAllMoods ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                  size: 18,
                  color: AppColors.primarySoft,
                ),
                const SizedBox(width: 4),
                Text(
                  _showAllMoods
                      ? 'Show Fewer Vibes'
                      : '+ More Vibes (${MoodRecommendationEngine.availableMoods.length - 6} more)',
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.primarySoft,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCustomPromptInput() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.surface1,
        borderRadius: AppRadii.borderLarge,
        border: Border.all(color: AppColors.surface2),
      ),
      child: TextField(
        controller: _customVibeController,
        style: AppTextStyles.bodyMedium,
        decoration: InputDecoration(
          border: InputBorder.none,
          hintText: 'Or describe your vibe in words (e.g. rainy train ride)',
          hintStyle: AppTextStyles.caption.copyWith(color: AppColors.textMuted),
          icon: const Icon(Icons.edit_note_rounded, color: AppColors.primarySoft),
        ),
      ),
    );
  }

  Widget _buildStyleSelector() {
    return SizedBox(
      height: 38,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: MoodContentStyle.values.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, idx) {
          final s = MoodContentStyle.values[idx];
          final isSelected = s == _selectedStyle;
          return GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              setState(() => _selectedStyle = s);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: isSelected ? AppColors.primarySoft.withValues(alpha: 0.25) : AppColors.surface1,
                borderRadius: AppRadii.borderPill,
                border: Border.all(
                  color: isSelected ? AppColors.primarySoft : AppColors.surface2,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    s.icon as IconData,
                    size: 14,
                    color: isSelected ? AppColors.primarySoft : AppColors.textMuted,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    s.label,
                    style: AppTextStyles.caption.copyWith(
                      color: isSelected ? Colors.white : AppColors.textSecondary,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildGenerateButton() {
    return Container(
      height: 52,
      decoration: BoxDecoration(
        borderRadius: AppRadii.borderLarge,
        gradient: const LinearGradient(
          colors: [AppColors.primary, AppColors.primarySoft],
        ),
        boxShadow: const [AppShadows.shadowSoft],
      ),
      child: InkWell(
        borderRadius: AppRadii.borderLarge,
        onTap: _isGenerating ? null : _generateMix,
        child: Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 20),
              const SizedBox(width: 10),
              Text(
                _isGenerating ? 'Synthesizing Mix...' : 'Generate My Vibe Mix',
                style: AppTextStyles.button.copyWith(fontSize: 16),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingShimmer() {
    return Column(
      children: List.generate(4, (_) {
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          height: 64,
          decoration: BoxDecoration(
            color: AppColors.surface1.withValues(alpha: 0.5),
            borderRadius: AppRadii.borderMedium,
          ),
        );
      }),
    );
  }

  Widget _buildMixResults(AudioProvider audio) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_companionMessage.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(bottom: 14),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.surface1.withValues(alpha: 0.8),
              borderRadius: AppRadii.borderMedium,
              border: Border.all(
                color: AppColors.primarySoft.withValues(alpha: 0.35),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.auto_awesome_rounded, color: AppColors.primarySoft, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _companionMessage,
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.textPrimary,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              ],
            ),
          ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Your Personalized Vibe Mix (${_recommendedTracks.length})',
              style: AppTextStyles.sectionTitle.copyWith(fontSize: 16),
            ),
            TextButton.icon(
              onPressed: () => _playAllMix(audio),
              icon: const Icon(Icons.play_circle_fill_rounded, color: AppColors.primarySoft, size: 20),
              label: Text(
                'Play All',
                style: AppTextStyles.caption.copyWith(
                  color: AppColors.primarySoft,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ..._recommendedTracks.map((track) {
          final type = AudioTypeDetector.detect(track.title, track.artist, track.durationSeconds);
          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              color: AppColors.surface1,
              borderRadius: AppRadii.borderMedium,
              border: Border.all(color: AppColors.surface2),
            ),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              leading: ClipRRect(
                borderRadius: AppRadii.borderSmall,
                child: (track.thumbnailUrl.isNotEmpty &&
                        !track.thumbnailUrl.contains('hqdefault') &&
                        !track.thumbnailUrl.contains('mqdefault'))
                    ? CachedNetworkImage(
                        imageUrl: track.thumbnailUrl,
                        width: 44,
                        height: 44,
                        fit: BoxFit.cover,
                        errorWidget: (_, __, ___) => GeneratedCoverArt(
                          title: track.title,
                          artist: track.artist,
                          thumbnailUrl: track.thumbnailUrl,
                          durationSeconds: track.durationSeconds,
                          size: 44,
                          borderRadius: AppRadii.borderSmall,
                        ),
                      )
                    : GeneratedCoverArt(
                        title: track.title,
                        artist: track.artist,
                        thumbnailUrl: track.thumbnailUrl,
                        durationSeconds: track.durationSeconds,
                        size: 44,
                        borderRadius: AppRadii.borderSmall,
                      ),
              ),
              title: Text(
                track.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w600),
              ),
              subtitle: Row(
                children: [
                  if (type != AudioContentType.song) ...[
                    Container(
                      margin: const EdgeInsets.only(right: 6),
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(
                        color: AppColors.primarySoft.withValues(alpha: 0.2),
                        borderRadius: AppRadii.borderSmall,
                      ),
                      child: Text(
                        AudioTypeDetector.getBadgeText(type),
                        style: TextStyle(
                          fontSize: 8.5,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primarySoft,
                        ),
                      ),
                    ),
                  ],
                  Expanded(
                    child: Text(
                      track.artist,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
                    ),
                  ),
                ],
              ),
              trailing: IconButton(
                icon: const Icon(Icons.play_arrow_rounded, color: AppColors.primarySoft),
                onPressed: () => audio.playTrack(track, _recommendedTracks),
              ),
            ),
          );
        }),
      ],
    );
  }
}
