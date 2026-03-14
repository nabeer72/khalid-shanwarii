import 'package:flutter/material.dart';
import 'package:mobile_app/providers/theme_provider.dart';

class PinDialogs {
  /// Dialog asking the user if they want to save their credentials for fast login.
  static Future<bool> showSaveCredentialPrompt(BuildContext context) async {
    final theme = ThemeProvider.instance;
    return await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: theme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Row(
          children: [
            Icon(Icons.security_rounded, color: theme.highlight, size: 28),
            const SizedBox(width: 12),
            Text('Quick Login', style: TextStyle(color: theme.textPrimary, fontWeight: FontWeight.w900)),
          ],
        ),
        content: Text(
          'Do you want to save your credentials and set a 4-digit PIN for quick access on this device?',
          style: TextStyle(color: theme.textSecondary, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('NO THANKS', style: TextStyle(color: theme.textHint, fontWeight: FontWeight.w800)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.highlight,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('YES, SETUP PIN', style: TextStyle(fontWeight: FontWeight.w900)),
          ),
        ],
      ),
    ) ?? false;
  }

  /// Dialog to setup a new 4-digit PIN (requires entering twice to confirm).
  static Future<String?> showSetupPinDialog(BuildContext context) async {
    return await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const _SetupPinDialog(),
    );
  }

  /// Dialog to enter an existing 4-digit PIN to login.
  static Future<String?> showEnterPinDialog(BuildContext context, String accountName) async {
    return await showDialog<String>(
      context: context,
      builder: (ctx) => _EnterPinDialog(accountName: accountName),
    );
  }
}

class _SetupPinDialog extends StatefulWidget {
  const _SetupPinDialog();
  @override
  State<_SetupPinDialog> createState() => _SetupPinDialogState();
}

class _SetupPinDialogState extends State<_SetupPinDialog> {
  final theme = ThemeProvider.instance;
  String _pin = '';
  String _confirmPin = '';
  bool _isConfirming = false;
  String? _error;

  void _onDigit(String digit) {
    setState(() {
      _error = null;
      if (!_isConfirming && _pin.length < 4) {
        _pin += digit;
        if (_pin.length == 4) {
          Future.delayed(const Duration(milliseconds: 300), () {
            setState(() => _isConfirming = true);
          });
        }
      } else if (_isConfirming && _confirmPin.length < 4) {
        _confirmPin += digit;
        if (_confirmPin.length == 4) {
          if (_pin == _confirmPin) {
            Future.delayed(const Duration(milliseconds: 200), () {
              Navigator.pop(context, _pin);
            });
          } else {
            setState(() {
              _error = 'PINs do not match. Try again.';
              _confirmPin = '';
            });
          }
        }
      }
    });
  }

  void _onBackspace() {
    setState(() {
      _error = null;
      if (_isConfirming) {
        if (_confirmPin.isNotEmpty) {
          _confirmPin = _confirmPin.substring(0, _confirmPin.length - 1);
        } else {
          _isConfirming = false;
          _pin = '';
        }
      } else {
        if (_pin.isNotEmpty) {
          _pin = _pin.substring(0, _pin.length - 1);
        }
      }
    });
  }

  Widget _buildDot(bool isFilled) {
    return Container(
      width: 16,
      height: 16,
      margin: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: isFilled ? theme.highlight : Colors.transparent,
        shape: BoxShape.circle,
        border: Border.all(color: isFilled ? theme.highlight : theme.whiteAlpha(0.2), width: 2),
      ),
    );
  }

  Widget _buildKeypadBtn(String text, {IconData? icon, VoidCallback? onTap}) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          height: 64,
          alignment: Alignment.center,
          child: icon != null 
            ? Icon(icon, color: theme.textPrimary, size: 28)
            : Text(text, style: TextStyle(color: theme.textPrimary, fontSize: 28, fontWeight: FontWeight.w600)),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentLength = _isConfirming ? _confirmPin.length : _pin.length;
    return Dialog(
      backgroundColor: theme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                _isConfirming ? 'Confirm PIN' : 'Set 4-Digit PIN',
                style: TextStyle(color: theme.textPrimary, fontSize: 20, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 8),
              Text(
                _isConfirming ? 'Enter the same PIN again' : 'This will be used for quick login',
                style: TextStyle(color: theme.textSecondary, fontSize: 13),
              ),
              const SizedBox(height: 32),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(4, (index) => _buildDot(index < currentLength)),
              ),
              if (_error != null) ...[
                 const SizedBox(height: 16),
                 Text(_error!, style: const TextStyle(color: ThemeProvider.error, fontSize: 13, fontWeight: FontWeight.bold)),
              ] else const SizedBox(height: 32),
              
              // Keypad
              for (var i = 0; i < 3; i++) ...[
                Row(
                  children: [
                    for (var j = 1; j <= 3; j++) 
                      _buildKeypadBtn('${i * 3 + j}', onTap: () => _onDigit('${i * 3 + j}')),
                  ],
                ),
                const SizedBox(height: 8),
              ],
              Row(
                children: [
                  _buildKeypadBtn('Cancel', onTap: () => Navigator.pop(context, null)),
                  _buildKeypadBtn('0', onTap: () => _onDigit('0')),
                  _buildKeypadBtn('', icon: Icons.backspace_rounded, onTap: _onBackspace),
                ],
              ),
            ],
          ),
          ),
        ),
      ),
    );
  }
}

class _EnterPinDialog extends StatefulWidget {
  final String accountName;
  const _EnterPinDialog({required this.accountName});

  @override
  State<_EnterPinDialog> createState() => _EnterPinDialogState();
}

class _EnterPinDialogState extends State<_EnterPinDialog> {
  final theme = ThemeProvider.instance;
  String _pin = '';

  void _onDigit(String digit) {
    if (_pin.length < 4) {
      setState(() {
        _pin += digit;
      });
      if (_pin.length == 4) {
        Future.delayed(const Duration(milliseconds: 200), () {
          Navigator.pop(context, _pin);
        });
      }
    }
  }

  void _onBackspace() {
    if (_pin.isNotEmpty) {
      setState(() {
        _pin = _pin.substring(0, _pin.length - 1);
      });
    }
  }

  Widget _buildDot(bool isFilled) {
    return Container(
      width: 16,
      height: 16,
      margin: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: isFilled ? theme.highlight : Colors.transparent,
        shape: BoxShape.circle,
        border: Border.all(color: isFilled ? theme.highlight : theme.whiteAlpha(0.2), width: 2),
      ),
    );
  }

  Widget _buildKeypadBtn(String text, {IconData? icon, VoidCallback? onTap}) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          height: 64,
          alignment: Alignment.center,
          child: icon != null 
            ? Icon(icon, color: theme.textPrimary, size: 28)
            : Text(text, style: TextStyle(color: theme.textPrimary, fontSize: 28, fontWeight: FontWeight.w600)),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: theme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Stack(
                alignment: Alignment.center,
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: IconButton(
                      icon: Icon(Icons.close_rounded, color: theme.textHint),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                  Column(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: theme.highlight.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.person_rounded, color: theme.highlight),
                      ),
                      const SizedBox(height: 8),
                    ],
                  ),
                ],
              ),
              Text(
                'Welcome Back',
                style: TextStyle(color: theme.textPrimary, fontSize: 14, fontWeight: FontWeight.w600),
              ),
              Text(
                widget.accountName,
                style: TextStyle(color: theme.textPrimary, fontSize: 20, fontWeight: FontWeight.w900, letterSpacing: -0.5),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(4, (index) => _buildDot(index < _pin.length)),
              ),
              const SizedBox(height: 32),
              
              // Keypad
              for (var i = 0; i < 3; i++) ...[
                Row(
                  children: [
                    for (var j = 1; j <= 3; j++) 
                      _buildKeypadBtn('${i * 3 + j}', onTap: () => _onDigit('${i * 3 + j}')),
                  ],
                ),
                const SizedBox(height: 8),
              ],
              Row(
                children: [
                  const Spacer(),
                  _buildKeypadBtn('0', onTap: () => _onDigit('0')),
                  _buildKeypadBtn('', icon: Icons.backspace_rounded, onTap: _onBackspace),
                ],
              ),
            ],
          ),
          ),
        ),
      ),
    );
  }
}
