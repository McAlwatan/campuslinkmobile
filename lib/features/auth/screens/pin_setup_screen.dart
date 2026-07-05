import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pinput/pinput.dart';
import 'package:campuslink/core/auth/auth_provider.dart';
import 'package:campuslink/core/theme/app_theme.dart';

class PinSetupScreen extends ConsumerStatefulWidget {
  const PinSetupScreen({super.key});

  @override
  ConsumerState<PinSetupScreen> createState() => _PinSetupScreenState();
}

class _PinSetupScreenState extends ConsumerState<PinSetupScreen> {
  final _pinCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _confirming = false;
  String? _firstPin;
  String? _error;

  void _onPin(String pin) {
    if (pin.length < 6) return;
    if (!_confirming) {
      setState(() { _firstPin = pin; _confirming = true; });
      _pinCtrl.clear();
    } else {
      if (pin == _firstPin) {
        ref.read(authProvider.notifier).savePin(pin);
        context.go('/home');
      } else {
        setState(() { _error = 'PINs do not match. Try again.'; _confirming = false; _firstPin = null; });
        _pinCtrl.clear();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final defaultTheme = PinTheme(
      width: 56,
      height: 56,
      textStyle: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border, width: 1.5),
      ),
    );

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              const SizedBox(height: 32),
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: AppColors.primaryTint,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Icon(Icons.lock_outline_rounded, size: 32, color: AppColors.primary),
              ),
              const SizedBox(height: 20),
              Text(
                _confirming ? 'Confirm your PIN' : 'Set up your PIN',
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
              ),
              const SizedBox(height: 8),
              Text(
                _confirming
                    ? 'Enter the same PIN again to confirm'
                    : 'You\'ll use this every time you open CampusLink',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 40),
              Pinput(
                controller: _pinCtrl,
                length: 6,
                obscureText: true,
                obscuringCharacter: '●',
                defaultPinTheme: defaultTheme,
                focusedPinTheme: defaultTheme.copyWith(
                  decoration: defaultTheme.decoration!.copyWith(
                    border: Border.all(color: AppColors.primary, width: 2),
                    color: AppColors.primaryTint,
                  ),
                ),
                onCompleted: _onPin,
              ),
              if (_error != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(10)),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline_rounded, size: 16, color: Colors.red),
                      const SizedBox(width: 8),
                      Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 13)),
                    ],
                  ),
                ),
              ],
              const Spacer(),
              const Text(
                'You can also enable biometrics after setup',
                style: TextStyle(fontSize: 12, color: AppColors.textHint),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}