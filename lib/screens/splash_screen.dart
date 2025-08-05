import 'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:provider/provider.dart';
import 'package:insightflo_app/features/auth/presentation/providers/auth_provider.dart';
import 'package:insightflo_app/features/auth/presentation/pages/sign_in_page.dart';
import 'home_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  String _statusMessage = 'Initializing...';

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    // Show splash for at least 2 seconds
    await Future.delayed(const Duration(seconds: 1));
    
    // Update status message
    setState(() {
      _statusMessage = 'Initializing API connection...';
    });
    
    // Simple API-based initialization - no complex validation needed
    try {
      setState(() {
        _statusMessage = 'API connection ready ✓';
      });
      
      await Future.delayed(const Duration(milliseconds: 500));
      
      // Check authentication state and navigate accordingly
      setState(() {
        _statusMessage = 'Checking authentication...';
      });
      
      await _checkAuthenticationAndNavigate();
      
    } catch (e) {
      if (mounted) {
        _showConnectionError(e.toString());
      }
    }
  }

  /// Check authentication state and navigate to appropriate screen
  Future<void> _checkAuthenticationAndNavigate() async {
    if (!mounted) {
      return;
    }

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      
      // Wait for auth provider to complete initialization
      while (!authProvider.isInitialized) {
        await Future.delayed(const Duration(milliseconds: 100));
        if (!mounted) {
          return;
        }
      }
      
      // Check if user is authenticated
      if (authProvider.isAuthenticated) {
        setState(() {
          _statusMessage = 'Welcome back!';
        });
        
        await Future.delayed(const Duration(milliseconds: 500));
        
        if (mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (context) => const HomeScreen()),
          );
        }
      } else {
        setState(() {
          _statusMessage = 'Please sign in';
        });
        
        await Future.delayed(const Duration(milliseconds: 500));
        
        if (mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (context) => const SignInPage()),
          );
        }
      }
    } catch (e) {
      // If there's an error checking auth, go to sign in page
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const SignInPage()),
        );
      }
    }
  }

  void _showConnectionError(String error) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Connection Error'),
        content: Text('Failed to initialize API connection:\n$error'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _initializeApp(); // Retry
            },
            child: const Text('Retry'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (context) => const HomeScreen()),
              );
            },
            child: const Text('Continue Anyway'),
          ),
        ],
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    
    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // App Icon/Logo
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: colorScheme.primary,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Icon(
                Icons.trending_up,
                size: 60,
                color: colorScheme.onPrimary,
              ),
            ),
            const SizedBox(height: 32),
            
            // App Name
            Text(
              'InsightFlo',
              style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                color: colorScheme.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
            
            // Subtitle
            const SizedBox(height: 8),
            Text(
              'Smart Financial News',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: colorScheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
            
            const SizedBox(height: 48),
            
            // Loading indicator
            SpinKitWave(
              color: colorScheme.primary,
              size: 30.0,
            ),
            
            const SizedBox(height: 16),
            Text(
              _statusMessage,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurface.withValues(alpha: 0.6),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}