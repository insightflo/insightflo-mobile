import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/providers.dart';

/// Example demonstrating how to use AuthProvider with Consumer pattern
/// 
/// This example shows various ways to consume authentication state
/// in Flutter widgets, including different Consumer patterns and
/// state-based UI rendering.
class AuthConsumerExample extends StatelessWidget {
  const AuthConsumerExample({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Auth Consumer Example'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Basic Consumer - Rebuilds entire widget on any state change
            _buildBasicConsumerExample(),
            
            const SizedBox(height: 24),
            
            // Selector - Rebuilds only when specific value changes
            _buildSelectorExample(),
            
            const SizedBox(height: 24),
            
            // Consumer with child optimization
            _buildOptimizedConsumerExample(),
            
            const SizedBox(height: 24),
            
            // Multiple selectors for granular updates
            _buildGranularSelectorsExample(),
            
            const SizedBox(height: 24),
            
            // Authentication actions
            _buildAuthActionsExample(),
          ],
        ),
      ),
    );
  }

  /// Basic Consumer example - Rebuilds on any AuthProvider change
  Widget _buildBasicConsumerExample() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Basic Consumer',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Consumer<AuthProvider>(
              builder: (context, authProvider, child) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('State: ${authProvider.state.description}'),
                    Text('Is Authenticated: ${authProvider.isAuthenticated}'),
                    Text('User: ${authProvider.userDisplayName}'),
                    if (authProvider.hasError)
                      Text(
                        'Error: ${authProvider.errorMessage}',
                        style: const TextStyle(color: Colors.red),
                      ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  /// Selector example - Only rebuilds when isAuthenticated changes
  Widget _buildSelectorExample() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Selector Example',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Selector<AuthProvider, bool>(
              selector: (context, authProvider) => authProvider.isAuthenticated,
              builder: (context, isAuthenticated, child) {
                return Container(
                  padding: const EdgeInsets.all(12.0),
                  decoration: BoxDecoration(
                    color: isAuthenticated ? Colors.green[100] : Colors.red[100],
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        isAuthenticated ? Icons.check_circle : Icons.cancel,
                        color: isAuthenticated ? Colors.green : Colors.red,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        isAuthenticated 
                          ? 'User is authenticated'
                          : 'User is not authenticated',
                        style: TextStyle(
                          color: isAuthenticated ? Colors.green[800] : Colors.red[800],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  /// Consumer with child optimization - Child widget doesn't rebuild
  Widget _buildOptimizedConsumerExample() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Optimized Consumer',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Consumer<AuthProvider>(
              // Child widget that doesn't need to rebuild
              child: const Icon(
                Icons.account_circle,
                size: 48,
                color: Colors.blue,
              ),
              builder: (context, authProvider, child) {
                return Row(
                  children: [
                    child!, // This icon doesn't rebuild
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (authProvider.shouldShowLoading)
                            const Row(
                              children: [
                                SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                ),
                                SizedBox(width: 8),
                                Text('Loading...'),
                              ],
                            )
                          else if (authProvider.isAuthenticated)
                            Text(
                              'Welcome, ${authProvider.userDisplayName}!',
                              style: const TextStyle(fontWeight: FontWeight.w500),
                            )
                          else
                            const Text('Please sign in to continue'),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  /// Multiple selectors for granular UI updates
  Widget _buildGranularSelectorsExample() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Granular Selectors',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            
            // Loading state selector
            Selector<AuthProvider, bool>(
              selector: (context, authProvider) => authProvider.shouldShowLoading,
              builder: (context, shouldShowLoading, child) {
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  height: shouldShowLoading ? 4.0 : 0.0,
                  child: shouldShowLoading
                    ? const LinearProgressIndicator()
                    : const SizedBox.shrink(),
                );
              },
            ),
            
            const SizedBox(height: 8),
            
            // Error state selector
            Selector<AuthProvider, String?>(
              selector: (context, authProvider) => 
                authProvider.hasError ? authProvider.errorMessage : null,
              builder: (context, errorMessage, child) {
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  height: errorMessage != null ? 60.0 : 0.0,
                  child: errorMessage != null
                    ? Container(
                        padding: const EdgeInsets.all(8.0),
                        decoration: BoxDecoration(
                          color: Colors.red[50],
                          border: Border.all(color: Colors.red[300]!),
                          borderRadius: BorderRadius.circular(4.0),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.error, color: Colors.red[700], size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                errorMessage,
                                style: TextStyle(color: Colors.red[700]),
                              ),
                            ),
                          ],
                        ),
                      )
                    : const SizedBox.shrink(),
                );
              },
            ),
            
            const SizedBox(height: 8),
            
            // User display name selector
            Selector<AuthProvider, String>(
              selector: (context, authProvider) => authProvider.userDisplayName,
              builder: (context, userDisplayName, child) {
                return userDisplayName.isNotEmpty
                  ? Chip(
                      avatar: const Icon(Icons.person, size: 18),
                      label: Text(userDisplayName),
                      backgroundColor: Colors.blue[50],
                    )
                  : const SizedBox.shrink();
              },
            ),
          ],
        ),
      ),
    );
  }

  /// Authentication actions example
  Widget _buildAuthActionsExample() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Authentication Actions',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            
            // Sign in action
            Consumer<AuthProvider>(
              builder: (context, authProvider, child) {
                return ElevatedButton(
                  onPressed: authProvider.canAuthenticate
                    ? () => _performSignIn(context, authProvider)
                    : null,
                  child: const Text('Sign In'),
                );
              },
            ),
            
            const SizedBox(height: 8),
            
            // Sign out action
            Selector<AuthProvider, bool>(
              selector: (context, authProvider) => authProvider.isAuthenticated,
              builder: (context, isAuthenticated, child) {
                return ElevatedButton(
                  onPressed: isAuthenticated
                    ? () => _performSignOut(context)
                    : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red[100],
                    foregroundColor: Colors.red[800],
                  ),
                  child: const Text('Sign Out'),
                );
              },
            ),
            
            const SizedBox(height: 8),
            
            // Clear error action
            Selector<AuthProvider, bool>(
              selector: (context, authProvider) => authProvider.hasError,
              builder: (context, hasError, child) {
                return TextButton(
                  onPressed: hasError
                    ? () => context.read<AuthProvider>().clearError()
                    : null,
                  child: const Text('Clear Error'),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  /// Example sign in implementation
  Future<void> _performSignIn(BuildContext context, AuthProvider authProvider) async {
    final success = await authProvider.signIn(
      email: 'test@example.com',
      password: 'password123',
    );
    
    if (success && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Sign in successful!'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  /// Example sign out implementation
  Future<void> _performSignOut(BuildContext context) async {
    final authProvider = context.read<AuthProvider>();
    final success = await authProvider.signOut();
    
    if (success && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Signed out successfully!'),
          backgroundColor: Colors.blue,
        ),
      );
    }
  }
}

/// Example of a state-based widget that automatically switches content
class StateBasedAuthWidget extends StatelessWidget {
  const StateBasedAuthWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, authProvider, child) {
        // Handle each authentication state
        switch (authProvider.state) {
          case AuthState.initial:
            return const _SplashWidget();
            
          case AuthState.loading:
            return const _LoadingWidget();
            
          case AuthState.authenticated:
            return _AuthenticatedWidget(user: authProvider.currentUser!);
            
          case AuthState.unauthenticated:
            return const _UnauthenticatedWidget();
            
          case AuthState.error:
            return _ErrorWidget(
              message: authProvider.errorMessage ?? 'Unknown error',
              onRetry: () => authProvider.checkAuthStatus(),
              onClearError: () => authProvider.clearError(),
            );
        }
      },
    );
  }
}

// Helper widgets for different states
class _SplashWidget extends StatelessWidget {
  const _SplashWidget();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          FlutterLogo(size: 64),
          SizedBox(height: 16),
          Text('Initializing...'),
        ],
      ),
    );
  }
}

class _LoadingWidget extends StatelessWidget {
  const _LoadingWidget();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text('Loading...'),
        ],
      ),
    );
  }
}

class _AuthenticatedWidget extends StatelessWidget {
  final dynamic user; // Replace with your User entity type
  
  const _AuthenticatedWidget({required this.user});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.check_circle, color: Colors.green, size: 64),
          const SizedBox(height: 16),
          Text('Welcome!'),
          Text('User: ${user.toString()}'),
        ],
      ),
    );
  }
}

class _UnauthenticatedWidget extends StatelessWidget {
  const _UnauthenticatedWidget();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.login, size: 64),
          SizedBox(height: 16),
          Text('Please sign in'),
        ],
      ),
    );
  }
}

class _ErrorWidget extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  final VoidCallback onClearError;

  const _ErrorWidget({
    required this.message,
    required this.onRetry,
    required this.onClearError,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error, color: Colors.red, size: 64),
          const SizedBox(height: 16),
          Text('Error: $message'),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton(
                onPressed: onRetry,
                child: const Text('Retry'),
              ),
              const SizedBox(width: 8),
              TextButton(
                onPressed: onClearError,
                child: const Text('Clear'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}