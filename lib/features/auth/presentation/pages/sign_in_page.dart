import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../../domain/value_objects/email.dart';  
import '../../domain/value_objects/password.dart';

/// Sign-in page with Material 3 design and accessibility compliance
/// 
/// Features:
/// - Material 3 design using app theme
/// - Real-time validation with email and password value objects
/// - Reactive state management with Consumer<AuthProvider>
/// - Comprehensive accessibility support
/// - Responsive design for various screen sizes
/// - Loading states and error handling
/// - Social login UI preparation
/// - Form submission with AuthProvider integration
class SignInPage extends StatefulWidget {
  const SignInPage({super.key});

  @override
  State<SignInPage> createState() => _SignInPageState();
}

class _SignInPageState extends State<SignInPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _emailFocusNode = FocusNode();
  final _passwordFocusNode = FocusNode();
  
  bool _obscurePassword = true;
  bool _rememberMe = false;
  
  // Real-time validation states
  String? _emailError;
  String? _passwordError;
  bool _isEmailValid = false;
  bool _isPasswordValid = false;

  @override
  void initState() {
    super.initState();
    
    // Add listeners for real-time validation
    _emailController.addListener(_validateEmail);
    _passwordController.addListener(_validatePassword);
  }

  @override
  void dispose() {
    _emailController.removeListener(_validateEmail);
    _passwordController.removeListener(_validatePassword);
    _emailController.dispose();
    _passwordController.dispose();
    _emailFocusNode.dispose();
    _passwordFocusNode.dispose();
    super.dispose();
  }

  /// Real-time email validation
  void _validateEmail() {
    final emailText = _emailController.text;
    if (emailText.isEmpty) {
      setState(() {
        _emailError = null;
        _isEmailValid = false;
      });
      return;
    }

    final emailResult = Email.create(emailText);
    setState(() {
      _emailError = emailResult.fold(
        (failure) => failure.message,
        (_) => null,
      );
      _isEmailValid = emailResult.isRight();
    });
  }

  /// Real-time password validation
  void _validatePassword() {
    final passwordText = _passwordController.text;
    if (passwordText.isEmpty) {
      setState(() {
        _passwordError = null;
        _isPasswordValid = false;
      });
      return;
    }

    final passwordResult = Password.create(passwordText);
    setState(() {
      _passwordError = passwordResult.fold(
        (failure) => failure.message,
        (_) => null,
      );
      _isPasswordValid = passwordResult.isRight();
    });
  }

  /// Handle form submission
  Future<void> _handleSignIn() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // Provide haptic feedback
    HapticFeedback.lightImpact();

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    
    final success = await authProvider.signIn(
      email: _emailController.text.trim(),
      password: _passwordController.text,
      rememberMe: _rememberMe,
    );

    if (mounted) {
      if (success) {
        // Show success feedback
        HapticFeedback.selectionClick();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Welcome back!'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Theme.of(context).colorScheme.primary,
            showCloseIcon: true,
          ),
        );
        // Navigation to home will be handled by parent widget based on auth state
      } else {
        // Show error message
        HapticFeedback.vibrate();
        if (authProvider.errorMessage != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(authProvider.errorMessage!),
              behavior: SnackBarBehavior.floating,
              backgroundColor: Theme.of(context).colorScheme.error,
              showCloseIcon: true,
              duration: const Duration(seconds: 5),
            ),
          );
        }
      }
    }
  }

  /// Handle forgot password
  Future<void> _handleForgotPassword() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter your email address first'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      _emailFocusNode.requestFocus();
      return;
    }

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final success = await authProvider.resetPassword(email: email);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success
                ? 'Password reset email sent! Check your inbox.'
                : authProvider.errorMessage ?? 'Failed to send reset email',
          ),
          behavior: SnackBarBehavior.floating,
          backgroundColor: success
              ? Theme.of(context).colorScheme.primary
              : Theme.of(context).colorScheme.error,
          showCloseIcon: true,
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Consumer<AuthProvider>(
          builder: (context, authProvider, child) {
            return CustomScrollView(
              slivers: [
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      children: [
                        // Header Section
                        _buildHeader(context),
                        
                        const SizedBox(height: 48),
                        
                        // Sign-in Form
                        Expanded(
                          child: _buildSignInForm(context, authProvider),
                        ),
                        
                        // Footer Section
                        _buildFooter(context),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  /// Build header section with app branding
  Widget _buildHeader(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 32),
        // App Icon/Logo
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Icon(
            Icons.insights_rounded,
            size: 48,
            color: Theme.of(context).colorScheme.onPrimaryContainer,
            semanticLabel: 'InsightFlo Logo',
          ),
        ),
        const SizedBox(height: 24),
        Text(
          'Welcome Back',
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.onSurface,
          ),
          semanticsLabel: 'Welcome back to InsightFlo',
        ),
        const SizedBox(height: 8),
        Text(
          'Sign in to your InsightFlo account',
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  /// Build main sign-in form
  Widget _buildSignInForm(BuildContext context, AuthProvider authProvider) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Email Field
          _buildEmailField(context),
          
          const SizedBox(height: 16),
          
          // Password Field
          _buildPasswordField(context),
          
          const SizedBox(height: 24),
          
          // Remember Me & Forgot Password Row
          _buildRememberMeAndForgotPassword(context),
          
          const SizedBox(height: 32),
          
          // Sign In Button
          _buildSignInButton(context, authProvider),
          
          const SizedBox(height: 24),
          
          // Divider
          _buildDivider(context),
          
          const SizedBox(height: 24),
          
          // Social Login Buttons
          _buildSocialLoginButtons(context),
        ],
      ),
    );
  }

  /// Build email input field with validation
  Widget _buildEmailField(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          controller: _emailController,
          focusNode: _emailFocusNode,
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.next,
          autocorrect: false,
          enableSuggestions: true,
          autofillHints: const [AutofillHints.email],
          decoration: InputDecoration(
            labelText: 'Email address',
            hintText: 'Enter your email',
            prefixIcon: Icon(
              Icons.email_outlined,
              semanticLabel: 'Email icon',
            ),
            suffixIcon: _isEmailValid
                ? Icon(
                    Icons.check_circle_outline,
                    color: Theme.of(context).colorScheme.primary,
                    semanticLabel: 'Valid email',
                  )
                : null,
            errorText: _emailError,
            border: const OutlineInputBorder(),
          ),
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Email is required';
            }
            return _emailError;
          },
          onFieldSubmitted: (_) {
            _passwordFocusNode.requestFocus();
          },
        ),
      ],
    );
  }

  /// Build password input field with validation
  Widget _buildPasswordField(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          controller: _passwordController,
          focusNode: _passwordFocusNode,
          obscureText: _obscurePassword,
          textInputAction: TextInputAction.done,
          autofillHints: const [AutofillHints.password],
          decoration: InputDecoration(
            labelText: 'Password',
            hintText: 'Enter your password',
            prefixIcon: Icon(
              Icons.lock_outline,
              semanticLabel: 'Password icon',
            ),
            suffixIcon: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_isPasswordValid)
                  Icon(
                    Icons.check_circle_outline,
                    color: Theme.of(context).colorScheme.primary,
                    semanticLabel: 'Valid password',
                  ),
                IconButton(
                  icon: Icon(
                    _obscurePassword ? Icons.visibility : Icons.visibility_off,
                    semanticLabel: _obscurePassword ? 'Show password' : 'Hide password',
                  ),
                  onPressed: () {
                    setState(() {
                      _obscurePassword = !_obscurePassword;
                    });
                  },
                ),
              ],
            ),
            errorText: _passwordError,
            border: const OutlineInputBorder(),
          ),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Password is required';
            }
            return _passwordError;
          },
          onFieldSubmitted: (_) {
            _handleSignIn();
          },
        ),
      ],
    );
  }

  /// Build remember me checkbox and forgot password link
  Widget _buildRememberMeAndForgotPassword(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: CheckboxListTile(
            value: _rememberMe,
            onChanged: (value) {
              setState(() {
                _rememberMe = value ?? false;
              });
            },
            title: Text(
              'Remember me',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            controlAffinity: ListTileControlAffinity.leading,
            contentPadding: EdgeInsets.zero,
            visualDensity: VisualDensity.compact,
          ),
        ),
        TextButton(
          onPressed: _handleForgotPassword,
          child: Text(
            'Forgot password?',
            style: TextStyle(
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
        ),
      ],
    );
  }

  /// Build sign-in button with loading state
  Widget _buildSignInButton(BuildContext context, AuthProvider authProvider) {
    final isLoading = authProvider.isLoading;
    final canSubmit = _isEmailValid && _isPasswordValid && !isLoading;
    
    return FilledButton(
      onPressed: canSubmit ? _handleSignIn : null,
      style: FilledButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      child: isLoading
          ? SizedBox(
              height: 20,
              width: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(
                  Theme.of(context).colorScheme.onPrimary,
                ),
              ),
            )
          : Text(
              'Sign In',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: Theme.of(context).colorScheme.onPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
    );
  }

  /// Build divider with "OR" text
  Widget _buildDivider(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Divider(
            color: Theme.of(context).colorScheme.outline,
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            'OR',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Expanded(
          child: Divider(
            color: Theme.of(context).colorScheme.outline,
          ),
        ),
      ],
    );
  }

  /// Build social login buttons (UI only - ready for implementation)
  Widget _buildSocialLoginButtons(BuildContext context) {
    return Column(
      children: [
        // Google Sign In Button
        OutlinedButton.icon(
          onPressed: () {
            // TODO: Implement Google Sign In
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Google Sign In - Coming Soon'),
                behavior: SnackBarBehavior.floating,
              ),
            );
          },
          icon: Icon(
            Icons.g_mobiledata_rounded,
            size: 24,
            semanticLabel: 'Google logo',
          ),
          label: const Text('Continue with Google'),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        
        const SizedBox(height: 12),
        
        // Apple Sign In Button  
        OutlinedButton.icon(
          onPressed: () {
            // TODO: Implement Apple Sign In
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Apple Sign In - Coming Soon'),
                behavior: SnackBarBehavior.floating,
              ),
            );
          },
          icon: Icon(
            Icons.apple,
            size: 24,
            semanticLabel: 'Apple logo',
          ),
          label: const Text('Continue with Apple'),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      ],
    );
  }

  /// Build footer with sign-up link
  Widget _buildFooter(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            "Don't have an account? ",
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pushReplacementNamed('/sign-up');
            },
            child: Text(
              'Sign Up',
              style: TextStyle(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}