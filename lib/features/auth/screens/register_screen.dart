import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:campuslink/core/auth/auth_provider.dart';
import 'package:campuslink/core/theme/app_theme.dart';
import 'package:campuslink/shared/widgets/cl_button.dart';
import 'package:campuslink/shared/widgets/cl_input.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _uniId = TextEditingController();
  final _password = TextEditingController();
  bool _loading = false;
  bool _agreed = false;
  String? _error;

  Future<void> _register() async {
    if (!_form.currentState!.validate()) return;
    if (!_agreed) {
      setState(() => _error = 'Please agree to the terms');
      return;
    }
    setState(() { _loading = true; _error = null; });
    final ok = await ref.read(authProvider.notifier).register(
      _email.text.trim(),
      _name.text.trim(),
      _password.text,
      _uniId.text.trim(),
    );
    if (!mounted) return;
    setState(() => _loading = false);
    if (ok) {
      context.go('/pin-setup');
    } else {
      setState(() => _error = 'Registration failed. Email may already be in use.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Form(
            key: _form,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 20),
                GestureDetector(
                  onTap: () => context.go('/onboarding'),
                  child: Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(10)),
                    child: const Icon(Icons.arrow_back_ios_new_rounded, size: 16, color: AppColors.textSecondary),
                  ),
                ),
                const SizedBox(height: 24),
                const Text('Create account', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
                const SizedBox(height: 6),
                const Text('Join your campus community today', style: TextStyle(fontSize: 14, color: AppColors.textSecondary)),
                const SizedBox(height: 28),

                // Avatar picker
                Center(
                  child: Stack(
                    children: [
                      Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          color: AppColors.primaryTint,
                          borderRadius: BorderRadius.circular(22),
                          border: Border.all(color: AppColors.primaryBorder, width: 2, style: BorderStyle.solid),
                        ),
                        child: const Icon(Icons.person_rounded, size: 36, color: AppColors.primary),
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                          child: const Icon(Icons.camera_alt_rounded, size: 12, color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                CLInput(
                  label: 'Full name',
                  placeholder: 'Alwatan Mwangi',
                  controller: _name,
                  prefixIcon: const Icon(Icons.person_outline_rounded, size: 18, color: AppColors.textHint),
                  validator: (v) => (v?.isEmpty ?? true) ? 'Required' : null,
                ),
                const SizedBox(height: 14),
                CLInput(
                  label: 'Email address',
                  placeholder: 'you@university.ac.tz',
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  prefixIcon: const Icon(Icons.mail_outline_rounded, size: 18, color: AppColors.textHint),
                  validator: (v) => (v?.isEmpty ?? true) ? 'Required' : null,
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: CLInput(
                        label: 'University ID',
                        placeholder: 'Optional',
                        controller: _uniId,
                        prefixIcon: const Icon(Icons.badge_outlined, size: 18, color: AppColors.textHint),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: CLInput(
                        label: 'Password',
                        placeholder: '••••••••',
                        password: true,
                        controller: _password,
                        prefixIcon: const Icon(Icons.lock_outline_rounded, size: 18, color: AppColors.textHint),
                        validator: (v) => (v?.length ?? 0) < 6 ? 'Min 6 chars' : null,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Terms
                GestureDetector(
                  onTap: () => setState(() => _agreed = !_agreed),
                  child: Row(
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        width: 20,
                        height: 20,
                        decoration: BoxDecoration(
                          color: _agreed ? AppColors.primary : Colors.transparent,
                          border: Border.all(
                            color: _agreed ? AppColors.primary : AppColors.border,
                            width: 1.5,
                          ),
                          borderRadius: BorderRadius.circular(5),
                        ),
                        child: _agreed
                            ? const Icon(Icons.check_rounded, size: 13, color: Colors.white)
                            : null,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: RichText(
                          text: const TextSpan(
                            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                            children: [
                              TextSpan(text: 'I agree to the '),
                              TextSpan(text: 'Terms of Service', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600)),
                              TextSpan(text: ' and '),
                              TextSpan(text: 'Privacy Policy', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(10)),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline_rounded, size: 16, color: Colors.red),
                        const SizedBox(width: 8),
                        Expanded(child: Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 13))),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 24),
                CLButton(label: 'Create account', onTap: _register, loading: _loading),
                const SizedBox(height: 20),

                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('Already have an account? ', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                    GestureDetector(
                      onTap: () => context.go('/login'),
                      child: const Text('Sign in', style: TextStyle(fontSize: 13, color: AppColors.primary, fontWeight: FontWeight.w700)),
                    ),
                  ],
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }
}