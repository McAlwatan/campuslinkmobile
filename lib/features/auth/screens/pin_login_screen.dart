import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:campuslink/core/auth/auth_provider.dart';
import 'package:campuslink/core/theme/app_theme.dart';

class PinLoginScreen extends ConsumerStatefulWidget {
  const PinLoginScreen({super.key});

  @override
  ConsumerState<PinLoginScreen> createState() => _PinLoginScreenState();
}

class _PinLoginScreenState extends ConsumerState<PinLoginScreen> {
  final List<String> _digits = [];
  bool _error = false;

  void _tap(String d) {
    if (_digits.length >= 6) return;
    setState(() { _digits.add(d); _error = false; });
    if (_digits.length == 6) _verify();
  }

  void _backspace() {
    if (_digits.isEmpty) return;
    setState(() => _digits.removeLast());
  }

  Future<void> _verify() async {
    final pin = _digits.join();
    final ok = await ref.read(authProvider.notifier).verifyPin(pin);
    if (!mounted) return;
    if (ok) {
      context.go('/home');
    } else {
      setState(() { _digits.clear(); _error = true; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    final name = (auth.user?['full_name'] as String? ?? 'there').split(' ').first;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            children: [
              const SizedBox(height: 48),
              // Avatar
              Container(
                width: 68,
                height: 68,
                decoration: BoxDecoration(
                  color: AppColors.primaryTint,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.primaryBorder, width: 2),
                ),
                child: Center(
                  child: Text(
                    name.isNotEmpty ? name[0].toUpperCase() : 'U',
                    style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w700, color: AppColors.primary),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Welcome back,\n$name 👋',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.textPrimary, height: 1.3),
              ),
              const SizedBox(height: 8),
              Text(
                _error ? 'Wrong PIN. Try again.' : 'Enter your PIN to continue',
                style: TextStyle(
                  fontSize: 13,
                  color: _error ? Colors.red : AppColors.textSecondary,
                  fontWeight: _error ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
              const SizedBox(height: 36),

              // PIN dots
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(6, (i) {
                  final filled = i < _digits.length;
                  final isActive = i == _digits.length;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    margin: const EdgeInsets.symmetric(horizontal: 7),
                    width: 16,
                    height: 16,
                    decoration: BoxDecoration(
                      color: filled ? AppColors.primary : Colors.transparent,
                      border: Border.all(
                        color: isActive
                            ? AppColors.primary
                            : filled
                            ? AppColors.primary
                            : AppColors.border,
                        width: 2,
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                  );
                }),
              ),
              const Spacer(),

              // Numpad
              _buildNumpad(),
              const SizedBox(height: 16),

              // Use password fallback
              TextButton(
                // onTap: () => context.go('/login'),
                onPressed: () => context.go('/login'),
                child: const Text(
                  'Use email & password instead',
                  style: TextStyle(fontSize: 13, color: AppColors.primary, fontWeight: FontWeight.w600),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNumpad() {
    const keys = [
      ['1', '2', '3'],
      ['4', '5', '6'],
      ['7', '8', '9'],
      ['bio', '0', 'del'],
    ];

    return Column(
      children: keys.map((row) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: row.map((k) {
              if (k == 'bio') {
                return _NumKey(
                  child: const Icon(Icons.fingerprint_rounded, size: 28, color: AppColors.primary),
                  onTap: () {},
                );
              }
              if (k == 'del') {
                return _NumKey(
                  onTap: _backspace,
                  child: const Icon(Icons.backspace_outlined, size: 22, color: AppColors.textSecondary),
                );
              }
              return _NumKey(
                child: Text(k, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                onTap: () => _tap(k),
              );
            }).toList(),
          ),
        );
      }).toList(),
    );
  }
}

class _NumKey extends StatelessWidget {
  final Widget child;
  final VoidCallback onTap;

  const _NumKey({required this.child, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 80,
        height: 72,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Center(child: child),
      ),
    );
  }
}