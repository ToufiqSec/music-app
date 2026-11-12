import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../core/services/taste_engine.dart';
import '../providers/audio_provider.dart';
import '../widgets/twilight_scene_background.dart';
import '../theme/app_colors.dart';
import '../theme/app_radii.dart';
import '../theme/app_text_styles.dart';

class ArtistOnboardingScreen extends StatefulWidget {
  final bool isModal;

  const ArtistOnboardingScreen({super.key, this.isModal = false});

  @override
  State<ArtistOnboardingScreen> createState() => _ArtistOnboardingScreenState();
}

class _ArtistOnboardingScreenState extends State<ArtistOnboardingScreen> {
  final TextEditingController _searchCtrl = TextEditingController();
  final Set<String> _selectedArtistNames = {};
  final Map<String, ArtistProfile> _selectedArtistProfiles = {};

  List<ArtistProfile> _artistPool = [];
  bool _isLoading = true;
  String _activeLanguage = 'All';
  String _searchFilter = '';

  final List<String> _languages = ['All', 'English', 'Hindi', 'Bengali'];

  @override
  void initState() {
    super.initState();
    _loadInitialTaste();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadInitialTaste() async {
    await TasteEngine.init();
    for (final a in TasteEngine.favoriteArtists) {
      _selectedArtistNames.add(a.name.toLowerCase());
      _selectedArtistProfiles[a.name.toLowerCase()] = a;
    }

    final audio = context.read<AudioProvider>();
    final pool = await TasteEngine.fetchPopularArtistsPool(audio.musicService, language: 'All');
    if (mounted) {
      setState(() {
        _artistPool = pool;
        _isLoading = false;
      });
    }
  }

  void _toggleArtist(ArtistProfile artist) {
    HapticFeedback.selectionClick();
    setState(() {
      final key = artist.name.toLowerCase();
      if (_selectedArtistNames.contains(key)) {
        _selectedArtistNames.remove(key);
        _selectedArtistProfiles.remove(key);
      } else {
        _selectedArtistNames.add(key);
        _selectedArtistProfiles[key] = artist;
      }
    });
  }

  Future<void> _handleSave() async {
    HapticFeedback.mediumImpact();
    final chosenList = _selectedArtistProfiles.values.toList();
    await TasteEngine.setFavoriteArtists(chosenList);

    if (!mounted) return;
    Navigator.of(context).pop(true);
  }

  List<ArtistProfile> get _filteredArtists {
    return _artistPool.where((a) {
      final matchesLang = (_activeLanguage == 'All') ||
          (a.language.toLowerCase() == _activeLanguage.toLowerCase());
      final matchesSearch = _searchFilter.isEmpty ||
          a.name.toLowerCase().contains(_searchFilter.toLowerCase());
      return matchesLang && matchesSearch;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgDeep,
      body: Stack(
        children: [
          // Background Twilight Scene
          const Positioned.fill(
            child: TwilightSceneBackground(mode: TwilightSceneMode.header),
          ),

          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Top Action Bar
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      if (widget.isModal)
                        IconButton(
                          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.iconIdle, size: 20),
                          onPressed: () => Navigator.of(context).pop(false),
                        )
                      else
                        const SizedBox(width: 40),
                      Text(
                        'Artist Preferences',
                        style: AppTextStyles.screenTitle.copyWith(fontSize: 18),
                      ),
                      TextButton(
                        onPressed: _selectedArtistNames.isNotEmpty ? _handleSave : () => Navigator.of(context).pop(false),
                        child: Text(
                          _selectedArtistNames.isNotEmpty ? 'Save' : 'Skip',
                          style: TextStyle(
                            color: _selectedArtistNames.isNotEmpty ? AppColors.primarySoft : AppColors.textMuted,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Title & Instructions
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 6),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Pick Your Favorite Artists',
                        style: AppTextStyles.displayTitle.copyWith(fontSize: 24),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'We\'ll tailor your personal recommendations, home discovery, and search ranking to your taste.',
                        style: AppTextStyles.subtitle.copyWith(color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 12),

                // Search Bar
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppColors.surface1,
                      borderRadius: AppRadii.borderPill,
                      border: Border.all(color: AppColors.surface2),
                    ),
                    child: TextField(
                      controller: _searchCtrl,
                      onChanged: (val) => setState(() => _searchFilter = val.trim()),
                      style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
                      decoration: InputDecoration(
                        hintText: 'Search artist by name...',
                        hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 14),
                        prefixIcon: const Icon(Icons.search_rounded, color: AppColors.iconIdle, size: 20),
                        suffixIcon: _searchFilter.isNotEmpty
                            ? GestureDetector(
                                onTap: () {
                                  _searchCtrl.clear();
                                  setState(() => _searchFilter = '');
                                },
                                child: const Icon(Icons.close_rounded, color: AppColors.iconIdle, size: 18),
                              )
                            : null,
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 12),

                // Language Filter Tabs
                SizedBox(
                  height: 38,
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    scrollDirection: Axis.horizontal,
                    itemCount: _languages.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (context, idx) {
                      final lang = _languages[idx];
                      final isSelected = lang == _activeLanguage;
                      return GestureDetector(
                        onTap: () => setState(() => _activeLanguage = lang),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: isSelected ? AppColors.primarySoft : AppColors.surface1,
                            borderRadius: AppRadii.borderPill,
                            border: Border.all(
                              color: isSelected ? AppColors.primarySoft : AppColors.surface2,
                            ),
                          ),
                          child: Text(
                            lang,
                            style: TextStyle(
                              color: isSelected ? Colors.white : AppColors.textSecondary,
                              fontSize: 13,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),

                const SizedBox(height: 16),

                // Artists Grid
                Expanded(
                  child: _isLoading
                      ? const Center(
                          child: CircularProgressIndicator(color: AppColors.primarySoft),
                        )
                      : _filteredArtists.isEmpty
                          ? Center(
                              child: Text(
                                'No artists matching "$_searchFilter"',
                                style: const TextStyle(color: AppColors.textMuted),
                              ),
                            )
                          : GridView.builder(
                              physics: const BouncingScrollPhysics(),
                              padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
                              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 3,
                                crossAxisSpacing: 14,
                                mainAxisSpacing: 16,
                                childAspectRatio: 0.82,
                              ),
                              itemCount: _filteredArtists.length,
                              itemBuilder: (context, index) {
                                final artist = _filteredArtists[index];
                                final isSelected = _selectedArtistNames.contains(artist.name.toLowerCase());

                                return GestureDetector(
                                  onTap: () => _toggleArtist(artist),
                                  child: Column(
                                    children: [
                                      Stack(
                                        alignment: Alignment.center,
                                        children: [
                                          AnimatedContainer(
                                            duration: const Duration(milliseconds: 220),
                                            width: 86,
                                            height: 86,
                                            decoration: BoxDecoration(
                                              shape: BoxShape.circle,
                                              border: Border.all(
                                                color: isSelected ? AppColors.primary : Colors.transparent,
                                                width: 3,
                                              ),
                                              boxShadow: isSelected
                                                  ? [
                                                      BoxShadow(
                                                        color: AppColors.primary.withValues(alpha: 0.45),
                                                        blurRadius: 12,
                                                        spreadRadius: 2,
                                                      ),
                                                    ]
                                                  : null,
                                            ),
                                            child: ClipOval(
                                              child: artist.imageUrl.isNotEmpty
                                                  ? CachedNetworkImage(
                                                      imageUrl: artist.imageUrl,
                                                      fit: BoxFit.cover,
                                                      errorWidget: (_, __, ___) => _buildFallbackAvatar(artist.name),
                                                    )
                                                  : _buildFallbackAvatar(artist.name),
                                            ),
                                          ),

                                          // Selected Checkmark Badge
                                          if (isSelected)
                                            Positioned(
                                              bottom: 2,
                                              right: 2,
                                              child: Container(
                                                padding: const EdgeInsets.all(4),
                                                decoration: const BoxDecoration(
                                                  shape: BoxShape.circle,
                                                  color: AppColors.primary,
                                                ),
                                                child: const Icon(
                                                  Icons.check_rounded,
                                                  size: 14,
                                                  color: Colors.white,
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        artist.name,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          color: isSelected ? AppColors.primarySoft : AppColors.textPrimary,
                                          fontSize: 12,
                                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                ),
              ],
            ),
          ),

          // Floating Bottom Save Pill Button
          if (_selectedArtistNames.isNotEmpty)
            Positioned(
              bottom: 24,
              left: 24,
              right: 24,
              child: GestureDetector(
                onTap: _handleSave,
                child: Container(
                  height: 52,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppColors.primary, AppColors.primarySoft],
                    ),
                    borderRadius: AppRadii.borderPill,
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.4),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Text(
                      'Done (${_selectedArtistNames.length} Selected) • Start Listening',
                      style: AppTextStyles.buttonLabel.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildFallbackAvatar(String name) {
    return Container(
      color: AppColors.surface2,
      child: Center(
        child: Text(
          name.isNotEmpty ? name[0].toUpperCase() : 'A',
          style: const TextStyle(
            color: AppColors.primarySoft,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
