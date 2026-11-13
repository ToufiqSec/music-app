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
  String _activeLanguage = 'All';
  String _searchFilter = '';
  bool _isSearchingLive = false;

  final List<String> _languages = ['All', 'Hindi', 'Bengali', 'Punjabi', 'English'];

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
      if (TasteEngine.isBlockedChannelOrLabel(a.name)) continue;
      _selectedArtistNames.add(a.name.toLowerCase());
      _selectedArtistProfiles[a.name.toLowerCase()] = a;
    }

    // Pre-populate with verified default catalog immediately
    _artistPool = List.from(TasteEngine.defaultArtistCatalog);

    // Also include any user-added favorite artists not in the default catalog
    for (final a in TasteEngine.favoriteArtists) {
      if (TasteEngine.isBlockedChannelOrLabel(a.name)) continue;
      if (!_artistPool.any((p) => p.name.toLowerCase() == a.name.toLowerCase())) {
        _artistPool.insert(0, a);
      }
    }

    if (mounted) {
      setState(() {});
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

  Future<void> _handleCustomAddArtist() async {
    final query = _searchFilter.trim();
    if (query.isEmpty) return;

    if (TasteEngine.isBlockedChannelOrLabel(query)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter an artist name rather than a channel or label.'),
          backgroundColor: AppColors.surface2,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _isSearchingLive = true);
    HapticFeedback.lightImpact();

    final audio = context.read<AudioProvider>();
    final customArtist = await TasteEngine.searchArtistLive(audio.musicService, query);

    if (mounted && customArtist != null) {
      setState(() {
        _isSearchingLive = false;
        if (!_artistPool.any((a) => a.name.toLowerCase() == customArtist.name.toLowerCase())) {
          _artistPool.insert(0, customArtist);
        }
        _selectedArtistNames.add(customArtist.name.toLowerCase());
        _selectedArtistProfiles[customArtist.name.toLowerCase()] = customArtist;
        _searchCtrl.clear();
        _searchFilter = '';
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Added "${customArtist.name}" to your favorites!'),
          backgroundColor: AppColors.surface2,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
    } else {
      if (mounted) setState(() => _isSearchingLive = false);
    }
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
                      if (widget.isModal || Navigator.of(context).canPop())
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
                        onPressed: _selectedArtistNames.isNotEmpty
                            ? _handleSave
                            : () => Navigator.of(context).pop(false),
                        child: Text(
                          _selectedArtistNames.isNotEmpty
                              ? 'Done (${_selectedArtistNames.length})'
                              : 'Skip',
                          style: TextStyle(
                            color: _selectedArtistNames.isNotEmpty
                                ? AppColors.primarySoft
                                : AppColors.textMuted,
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Title & Instructions
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Pick Your Favorite Artists',
                        style: AppTextStyles.displayTitle.copyWith(fontSize: 22),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Your Home Feed, mixes, and recommendations will be personalized to your selection.',
                        style: AppTextStyles.subtitle.copyWith(
                          color: AppColors.textSecondary,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 10),

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
                        hintText: 'Search or add any artist...',
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

                // Live Search / Add Artist Banner if typing something not in list
                if (_searchFilter.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                    child: InkWell(
                      borderRadius: AppRadii.borderMedium,
                      onTap: _isSearchingLive ? null : _handleCustomAddArtist,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: AppColors.surface2.withValues(alpha: 0.8),
                          borderRadius: AppRadii.borderMedium,
                          border: Border.all(
                            color: AppColors.primarySoft.withValues(alpha: 0.4),
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.add_circle_outline_rounded, color: AppColors.primarySoft, size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _isSearchingLive
                                    ? 'Finding "$_searchFilter" online...'
                                    : 'Add "$_searchFilter" as favorite artist',
                                style: const TextStyle(
                                  color: AppColors.textPrimary,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                            if (_isSearchingLive)
                              const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primarySoft),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),

                const SizedBox(height: 8),

                // Language Filter Tabs
                SizedBox(
                  height: 36,
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

                const SizedBox(height: 14),

                // Artists Grid
                Expanded(
                  child: GridView.builder(
                    padding: const EdgeInsets.only(left: 20, right: 20, bottom: 40),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      mainAxisSpacing: 16,
                      crossAxisSpacing: 12,
                      childAspectRatio: 0.76,
                    ),
                    itemCount: _filteredArtists.length,
                    itemBuilder: (context, idx) {
                      final artist = _filteredArtists[idx];
                      final isSelected = _selectedArtistNames.contains(artist.name.toLowerCase());

                      return GestureDetector(
                        onTap: () => _toggleArtist(artist),
                        child: Column(
                          children: [
                            Stack(
                              clipBehavior: Clip.none,
                              children: [
                                AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  width: 86,
                                  height: 86,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: isSelected
                                          ? AppColors.primarySoft
                                          : Colors.transparent,
                                      width: 2.5,
                                    ),
                                    boxShadow: isSelected
                                        ? [
                                            BoxShadow(
                                              color: AppColors.primarySoft.withValues(alpha: 0.45),
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
                                            placeholder: (_, __) => _buildInitialsGradient(artist.name),
                                            errorWidget: (_, __, ___) => _buildInitialsGradient(artist.name),
                                          )
                                        : _buildInitialsGradient(artist.name),
                                  ),
                                ),

                                // Checkmark Badge when Selected
                                if (isSelected)
                                  Positioned(
                                    right: 0,
                                    bottom: 0,
                                    child: Container(
                                      padding: const EdgeInsets.all(4),
                                      decoration: const BoxDecoration(
                                        color: AppColors.primarySoft,
                                        shape: BoxShape.circle,
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
                            const SizedBox(height: 6),
                            Text(
                              artist.name,
                              maxLines: 2,
                              textAlign: TextAlign.center,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: isSelected ? Colors.white : AppColors.textPrimary,
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                fontSize: 12.5,
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
        ],
      ),
    );
  }

  Widget _buildInitialsGradient(String name, {double size = 86, double fontSize = 26}) {
    final clean = name.trim();
    String initials = '?';
    if (clean.isNotEmpty) {
      final parts = clean.split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
      if (parts.length >= 2) {
        initials = '${parts[0][0]}${parts[1][0]}'.toUpperCase();
      } else {
        initials = parts[0].substring(0, parts[0].length >= 2 ? 2 : 1).toUpperCase();
      }
    }

    const gradients = [
      [Color(0xFF6366F1), Color(0xFF8B5CF6)], // Indigo - Purple
      [Color(0xFFEC4899), Color(0xFFF43F5E)], // Pink - Rose
      [Color(0xFF06B6D4), Color(0xFF3B82F6)], // Cyan - Blue
      [Color(0xFF10B981), Color(0xFF059669)], // Emerald - Teal
      [Color(0xFFF59E0B), Color(0xFFEF4444)], // Amber - Red
      [Color(0xFF8B5CF6), Color(0xFFD946EF)], // Purple - Fuchsia
      [Color(0xFF3B82F6), Color(0xFF1D4ED8)], // Royal Blue
      [Color(0xFF14B8A6), Color(0xFF0D9488)], // Teal
    ];
    final colorPair = gradients[clean.hashCode.abs() % gradients.length];

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: colorPair,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Text(
          initials,
          style: TextStyle(
            color: Colors.white,
            fontSize: fontSize,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
          ),
        ),
      ),
    );
  }
}
