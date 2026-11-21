import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../theme/app_radii.dart';
import '../theme/app_spacing.dart';
import '../providers/auth_provider.dart';
import '../providers/audio_provider.dart';
import '../core/services/supabase_service.dart';

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
  StreamSubscription<AuthState>? _authSubscription;
  bool _isDismissed = false;

  @override
  void initState() {
    super.initState();
    _authSubscription = SupabaseService.authStateChanges.listen((data) {
      if (data.event == AuthChangeEvent.signedIn && mounted) {
        _safeDismiss('Signed in successfully!');
      }
    });
  }

  void _safeDismiss(String message) {
    if (_isDismissed || !mounted) return;
    _isDismissed = true;
    _authSubscription?.cancel();
    final audioProvider = context.read<AudioProvider>();
    audioProvider.reloadUserLibrary();
    Navigator.of(context).pop(true);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(color: Colors.white)),
        backgroundColor: AppColors.surface2,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _handleEmailAuth() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _localError = null);

    final authProvider = context.read<AuthProvider>();

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
      _safeDismiss(_isSignUp ? 'Account created! Welcome.' : 'Signed in successfully!');
    } else {
      setState(() {
        _localError = authProvider.errorMessage ?? 'Authentication failed. Please check your credentials.';
      });
    }
  }

  Future<void> _handleGoogleAuth() async {
    setState(() => _localError = null);
    final authProvider = context.read<AuthProvider>();
    try {
      final launched = await authProvider.signInWithGoogle();
      if (!mounted) return;

      if (!launched && authProvider.errorMessage != null) {
        setState(() => _localError = authProvider.errorMessage);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Opening Google sign-in in your browser...'),
            backgroundColor: AppColors.surface2,
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _localError = 'Google sign-in error: $e');
      }
    }
  }

  void _showGoogleOAuthSetupDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface1,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(AppRadii.lg))),
        title: Text('Google Sign-In Setup Info', style: AppTextStyles.h3.copyWith(fontSize: 18)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'To prevent "Error 400: redirect_uri_mismatch", configure your Google Cloud Console OAuth 2.0 Web Client with these exact values:',
                style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary, height: 1.4),
              ),
              const SizedBox(height: 14),
              const Text('Package Name:', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
              const SelectableText('com.toufiqsec.music_app', style: TextStyle(color: AppColors.primarySoft, fontFamily: 'monospace', fontSize: 12)),
              const SizedBox(height: 10),
              const Text('Authorized Redirect URI (Google Cloud):', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
              const SelectableText('https://wcztbsbcfjoxlypghjil.supabase.co/auth/v1/callback', style: TextStyle(color: AppColors.primarySoft, fontFamily: 'monospace', fontSize: 11)),
              const SizedBox(height: 10),
              const Text('App Deep Link Scheme (Supabase URL config):', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
              const SelectableText('io.supabase.musicapp://login-callback', style: TextStyle(color: AppColors.primarySoft, fontFamily: 'monospace', fontSize: 12)),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Got it', style: TextStyle(color: AppColors.primarySoft, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showForgotPasswordDialog() {
    final resetEmailController = TextEditingController(text: _emailController.text);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface1,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(AppRadii.lg))),
        title: Text('Reset Password', style: AppTextStyles.h3),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Enter your email address to receive password reset instructions.',
              style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: resetEmailController,
              keyboardType: TextInputType.emailAddress,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Email address',
                hintStyle: const TextStyle(color: Colors.white38),
                filled: true,
                fillColor: AppColors.surface2,
                border: OutlineInputBorder(borderRadius: AppRadii.borderMedium, borderSide: BorderSide.none),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            onPressed: () async {
              final email = resetEmailController.text.trim();
              if (email.isEmpty || !email.contains('@')) return;
              Navigator.of(ctx).pop();
              final authProvider = context.read<AuthProvider>();
              final sent = await authProvider.resetPassword(email);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(sent
                        ? 'Password reset instructions sent to $email'
                        : authProvider.errorMessage ?? 'Failed to send reset email'),
                    backgroundColor: AppColors.surface2,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            },
            child: const Text('Send Reset Link', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
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

                      if (!_isSignUp) ...[
                        const SizedBox(height: 6),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: isLoading ? null : _showForgotPasswordDialog,
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            child: Text(
                              'Forgot Password?',
                              style: AppTextStyles.caption.copyWith(color: AppColors.primarySoft),
                            ),
                          ),
                        ),
                      ],

                      const SizedBox(height: 20),

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

                      const SizedBox(height: 6),

                      // Google OAuth Setup Info Link
                      Center(
                        child: TextButton.icon(
                          onPressed: _showGoogleOAuthSetupDialog,
                          icon: const Icon(Icons.info_outline_rounded, size: 14, color: AppColors.primarySoft),
                          label: const Text(
                            'Google Sign-In setup details',
                            style: TextStyle(color: AppColors.primarySoft, fontSize: 11, decoration: TextDecoration.underline),
                          ),
                        ),
                      ),

                      const SizedBox(height: 10),

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

                      const SizedBox(height: 8),

                      // Toggle Sign In / Sign Up prompt
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            _isSignUp ? 'Already have an account?' : "Don't have an account?",
                            style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
                          ),
                          TextButton(
                            onPressed: isLoading
                                ? null
                                : () => setState(() {
                                      _isSignUp = !_isSignUp;
                                      _localError = null;
                                    }),
                            child: Text(
                              _isSignUp ? 'Sign In' : 'Sign Up',
                              style: AppTextStyles.caption.copyWith(
                                color: AppColors.primarySoft,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
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
