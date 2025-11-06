import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api.dart' show ApiService, ApiException;

class VerifyCodeScreen extends StatefulWidget {
  final String email;

  const VerifyCodeScreen({super.key, required this.email});

  @override
  State<VerifyCodeScreen> createState() => _VerifyCodeScreenState();
}

class _VerifyCodeScreenState extends State<VerifyCodeScreen> {
  final _codeController = TextEditingController();
  final _focusNode = FocusNode();
  bool _loading = false;
  bool _resending = false;
  String? _message;
  String? _error;

  @override
  void initState() {
    super.initState();
    // Auto-focus the input field when the screen loads
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _codeController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _handleVerify() async {
    final code = _codeController.text.trim();
    
    if (code.isEmpty) {
      setState(() {
        _error = 'Please enter the verification code';
        _message = null;
      });
      return;
    }

    if (code.length != 6) {
      setState(() {
        _error = 'Verification code must be 6 digits';
        _message = null;
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
      _message = null;
    });

    try {
      await ApiService.verifyEmailCode(widget.email, code);
      setState(() {
        _message = 'Email verified successfully! Logging you in...';
      });

      // Try to auto-login with stored credentials
      final prefs = await SharedPreferences.getInstance();
      final pendingLoginJson = prefs.getString('pendingLogin');
      
      if (pendingLoginJson != null) {
        try {
          final pendingLogin = json.decode(pendingLoginJson);
          final username = pendingLogin['username'] as String;
          final password = pendingLogin['password'] as String;
          
          // Clear stored credentials
          await prefs.remove('pendingLogin');
          
          // Auto-login
          final loginResponse = await ApiService.login(username, password);
          
          if (loginResponse['error'] == null || loginResponse['error'].toString().isEmpty) {
            // Store user data
            await prefs.setString('user', json.encode({
              'id': loginResponse['id'],
              'email': loginResponse['email'],
              'firstName': loginResponse['firstName'],
              'lastName': loginResponse['lastName'],
              'emailVerified': true,
            }));
            
            // Navigate to game
            if (mounted) {
              Navigator.of(context).pushReplacementNamed('/game');
            }
            return;
          }
        } catch (loginErr) {
          // If auto-login fails, just redirect to login page
          print('Auto-login failed: $loginErr');
        }
      }
      
      // If no stored credentials or auto-login failed, redirect to login
      if (mounted) {
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) {
            Navigator.of(context).pushReplacementNamed('/login');
          }
        });
      }
    } catch (e) {
      String errorMessage;
      if (e is ApiException) {
        errorMessage = e.message;
      } else {
        errorMessage = e.toString().replaceAll('Exception: ', '');
      }
      setState(() {
        _error = errorMessage;
        _message = null;
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Future<void> _handleResend() async {
    if (widget.email.isEmpty) {
      setState(() {
        _error = 'Email address is required';
        return;
      });
    }

    setState(() {
      _resending = true;
      _error = null;
      _message = null;
    });

    try {
      final result = await ApiService.resendVerificationCode(widget.email);
      setState(() {
        _message = result['message'] ?? 'Verification code resent!';
      });
    } catch (e) {
      String errorMessage;
      if (e is Exception) {
        errorMessage = e.toString().replaceAll('Exception: ', '');
      } else {
        errorMessage = 'Failed to resend verification code';
      }
      setState(() {
        _error = errorMessage;
      });
    } finally {
      if (mounted) {
        setState(() {
          _resending = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121213),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  'Verify Your Email',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Enter the 6-digit verification code sent to\n${widget.email}',
                  style: const TextStyle(
                    fontSize: 16,
                    color: Colors.white70,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 40),
                if (_message != null)
                  Container(
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 20),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.green),
                    ),
                    child: Text(
                      _message!,
                      style: const TextStyle(color: Colors.green),
                      textAlign: TextAlign.center,
                    ),
                  ),
                if (_error != null)
                  Container(
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 20),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red),
                    ),
                    child: Text(
                      _error!,
                      style: const TextStyle(color: Colors.red),
                      textAlign: TextAlign.center,
                    ),
                  ),
                TextField(
                  controller: _codeController,
                  focusNode: _focusNode,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  maxLength: 6,
                  style: const TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 8,
                    color: Colors.white,
                  ),
                  decoration: InputDecoration(
                    hintText: '000000',
                    hintStyle: TextStyle(
                      fontSize: 32,
                      color: Colors.white.withOpacity(0.3),
                      letterSpacing: 8,
                    ),
                    filled: true,
                    fillColor: const Color(0xFF2d2d2e),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Color(0xFF3d3d3e)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Color(0xFF3d3d3e)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Color(0xFF6aaa64), width: 2),
                    ),
                    counterText: '',
                  ),
                  onChanged: (value) {
                    // Only allow digits
                    if (value.isNotEmpty && !RegExp(r'^\d+$').hasMatch(value)) {
                      _codeController.value = TextEditingValue(
                        text: value.replaceAll(RegExp(r'[^\d]'), ''),
                        selection: TextSelection.collapsed(
                          offset: value.replaceAll(RegExp(r'[^\d]'), '').length,
                        ),
                      );
                    }
                    // Auto-submit when 6 digits are entered
                    if (value.length == 6 && !_loading) {
                      _handleVerify();
                    }
                  },
                ),
                const SizedBox(height: 10),
                const Text(
                  'Enter the 6-digit code from your email',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 30),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _loading || _codeController.text.length != 6 ? null : _handleVerify,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF6aaa64),
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: _loading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text(
                            'Verify Email',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 15),
                TextButton(
                  onPressed: _resending || widget.email.isEmpty ? null : _handleResend,
                  child: _resending
                      ? const Text(
                          'Resending...',
                          style: TextStyle(color: Color(0xFF6aaa64)),
                        )
                      : const Text(
                          "Didn't receive a code? Resend",
                          style: TextStyle(color: Color(0xFF6aaa64)),
                        ),
                ),
                const SizedBox(height: 20),
                TextButton(
                  onPressed: () => Navigator.of(context).pushReplacementNamed('/login'),
                  child: const Text(
                    'Back to Login',
                    style: TextStyle(color: Colors.white70),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

