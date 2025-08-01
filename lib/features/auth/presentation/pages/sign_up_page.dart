import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../../domain/value_objects/email.dart';
import '../../domain/value_objects/password.dart';

/// Sign-up page with Material 3 design and accessibility compliance
/// 
/// Features:
/// - Material 3 design using app theme
/// - Real-time validation with email and password value objects
/// - Password strength indicator
/// - Password confirmation validation
/// - Reactive state management with Consumer<AuthProvider>
/// - Comprehensive accessibility support
/// - Responsive design for various screen sizes
/// - Loading states and error handling
/// - Social login UI preparation
/// - Terms and privacy policy acknowledgment
/// - Form submission with AuthProvider integration
class SignUpPage extends StatefulWidget {
  const SignUpPage({super.key});

  @override
  State<SignUpPage> createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignUpPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _emailFocusNode = FocusNode();
  final _passwordFocusNode = FocusNode();
  final _confirmPasswordFocusNode = FocusNode();
  
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _acceptTerms = false;
  
  // Real-time validation states
  String? _emailError;
  String? _passwordError;
  String? _confirmPasswordError;
  bool _isEmailValid = false;
  bool _isPasswordValid = false;
  bool _isConfirmPasswordValid = false;
  Password? _currentPassword;

  @override
  void initState() {
    super.initState();
    
    // Add listeners for real-time validation
    _emailController.addListener(_validateEmail);
    _passwordController.addListener(_validatePassword);
    _confirmPasswordController.addListener(_validateConfirmPassword);
  }

  @override
  void dispose() {
    _emailController.removeListener(_validateEmail);
    _passwordController.removeListener(_validatePassword);
    _confirmPasswordController.removeListener(_validateConfirmPassword);
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _emailFocusNode.dispose();
    _passwordFocusNode.dispose();
    _confirmPasswordFocusNode.dispose();
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
        _currentPassword = null;
      });
      _validateConfirmPassword(); // Re-validate confirm password
      return;
    }

    final passwordResult = Password.create(passwordText);
    setState(() {
      _passwordError = passwordResult.fold(
        (failure) => failure.message,
        (password) {
          _currentPassword = password;
          return null;
        },
      );
      _isPasswordValid = passwordResult.isRight();
    });
    _validateConfirmPassword(); // Re-validate confirm password when password changes
  }

  /// Real-time password confirmation validation
  void _validateConfirmPassword() {
    final confirmPasswordText = _confirmPasswordController.text;
    if (confirmPasswordText.isEmpty) {
      setState(() {
        _confirmPasswordError = null;
        _isConfirmPasswordValid = false;
      });
      return;
    }

    if (_currentPassword == null) {
      setState(() {
        _confirmPasswordError = 'Please enter password first';
        _isConfirmPasswordValid = false;
      });
      return;
    }

    final isMatching = _currentPassword!.value == confirmPasswordText;
    setState(() {
      _confirmPasswordError = isMatching ? null : 'Passwords do not match';
      _isConfirmPasswordValid = isMatching;
    });
  }

  /// Handle form submission
  Future<void> _handleSignUp() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (!_acceptTerms) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please accept the Terms and Privacy Policy'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Theme.of(context).colorScheme.error,
          showCloseIcon: true,
        ),
      );
      return;
    }

    // Provide haptic feedback
    HapticFeedback.lightImpact();

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    
    final success = await authProvider.signUp(
      email: _emailController.text.trim(),
      password: _passwordController.text,
      metadata: {
        'signup_source': 'mobile_app',
        'timestamp': DateTime.now().toIso8601String(),
      },
    );

    if (mounted) {
      if (success) {
        // Show success feedback
        HapticFeedback.selectionClick();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Account created successfully! Welcome to InsightFlo!'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Theme.of(context).colorScheme.primary,
            showCloseIcon: true,
            duration: const Duration(seconds: 4),
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
              duration: const Duration(seconds: 6),
            ),
          );
        }
      }
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
                        
                        const SizedBox(height: 32),
                        
                        // Sign-up Form
                        Expanded(
                          child: _buildSignUpForm(context, authProvider),
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
        const SizedBox(height: 16),
        // App Icon/Logo
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Icon(
            Icons.insights_rounded,
            size: 40,
            color: Theme.of(context).colorScheme.onPrimaryContainer,
            semanticLabel: 'InsightFlo Logo',
          ),
        ),
        const SizedBox(height: 20),
        Text(
          'Create Account',
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.onSurface,
          ),
          semanticsLabel: 'Create your InsightFlo account',
        ),
        const SizedBox(height: 8),
        Text(
          'Join InsightFlo to stay informed',
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  /// Build main sign-up form
  Widget _buildSignUpForm(BuildContext context, AuthProvider authProvider) {
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
          
          const SizedBox(height: 16),
          
          // Confirm Password Field
          _buildConfirmPasswordField(context),
          
          const SizedBox(height: 20),
          
          // Terms and Privacy Policy Checkbox
          _buildTermsCheckbox(context),
          
          const SizedBox(height: 24),
          
          // Sign Up Button
          _buildSignUpButton(context, authProvider),
          
          const SizedBox(height: 20),
          
          // Divider
          _buildDivider(context),
          
          const SizedBox(height: 20),
          
          // Social Login Buttons
          _buildSocialLoginButtons(context),
        ],
      ),
    );
  }

  /// Build email input field with validation
  Widget _buildEmailField(BuildContext context) {
    return TextFormField(
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
    );
  }

  /// Build password input field with validation and strength indicator
  Widget _buildPasswordField(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          controller: _passwordController,
          focusNode: _passwordFocusNode,
          obscureText: _obscurePassword,
          textInputAction: TextInputAction.next,
          autofillHints: const [AutofillHints.newPassword],
          decoration: InputDecoration(
            labelText: 'Password',
            hintText: 'Create a strong password',
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
            _confirmPasswordFocusNode.requestFocus();
          },
        ),
        
        // Password Strength Indicator
        if (_currentPassword != null) ...[
          const SizedBox(height: 8),
          _buildPasswordStrengthIndicator(context, _currentPassword!),
        ],
      ],
    );
  }

  /// Build password strength indicator
  Widget _buildPasswordStrengthIndicator(BuildContext context, Password password) {
    final strength = password.strength;
    final score = password.strengthScore;
    
    Color getStrengthColor() {
      switch (strength) {
        case PasswordStrength.veryWeak:
          return Theme.of(context).colorScheme.error;
        case PasswordStrength.weak:
          return Colors.orange;
        case PasswordStrength.medium:
          return Colors.amber;
        case PasswordStrength.strong:
          return Theme.of(context).colorScheme.primary;
      }
    }
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: LinearProgressIndicator(
                value: score / 100,
                backgroundColor: Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
                valueColor: AlwaysStoppedAnimation<Color>(getStrengthColor()),
                minHeight: 4,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              strength.label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: getStrengthColor(),
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'Password Requirements: 8+ chars, uppercase, lowercase, number, special char',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  /// Build confirm password input field
  Widget _buildConfirmPasswordField(BuildContext context) {
    return TextFormField(
      controller: _confirmPasswordController,
      focusNode: _confirmPasswordFocusNode,
      obscureText: _obscureConfirmPassword,
      textInputAction: TextInputAction.done,
      autofillHints: const [AutofillHints.newPassword],
      decoration: InputDecoration(
        labelText: 'Confirm password',
        hintText: 'Re-enter your password',
        prefixIcon: Icon(
          Icons.lock_outline,
          semanticLabel: 'Confirm password icon',
        ),
        suffixIcon: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_isConfirmPasswordValid)
              Icon(
                Icons.check_circle_outline,
                color: Theme.of(context).colorScheme.primary,
                semanticLabel: 'Passwords match',
              ),
            IconButton(
              icon: Icon(
                _obscureConfirmPassword ? Icons.visibility : Icons.visibility_off,
                semanticLabel: _obscureConfirmPassword ? 'Show password' : 'Hide password',
              ),
              onPressed: () {
                setState(() {
                  _obscureConfirmPassword = !_obscureConfirmPassword;
                });
              },
            ),
          ],
        ),
        errorText: _confirmPasswordError,
        border: const OutlineInputBorder(),
      ),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Please confirm your password';
        }
        return _confirmPasswordError;
      },
      onFieldSubmitted: (_) {
        _handleSignUp();
      },
    );
  }

  /// Build terms and privacy policy checkbox
  Widget _buildTermsCheckbox(BuildContext context) {
    return CheckboxListTile(
      value: _acceptTerms,
      onChanged: (value) {
        setState(() {
          _acceptTerms = value ?? false;
        });
      },
      title: Wrap(
        children: [
          Text(
            'I agree to the ',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          GestureDetector(
            onTap: () {
              // TODO: Show Terms of Service
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Terms of Service - Coming Soon'),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
            child: Text(
              'Terms of Service',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.primary,
                decoration: TextDecoration.underline,
              ),
            ),
          ),
          Text(
            ' and ',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          GestureDetector(
            onTap: () {
              // TODO: Show Privacy Policy
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Privacy Policy - Coming Soon'),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
            child: Text(
              'Privacy Policy',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.primary,
                decoration: TextDecoration.underline,
              ),
            ),
          ),
        ],
      ),
      controlAffinity: ListTileControlAffinity.leading,
      contentPadding: EdgeInsets.zero,
      visualDensity: VisualDensity.compact,
    );
  }

  /// Build sign-up button with loading state
  Widget _buildSignUpButton(BuildContext context, AuthProvider authProvider) {
    final isLoading = authProvider.isLoading;
    final canSubmit = _isEmailValid && 
                     _isPasswordValid && 
                     _isConfirmPasswordValid && 
                     _acceptTerms && 
                     !isLoading;
    
    return FilledButton(
      onPressed: canSubmit ? _handleSignUp : null,
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
              'Create Account',
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
        // Google Sign Up Button
        OutlinedButton.icon(
          onPressed: () {
            // TODO: Implement Google Sign Up
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Google Sign Up - Coming Soon'),
                behavior: SnackBarBehavior.floating,
              ),
            );
          },
          icon: Icon(
            Icons.g_mobiledata_rounded,
            size: 24,
            semanticLabel: 'Google logo',
          ),
          label: const Text('Sign up with Google'),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        
        const SizedBox(height: 12),
        
        // Apple Sign Up Button  
        OutlinedButton.icon(
          onPressed: () {
            // TODO: Implement Apple Sign Up
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Apple Sign Up - Coming Soon'),
                behavior: SnackBarBehavior.floating,
              ),
            );
          },
          icon: Icon(
            Icons.apple,
            size: 24,
            semanticLabel: 'Apple logo',
          ),
          label: const Text('Sign up with Apple'),
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

  /// Build footer with sign-in link
  Widget _buildFooter(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'Already have an account? ',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pushReplacementNamed('/sign-in');
            },
            child: Text(
              'Sign In',
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