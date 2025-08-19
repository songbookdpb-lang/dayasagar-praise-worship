import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../auth/auth_service.dart';

class AdminLoginScreen extends ConsumerStatefulWidget {
  const AdminLoginScreen({super.key});

  @override
  ConsumerState<AdminLoginScreen> createState() => _AdminLoginScreenState();
}

class _AdminLoginScreenState extends ConsumerState<AdminLoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _emailFocusNode = FocusNode();
  final _passwordFocusNode = FocusNode();
  
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _isResetPasswordLoading = false;
  String? _emailError;
  String? _passwordError;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _emailFocusNode.dispose();
    _passwordFocusNode.dispose();
    super.dispose();
  }

  // Email validation
  String? _validateEmail(String? value) {
    if (value == null || value.isEmpty) {
      return 'Email is required';
    }
    
    final emailRegex = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');
    if (!emailRegex.hasMatch(value)) {
      return 'Please enter a valid email address';
    }

    
    return null;
  }

  // Password validation
  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Password is required';
    }
    
    if (value.length < 6) {
      return 'Password must be at least 6 characters';
    }
    
    return null;
  }

  Future<void> _login() async {
    setState(() {
      _emailError = null;
      _passwordError = null;
    });
    if (!_formKey.currentState!.validate()) {
      _showSnackbar('Please fix the errors above', SnackBarType.error);
      return;
    }
    setState(() => _isLoading = true);
    HapticFeedback.lightImpact();
    try {
      await ref.read(authServiceProvider).signInWithEmailAndPassword(
        _emailController.text.trim(),
        _passwordController.text,
      );
      
      if (mounted) {
        _showSnackbar('Login successful! Welcome back.', SnackBarType.success);
        await Future.delayed(const Duration(milliseconds: 500));
        
        if (mounted) {
          context.go('/admin');
        }
      }
    } catch (e) {
      if (mounted) {
        _handleLoginError(e);
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
  void _handleLoginError(dynamic error) {
    String errorMessage = 'Login failed. Please try again.';
    SnackBarType type = SnackBarType.error;

    final errorString = error.toString().toLowerCase();

    if (errorString.contains('user-not-found')) {
      errorMessage = 'No admin account found with this email address.';
      setState(() => _emailError = 'Account not found');
    } else if (errorString.contains('wrong-password') || errorString.contains('invalid-credential')) {
      errorMessage = 'Incorrect password. Please try again.';
      setState(() => _passwordError = 'Incorrect password');
    } else if (errorString.contains('invalid-email')) {
      errorMessage = 'Please enter a valid email address.';
      setState(() => _emailError = 'Invalid email format');
    } else if (errorString.contains('user-disabled')) {
      errorMessage = 'This admin account has been disabled. Contact support.';
      type = SnackBarType.warning;
    } else if (errorString.contains('too-many-requests')) {
      errorMessage = 'Too many failed attempts. Please try again later.';
      type = SnackBarType.warning;
    } else if (errorString.contains('network')) {
      errorMessage = 'Network error. Please check your connection.';
      type = SnackBarType.warning;
    } else if (errorString.contains('weak-password')) {
      errorMessage = 'Password is too weak. Please use a stronger password.';
      setState(() => _passwordError = 'Password too weak');
    }

    _showSnackbar(errorMessage, type);
    HapticFeedback.heavyImpact();
  }

  // Forgot password function
  Future<void> _forgotPassword() async {
    // Validate email first
    if (_emailController.text.isEmpty) {
      _showSnackbar('Please enter your email address first', SnackBarType.warning);
      _emailFocusNode.requestFocus();
      return;
    }

    final emailValidation = _validateEmail(_emailController.text);
    if (emailValidation != null) {
      _showSnackbar(emailValidation, SnackBarType.error);
      _emailFocusNode.requestFocus();
      return;
    }

    setState(() => _isResetPasswordLoading = true);
    HapticFeedback.lightImpact();

    try {
      await ref.read(authServiceProvider).sendPasswordResetEmail(
        _emailController.text.trim(),
      );
      
      if (mounted) {
        _showResetPasswordDialog();
      }
    } catch (e) {
      if (mounted) {
        _handleResetPasswordError(e);
      }
    } finally {
      if (mounted) {
        setState(() => _isResetPasswordLoading = false);
      }
    }
  }

  // Handle password reset errors
  void _handleResetPasswordError(dynamic error) {
    String errorMessage = 'Failed to send reset email. Please try again.';
    
    final errorString = error.toString().toLowerCase();
    
    if (errorString.contains('user-not-found')) {
      errorMessage = 'No admin account found with this email address.';
    } else if (errorString.contains('invalid-email')) {
      errorMessage = 'Please enter a valid email address.';
    } else if (errorString.contains('too-many-requests')) {
      errorMessage = 'Too many reset requests. Please wait before trying again.';
    }
    
    _showSnackbar(errorMessage, SnackBarType.error);
  }

  // Show reset password success dialog
  void _showResetPasswordDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        final theme = Theme.of(context);
        final isDark = theme.brightness == Brightness.dark;
        
        return AlertDialog(
          backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              const Icon(
                Icons.mark_email_read,
                color: Colors.green,
                size: 28,
              ),
              const SizedBox(width: 12),
              Text(
                'Email Sent',
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : const Color(0xFF1F2937),
                ),
              ),
            ],
          ),
          content: Text(
            'A password reset link has been sent to ${_emailController.text}.\n\nPlease check your email and follow the instructions to reset your password.',
            style: GoogleFonts.inter(
              color: isDark ? Colors.white70 : const Color(0xFF6B7280),
              height: 1.5,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _showSnackbar('Password reset email sent successfully', SnackBarType.success);
              },
              child: Text(
                'OK',
                style: GoogleFonts.inter(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  // Enhanced snackbar with different types
  void _showSnackbar(String message, SnackBarType type) {
    Color backgroundColor;
    IconData icon;
    
    switch (type) {
      case SnackBarType.success:
        backgroundColor = Colors.green.shade600;
        icon = Icons.check_circle;
        break;
      case SnackBarType.warning:
        backgroundColor = Colors.orange.shade600;
        icon = Icons.warning;
        break;
      case SnackBarType.error:
      default:
        backgroundColor = Colors.red.shade600;
        icon = Icons.error;
        break;
    }

    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(icon, color: Colors.white, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: backgroundColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        duration: Duration(seconds: type == SnackBarType.success ? 2 : 4),
        action: SnackBarAction(
          label: 'Dismiss',
          textColor: Colors.white,
          onPressed: () {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
          },
        ),
      ),
    );
  }

  // Quick fill demo credentials (remove in production)
  void _fillDemoCredentials() {
    _emailController.text = 'admin@example.com';
    _passwordController.text = 'admin123';
    setState(() {
      _emailError = null;
      _passwordError = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final screenSize = MediaQuery.of(context).size;
    
    return Scaffold(
      // Full screen AppBar with transparent background
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
          statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
        ),
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back,
            color: isDark ? Colors.white : const Color(0xFF1F2937),
          ),
          onPressed: () {
            HapticFeedback.lightImpact();
            context.go('/');
          },
        ),
        actions: [
          // Demo credentials button (remove in production)
          if (true) // Set to false in production
            IconButton(
              icon: Icon(
                Icons.science,
                color: isDark ? Colors.white70 : const Color(0xFF6B7280),
              ),
              onPressed: _fillDemoCredentials,
              tooltip: 'Fill demo credentials',
            ),
        ],
      ),
      extendBodyBehindAppBar: true,
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: isDark
              ? [
                  const Color(0xFF0F172A),
                  const Color(0xFF1E293B),
                  const Color(0xFF334155),
                ]
              : [
                  const Color(0xFFE2E8F0),
                  const Color(0xFF94A3B8),
                  const Color(0xFF475569),
                ],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32.0),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    // Top spacing
                    SizedBox(height: screenSize.height * 0.05),
                    
                    // Admin Login Header
                    Column(
                      children: [
                        Hero(
                          tag: 'admin_icon',
                          child: Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.1),
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.1),
                                  blurRadius: 20,
                                  offset: const Offset(0, 10),
                                ),
                              ],
                            ),
                            child: Icon(
                              Icons.admin_panel_settings,
                              size: 60,
                              color: isDark ? Colors.white : const Color(0xFF1F2937),
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        Text(
                          'Admin Portal',
                          style: GoogleFonts.inter(
                            fontSize: 32,
                            fontWeight: FontWeight.w700,
                            color: isDark ? Colors.white : const Color(0xFF1F2937),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Secure access to administrative features',
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: (isDark ? Colors.white : const Color(0xFF1F2937)).withValues(alpha: 0.7),
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),

                    SizedBox(height: screenSize.height * 0.06),

                    // Login Form
                    Container(
                      padding: const EdgeInsets.all(32),
                      decoration: BoxDecoration(
                        color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.1),
                          width: 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 20,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Email Field
                          TextFormField(
                            controller: _emailController,
                            focusNode: _emailFocusNode,
                            validator: _validateEmail,
                            style: GoogleFonts.inter(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                              color: isDark ? Colors.white : const Color(0xFF1F2937),
                            ),
                            decoration: InputDecoration(
                              labelText: 'Admin Email',
                              labelStyle: GoogleFonts.inter(
                                color: (isDark ? Colors.white : const Color(0xFF1F2937)).withValues(alpha: 0.6),
                                fontWeight: FontWeight.w500,
                              ),
                              prefixIcon: Icon(
                                Icons.email_outlined,
                                color: (isDark ? Colors.white : const Color(0xFF1F2937)).withValues(alpha: 0.6),
                              ),
                              errorText: _emailError,
                              errorStyle: GoogleFonts.inter(
                                color: Colors.red.shade400,
                                fontWeight: FontWeight.w500,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.2),
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.2),
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: theme.colorScheme.primary,
                                  width: 2,
                                ),
                              ),
                              errorBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: Colors.red.shade400,
                                  width: 1,
                                ),
                              ),
                              focusedErrorBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: Colors.red.shade400,
                                  width: 2,
                                ),
                              ),
                              filled: true,
                              fillColor: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.05),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                            ),
                            keyboardType: TextInputType.emailAddress,
                            textInputAction: TextInputAction.next,
                            onFieldSubmitted: (_) => _passwordFocusNode.requestFocus(),
                            onChanged: (_) {
                              if (_emailError != null) {
                                setState(() => _emailError = null);
                              }
                            },
                          ),
                          
                          const SizedBox(height: 20),
                          
                          // Password Field
                          TextFormField(
                            controller: _passwordController,
                            focusNode: _passwordFocusNode,
                            validator: _validatePassword,
                            style: GoogleFonts.inter(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                              color: isDark ? Colors.white : const Color(0xFF1F2937),
                            ),
                            decoration: InputDecoration(
                              labelText: 'Password',
                              labelStyle: GoogleFonts.inter(
                                color: (isDark ? Colors.white : const Color(0xFF1F2937)).withValues(alpha: 0.6),
                                fontWeight: FontWeight.w500,
                              ),
                              prefixIcon: Icon(
                                Icons.lock_outlined,
                                color: (isDark ? Colors.white : const Color(0xFF1F2937)).withValues(alpha: 0.6),
                              ),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscurePassword ? Icons.visibility : Icons.visibility_off,
                                  color: (isDark ? Colors.white : const Color(0xFF1F2937)).withValues(alpha: 0.6),
                                ),
                                onPressed: () {
                                  setState(() {
                                    _obscurePassword = !_obscurePassword;
                                  });
                                  HapticFeedback.selectionClick();
                                },
                              ),
                              errorText: _passwordError,
                              errorStyle: GoogleFonts.inter(
                                color: Colors.red.shade400,
                                fontWeight: FontWeight.w500,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.2),
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.2),
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: theme.colorScheme.primary,
                                  width: 2,
                                ),
                              ),
                              errorBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: Colors.red.shade400,
                                  width: 1,
                                ),
                              ),
                              focusedErrorBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: Colors.red.shade400,
                                  width: 2,
                                ),
                              ),
                              filled: true,
                              fillColor: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.05),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                            ),
                            obscureText: _obscurePassword,
                            textInputAction: TextInputAction.done,
                            onFieldSubmitted: (_) => _login(),
                            onChanged: (_) {
                              if (_passwordError != null) {
                                setState(() => _passwordError = null);
                              }
                            },
                          ),
                          
                          const SizedBox(height: 16),
                          
                          // Forgot Password Link
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              onPressed: _isResetPasswordLoading ? null : _forgotPassword,
                              child: _isResetPasswordLoading
                                  ? SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: theme.colorScheme.primary,
                                      ),
                                    )
                                  : Text(
                                      'Forgot Password?',
                                      style: GoogleFonts.inter(
                                        color: theme.colorScheme.primary,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 14,
                                      ),
                                    ),
                            ),
                          ),
                          
                          const SizedBox(height: 16),
                          
                          // Login Button
                          SizedBox(
                            height: 56,
                            child: ElevatedButton(
                              onPressed: _isLoading ? null : _login,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: theme.colorScheme.primary,
                                disabledBackgroundColor: theme.colorScheme.primary.withValues(alpha: 0.6),
                                elevation: 0,
                                shadowColor: Colors.transparent,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: _isLoading
                                  ? Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        const SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(
                                            color: Colors.white,
                                            strokeWidth: 2,
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Text(
                                          'Signing In...',
                                          style: GoogleFonts.inter(
                                            color: Colors.white,
                                            fontSize: 16,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    )
                                  : Text(
                                      'Sign In',
                                      style: GoogleFonts.inter(
                                        color: Colors.white,
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    // Bottom spacing
                    SizedBox(height: screenSize.height * 0.05),
                    
                    // Security Notice
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: (isDark ? Colors.blue : Colors.blue.shade50).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.blue.withValues(alpha: 0.2),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.security,
                            color: Colors.blue,
                            size: 20,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'This is a secure admin portal. All activities are logged.',
                              style: GoogleFonts.inter(
                                color: isDark ? Colors.blue.shade200 : Colors.blue.shade700,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

enum SnackBarType {
  success,
  error,
  warning,
}
