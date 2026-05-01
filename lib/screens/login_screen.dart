import 'package:flutter/material.dart';
import '../services/auth_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final AuthService _authService = AuthService();
  bool _isVerifying = false;

  Future<void> _handleSignIn() async {
    setState(() => _isVerifying = true);
    
    try {
      final userCred = await _authService.signInWithGoogle();
      
      if (userCred?.user != null) {
        final email = userCred!.user!.email!;
        final isAdmin = await _authService.isAdmin(email);
        
        if (!isAdmin) {
          await _authService.signOut();
          if (mounted) {
            _showError("Access Denied", "The account '$email' is not authorized to use this app.");
          }
        }
      }
    } catch (e) {
      if (mounted) _showError("Login Error", e.toString());
    } finally {
      if (mounted) setState(() => _isVerifying = false);
    }
  }

  void _showError(String title, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("OK"))
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.satellite_alt_rounded, size: 80, color: Colors.blue),
              const SizedBox(height: 20),
              const Text(
                "NAP Finder",
                style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
              ),
              const Text(
                "Authorized Access Only",
                style: TextStyle(color: Colors.grey, fontSize: 14),
              ),
              const SizedBox(height: 60),
              _isVerifying
                  ? const CircularProgressIndicator()
                  : ElevatedButton.icon(
                      onPressed: _handleSignIn,
                      icon: const Icon(Icons.login),
                      label: const Text("Sign in with Google"),
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 50),
                        backgroundColor: Colors.blueGrey.shade800,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
              const SizedBox(height: 20),
              const Text(
                "Technician verification required to access network maps and patching data.",
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey, fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
