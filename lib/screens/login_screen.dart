import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../theme/app_radii.dart';
import '../theme/app_spacing.dart';
import '../providers/auth_provider.dart';
import '../providers/audio_provider.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with SingleTickerProviderStateMixin {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  bool _isSignUp = false;
  bool _obscurePassword = true;
  String? _localError;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _handleEmailAuth() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _localError = null);

    final authProvider = context.read<AuthProvider>();
    final audioProvider = context.read<AudioProvider>();

    bool success;
    if (_isSignUp) {
      success = await authProvider.signUpWithEmail(
        email: _emailController.text.trim(),
        password: _passwordController.text,
        displayName: _nameController.text.trim().isEmpty ? null : _nameController.text.trim(),
      );
    } else {
      success = await authProvider.signInWithEmail(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );
    }

    if (!mounted) return;

    if (success) {
      await audioProvider.reloadUserLibrary();
      Navigator.of(context).pop(true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _isSignUp ? 'Account created! Welcome.' : 'Signed in successfully!',
            style: const TextStyle(color: Colors.white),
          ),
          backgroundColor: AppColors.surface2,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else {
      setState(() {
        _localError = authProvider.errorMessage ?? 'Authentication failed. Please check your inputs.';
      });
    }
  }

  Future<void> _handleGoogleAuth() async {
    setState(() => _localError = null);
    final authProvider = context.read<AuthProvider>();
    final success = await authProvider.signInWithGoogle();

    if (!mounted) return;

    if (success) {
      final audioProvider = context.read<AudioProvider>();
      await audioProvider.reloadUserLibrary();
      Navigator.of(context).pop(true);
    } else if (authProvider.errorMessage != null) {
      setState(() {
        _localError = authProvider.errorMessage;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final isLoading = authProvider.isLoading;

    return Scaffold(
      backgroundColor: AppColors.bgDeep,
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

          // Ambient Purple Hero Glow
          Positioned(
            top: -50,
            left: 0,
            right: 0,
            height: MediaQuery.of(context).size.height * 0.45,
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  center: Alignment.topCenter,
                  radius: 0.85,
                  colors: [
                    AppColors.primarySoft.withValues(alpha: 0.25),
                    AppColors.primary.withValues(alpha: 0.08),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),

          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.x24, vertical: AppSpacing.x16),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Close / Back button row
                      Align(
                        alignment: Alignment.centerLeft,
                        child: IconButton(
                          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.iconIdle, size: 20),
                          onPressed: () => Navigator.of(context).pop(false),
                        ),
                      ),

                      const SizedBox(height: 12),

                      // Brand Icon
                      Center(
                        child: Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: const LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [AppColors.primarySoft, AppColors.sunsetViolet],
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.primarySoft.withValues(alpha: 0.35),
                                blurRadius: 24,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.music_note_rounded,
                            size: 42,
                            color: Colors.white,
                          ),
                        ),
                      ),

                      const SizedBox(height: 20),

                      // Title & Subtitle
                      Center(
                        child: Text(
                          _isSignUp ? 'Create Account' : 'Welcome Back',
                          style: AppTextStyles.screenTitle.copyWith(fontSize: 26),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Center(
                        child: Text(
                          _isSignUp
                              ? 'Join to sync your playlists and favorites across all devices'
                              : 'Sign in to access your personal music vault',
                          textAlign: TextAlign.center,
                          style: AppTextStyles.subtitle.copyWith(color: AppColors.textSecondary),
                        ),
                      ),

                      const SizedBox(height: 28),

                      // Segmented Tab Toggle (Sign In / Sign Up)
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: AppColors.surface1,
                          borderRadius: AppRadii.borderPill,
                          border: Border.all(
                            color: AppColors.primarySoft.withValues(alpha: 0.15),
                          ),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: GestureDetector(
                                onTap: () => setState(() {
                                  _isSignUp = false;
                                  _localError = null;
                                }),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  padding: const EdgeInsets.symmetric(vertical: 10),
                                  decoration: BoxDecoration(
                                    color: !_isSignUp ? AppColors.surface2 : Colors.transparent,
                                    borderRadius: AppRadii.borderPill,
                                  ),
                                  child: Center(
                                    child: Text(
                                      'Sign In',
                                      style: TextStyle(
                                        color: !_isSignUp ? AppColors.textPrimary : AppColors.textMuted,
                                        fontWeight: !_isSignUp ? FontWeight.w600 : FontWeight.normal,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            Expanded(
                              child: GestureDetector(
                                onTap: () => setState(() {
                                  _isSignUp = true;
                                  _localError = null;
                                }),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  padding: const EdgeInsets.symmetric(vertical: 10),
                                  decoration: BoxDecoration(
                                    color: _isSignUp ? AppColors.surface2 : Colors.transparent,
                                    borderRadius: AppRadii.borderPill,
                                  ),
                                  child: Center(
                                    child: Text(
                                      'Sign Up',
                                      style: TextStyle(
                                        color: _isSignUp ? AppColors.textPrimary : AppColors.textMuted,
                                        fontWeight: _isSignUp ? FontWeight.w600 : FontWeight.normal,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 24),

                      // Error Banner
                      if (_localError != null) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: AppColors.error.withValues(alpha: 0.15),
                            borderRadius: AppRadii.borderMedium,
                            border: Border.all(color: AppColors.error.withValues(alpha: 0.4)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.error_outline_rounded, color: AppColors.error, size: 20),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  _localError!,
                                  style: AppTextStyles.meta.copyWith(color: AppColors.error),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],

                      // Name Field (only in Sign Up)
                      if (_isSignUp) ...[
                        _buildInputField(
                          controller: _nameController,
                          hintText: 'Display Name',
                          icon: Icons.person_outline_rounded,
                          validator: (val) {
                            if (val == null || val.trim().isEmpty) {
                              return 'Please enter your name';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 14),
                      ],

                      // Email Field
                      _buildInputField(
                        controller: _emailController,
                        hintText: 'Email address',
                        icon: Icons.email_outlined,
                        keyboardType: TextInputType.emailAddress,
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) {
                            return 'Please enter your email';
                          }
                          if (!val.contains('@') || !val.contains('.')) {
                            return 'Please enter a valid email';
                          }
                          return null;
                        },
                      ),

                      const SizedBox(height: 14),

                      // Password Field
                      _buildInputField(
                        controller: _passwordController,
                        hintText: 'Password',
                        icon: Icons.lock_outline_rounded,
                        obscureText: _obscurePassword,
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                            color: AppColors.iconIdle,
                            size: 20,
                          ),
                          onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                        ),
                        validator: (val) {
                          if (val == null || val.length < 6) {
                            return 'Password must be at least 6 characters';
                          }
                          return null;
                        },
                      ),

                      const SizedBox(height: 24),

                      // Submit Gradient Button
                      GestureDetector(
                        onTap: isLoading ? null : _handleEmailAuth,
                        child: Container(
                          height: 52,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [AppColors.primary, AppColors.primarySoft],
                            ),
                            borderRadius: AppRadii.borderPill,
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.primary.withValues(alpha: 0.35),
                                blurRadius: 16,
                                offset: const Offset(0, 6),
                              ),
                            ],
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
                                : Text(
                                    _isSignUp ? 'Create Account' : 'Sign In',
                                    style: AppTextStyles.buttonLabel.copyWith(
                                      color: Colors.white,
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 20),

                      // Divider Row
                      Row(
                        children: [
                          Expanded(
                            child: Divider(color: AppColors.surface2, thickness: 1),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 14),
                            child: Text(
                              'OR',
                              style: AppTextStyles.meta.copyWith(color: AppColors.textMuted),
                            ),
                          ),
                          Expanded(
                            child: Divider(color: AppColors.surface2, thickness: 1),
                          ),
                        ],
                      ),

                      const SizedBox(height: 20),

                      // Google Sign In Button
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          backgroundColor: AppColors.surface1,
                          side: BorderSide(color: AppColors.surface2),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: const RoundedRectangleBorder(
                            borderRadius: AppRadii.borderPill,
                          ),
                        ),
                        icon: const Icon(Icons.g_mobiledata_rounded, size: 28, color: Colors.white),
                        label: Text(
                          'Continue with Google',
                          style: AppTextStyles.buttonLabel.copyWith(
                            color: AppColors.textPrimary,
                            fontSize: 14,
                          ),
                        ),
                        onPressed: isLoading ? null : _handleGoogleAuth,
                      ),

                      const SizedBox(height: 12),

                      // Continue as Guest Option
                      TextButton(
                        onPressed: isLoading ? null : () => Navigator.of(context).pop(false),
                        child: Text(
                          'Continue as Guest',
                          style: AppTextStyles.subtitle.copyWith(
                            color: AppColors.textSecondary,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String hintText,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    bool obscureText = false,
    Widget? suffixIcon,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscureText,
      style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textPrimary),
      validator: validator,
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: AppTextStyles.bodyMedium.copyWith(color: AppColors.textMuted),
        prefixIcon: Icon(icon, color: AppColors.iconIdle, size: 20),
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: AppColors.surface1,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: AppRadii.borderMedium,
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: AppRadii.borderMedium,
          borderSide: BorderSide(color: AppColors.surface2, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: AppRadii.borderMedium,
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: AppRadii.borderMedium,
          borderSide: const BorderSide(color: AppColors.error, width: 1),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: AppRadii.borderMedium,
          borderSide: const BorderSide(color: AppColors.error, width: 1.5),
        ),
      ),
    );
  }
}
