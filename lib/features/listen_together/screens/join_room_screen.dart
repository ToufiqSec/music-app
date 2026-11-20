import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_radii.dart';
import '../../../theme/app_text_styles.dart';
import '../../../providers/auth_provider.dart';
import '../providers/room_provider.dart';
import 'room_screen.dart';

class JoinRoomScreen extends StatefulWidget {
  final String? initialCode;
  const JoinRoomScreen({super.key, this.initialCode});

  @override
  State<JoinRoomScreen> createState() => _JoinRoomScreenState();
}

class _JoinRoomScreenState extends State<JoinRoomScreen> {
  final List<TextEditingController> _codeControllers =
      List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());
  final TextEditingController _nameController = TextEditingController();

  String? _inlineError;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    final authProvider = context.read<AuthProvider>();
    _nameController.text = authProvider.displayName;
    if (widget.initialCode != null && widget.initialCode!.isNotEmpty) {
      final chars = widget.initialCode!.trim().toUpperCase().split('');
      for (int i = 0; i < chars.length && i < _codeControllers.length; i++) {
        _codeControllers[i].text = chars[i];
      }
    }
  }

  @override
  void dispose() {
    for (final c in _codeControllers) {
      c.dispose();
    }
    for (final f in _focusNodes) {
      f.dispose();
    }
    _nameController.dispose();
    super.dispose();
  }

  String get _currentCode =>
      _codeControllers.map((c) => c.text.trim().toUpperCase()).join();

  bool get _isCodeComplete => _currentCode.length == 6;

  void _onCodeChanged(int index, String value) {
    setState(() {
      _inlineError = null;
    });

    if (value.length > 1) {
      // Pasted full or partial code
      final clean = value.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '').toUpperCase();
      for (int i = 0; i < 6 && i < clean.length; i++) {
        _codeControllers[i].text = clean[i];
      }
      final nextFocus = clean.length < 6 ? clean.length : 5;
      _focusNodes[nextFocus].requestFocus();
      setState(() {});
      return;
    }

    if (value.isNotEmpty) {
      _codeControllers[index].text = value.toUpperCase();
      if (index < 5) {
        _focusNodes[index + 1].requestFocus();
      } else {
        _focusNodes[index].unfocus();
      }
    } else if (index > 0) {
      // Backspace navigation to previous box (Issue 5.3)
      _focusNodes[index - 1].requestFocus();
    }
  }

  Future<void> _handleJoin() async {
    if (!_isCodeComplete || _isSubmitting) return;

    final roomProvider = context.read<RoomProvider>();
    final code = _currentCode;
    final name = _nameController.text.trim().isNotEmpty
        ? _nameController.text.trim()
        : 'Listener';

    setState(() {
      _isSubmitting = true;
      _inlineError = null;
    });

    final success = await roomProvider.joinRoom(
      code: code,
      displayName: name,
    );

    if (!mounted) return;

    setState(() {
      _isSubmitting = false;
    });

    if (success) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const RoomScreen()),
      );
    } else {
      setState(() {
        _inlineError = roomProvider.errorMessage ?? 'Could not join room. Check code.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    return Scaffold(
      backgroundColor: AppColors.bgDeep,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text('Join Room', style: AppTextStyles.h3),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 12),
              // Icon
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: AppColors.primarySoft.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.primarySoft.withValues(alpha: 0.3)),
                ),
                child: const Icon(
                  Icons.group_add_rounded,
                  color: AppColors.accentTeal,
                  size: 36,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Enter 6-Character Code',
                style: AppTextStyles.h2.copyWith(fontSize: 22),
              ),
              const SizedBox(height: 8),
              Text(
                'Type the invite code provided by the room host to listen in sync.',
                textAlign: TextAlign.center,
                style: AppTextStyles.bodySecondary.copyWith(fontSize: 14),
              ),
              const SizedBox(height: 36),

              // 6 PIN Input Boxes (Spec Section 7.2)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: List.generate(6, (index) {
                  return SizedBox(
                    width: 48,
                    height: 58,
                    child: TextField(
                      controller: _codeControllers[index],
                      focusNode: _focusNodes[index],
                      textAlign: TextAlign.center,
                      textCapitalization: TextCapitalization.characters,
                      keyboardType: TextInputType.text,
                      maxLength: 1,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'monospace',
                      ),
                      decoration: InputDecoration(
                        counterText: '',
                        filled: true,
                        fillColor: AppColors.surface1,
                        contentPadding: EdgeInsets.zero,
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppRadii.md),
                          borderSide: BorderSide(
                            color: _codeControllers[index].text.isNotEmpty
                                ? AppColors.primarySoft
                                : AppColors.cardBorder,
                            width: 1.5,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppRadii.md),
                          borderSide: const BorderSide(
                            color: AppColors.accentTeal,
                            width: 2,
                          ),
                        ),
                      ),
                      onChanged: (val) => _onCodeChanged(index, val),
                    ),
                  );
                }),
              ),

              // Inline Error Message (Spec Section 7.2)
              if (_inlineError != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppColors.error.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(AppRadii.sm),
                    border: Border.all(color: AppColors.error.withValues(alpha: 0.4)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline_rounded, color: AppColors.error, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _inlineError!,
                          style: const TextStyle(color: AppColors.error, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 28),

              // Display Name Input (For Guest or Custom Room Name)
              TextField(
                controller: _nameController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Your Display Name in Room',
                  labelStyle: const TextStyle(color: AppColors.textSecondary),
                  hintText: auth.displayName,
                  hintStyle: TextStyle(color: AppColors.textTertiary.withValues(alpha: 0.5)),
                  prefixIcon: const Icon(Icons.person_outline_rounded, color: AppColors.iconIdle),
                  filled: true,
                  fillColor: AppColors.surface1,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadii.md),
                    borderSide: const BorderSide(color: AppColors.cardBorder),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadii.md),
                    borderSide: const BorderSide(color: AppColors.cardBorder),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadii.md),
                    borderSide: const BorderSide(color: AppColors.accentTeal),
                  ),
                ),
              ),

              const SizedBox(height: 36),

              // Join Button (Spec Section 7.2)
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _isCodeComplete ? AppColors.primarySoft : AppColors.surface2,
                    foregroundColor: _isCodeComplete ? Colors.white : AppColors.textTertiary,
                    elevation: _isCodeComplete ? 4 : 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadii.md),
                    ),
                  ),
                  onPressed: _isCodeComplete && !_isSubmitting ? _handleJoin : null,
                  child: _isSubmitting
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : Text(
                          'Join Room',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: _isCodeComplete ? Colors.white : AppColors.textTertiary,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
