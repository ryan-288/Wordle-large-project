import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api.dart' show ApiService, ApiException;

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _loading = false;

  Future<void> _handleLogin() async {
    if (_usernameController.text.isEmpty || _passwordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter username and password')),
      );
      return;
    }

    setState(() => _loading = true);

    try {
      final response = await ApiService.login(
        _usernameController.text,
        _passwordController.text,
      );

      if (response['error'] != null && response['error'].toString().isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(response['error'])),
        );
      } else {
        // Store user data
        // If login succeeds, email is verified (server returns 403 if not verified)
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('user', json.encode({
          'id': response['id'],
          'email': response['email'],
          'firstName': response['firstName'],
          'lastName': response['lastName'],
          'emailVerified': true, // Login success means email is verified
        }));

        // Navigate to game (if login succeeded, email is verified)
        Navigator.of(context).pushReplacementNamed('/game');
      }
    } catch (e) {
      final errorMessage = e.toString().replaceAll('Exception: ', '');
      
      // Check if it's a 403 status (email verification needed)
      // The _ApiException preserves statusCode and email
      bool isVerificationError = false;
      String? userEmail;
      
      // Check if it's our custom ApiException with 403 status
      try {
        if (e is ApiException) {
          final apiException = e as ApiException;
          if (apiException.statusCode == 403) {
            isVerificationError = true;
            userEmail = apiException.email;
          }
        }
      } catch (_) {
        // Not our custom exception, fall through to string matching
      }
      
      // Also check error message for verification keywords
      if (!isVerificationError && (errorMessage.contains('Verification still needed') || 
          errorMessage.contains('verification') ||
          errorMessage.contains('Verification'))) {
        isVerificationError = true;
      }
      
      if (isVerificationError) {
        // Store credentials for auto-login after verification
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('pendingLogin', json.encode({
          'username': _usernameController.text,
          'password': _passwordController.text,
        }));
        
        // Use email from exception if available, otherwise use username
        final finalEmail = userEmail ?? _usernameController.text;
        
        // Automatically send verification code when user needs to verify
        try {
          await ApiService.resendVerificationCode(finalEmail);
        } catch (resendErr) {
          // If resend fails, still navigate - user can click resend button
          print('Failed to auto-send verification code: $resendErr');
        }
        
        // Navigate to verify code page
        Navigator.of(context).pushReplacementNamed(
          '/verify-code',
          arguments: finalEmail,
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMessage)),
        );
      }
    } finally {
      setState(() => _loading = false);
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
                  'Login',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 40),
                TextField(
                  controller: _usernameController,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Username',
                    labelStyle: const TextStyle(color: Colors.grey),
                    filled: true,
                    fillColor: const Color(0xFF2a2a2a),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Color(0xFF444)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Color(0xFF444)),
                    ),
                  ),
                ),
                const SizedBox(height: 15),
                TextField(
                  controller: _passwordController,
                  obscureText: true,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Password',
                    labelStyle: const TextStyle(color: Colors.grey),
                    filled: true,
                    fillColor: const Color(0xFF2a2a2a),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Color(0xFF444)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Color(0xFF444)),
                    ),
                  ),
                ),
                const SizedBox(height: 30),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _loading ? null : _handleLogin,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0D6EFD),
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: _loading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text(
                            'Login',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 20),
                TextButton(
                  onPressed: () => Navigator.of(context).pushNamed('/register'),
                  child: const Text(
                    'Create account',
                    style: TextStyle(color: Color(0xFF0D6EFD)),
                  ),
                ),
                const SizedBox(height: 10),
                TextButton(
                  onPressed: () async {
                    // Clear any stored user data to ensure guest mode
                    final prefs = await SharedPreferences.getInstance();
                    await prefs.remove('user');
                    if (mounted) {
                      Navigator.of(context).pushReplacementNamed('/game');
                    }
                  },
                  child: const Text(
                    'Play as Guest',
                    style: TextStyle(color: Color(0xFF0D6EFD)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }
}

