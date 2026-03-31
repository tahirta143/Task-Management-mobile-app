import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../provider/auth_provider.dart';
import '../main_app_scaffold.dart';

import '../../../widgets/custom_loader.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _userController = TextEditingController();
  final TextEditingController _passController = TextEditingController();
  bool _showPassword = false;
  final _formKey = GlobalKey<FormState>();
  bool _isScreenLoading = true;

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 1000), () {
      if (mounted) setState(() => _isScreenLoading = false);
    });
  }

  @override
  void dispose() {
    _userController.dispose();
    _passController.dispose();
    super.dispose();
  }

  void _onLogin() async {
    if (_formKey.currentState!.validate()) {
      final username = _userController.text.trim();
      final password = _passController.text;

      try {
        await context.read<AuthProvider>().login(username, password);
        if (mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const MainAppScaffold()),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(e.toString()),
              backgroundColor: Colors.redAccent,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isScreenLoading) {
      return const Scaffold(body: CustomLoader(fullScreen: true));
    }

    final authState = context.watch<AuthProvider>();
    final th = Theme.of(context);
    final isDark = th.brightness == Brightness.dark;
    
    // Responsive Dimensions
    final sw = MediaQuery.of(context).size.width;
    final sh = MediaQuery.of(context).size.height;
    final top = MediaQuery.of(context).padding.top;

    return Scaffold(
      backgroundColor: th.scaffoldBackgroundColor,
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            children: [
              _buildHeader(sw, sh, top, th, isDark),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: sw * 0.055),
                child: Column(
                  children: [
                    const SizedBox(height: 24),
                    _buildFormCard(sw, sh, th, isDark, authState),
                    _buildDivider(sw, sh, th, isDark),
                    _buildSocialRow(sw, sh, th, isDark),
                    const SizedBox(height: 16),
                    _buildSignUpRow(sw, th),
                    const SizedBox(height: 12),
                    // _buildDeveloperCredit(sw, th),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(double sw, double sh, double top, ThemeData th, bool isDark) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(
        sw * 0.06,
        top + sh * 0.04,
        sw * 0.06,
        sh * 0.042,
      ),
      decoration: BoxDecoration(
        color: th.colorScheme.primary,
        borderRadius: BorderRadius.vertical(
          bottom: Radius.circular(sw * 0.09),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Frosted icon box
          Container(
            width: sw * 0.16,
            height: sw * 0.16,
            decoration: BoxDecoration(
              color: (isDark ? Colors.black : Colors.white).withAlpha(40),
              borderRadius: BorderRadius.circular(sw * 0.045),
              border: Border.all(
                color: (isDark ? Colors.black : Colors.white).withAlpha(70),
                width: 1.5,
              ),
            ),
            child: Icon(
              LucideIcons.lock,
              color: isDark ? Colors.white : Colors.black87,
              size: sw * 0.075,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Welcome Back',
            style: TextStyle(
              color: isDark ? Colors.white : Colors.black,
              fontSize: sw * 0.055,
              fontWeight: FontWeight.bold,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Sign in to your Enterprise Dashboard',
            style: TextStyle(
              color: (isDark ? Colors.white : Colors.black).withAlpha(150),
              fontSize: sw * 0.032,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFormCard(double sw, double sh, ThemeData th, bool isDark, AuthProvider authState) {
    return Container(
      padding: EdgeInsets.all(sw * 0.055),
      decoration: BoxDecoration(
        color: isDark ? th.colorScheme.surface : Colors.white,
        borderRadius: BorderRadius.circular(sw * 0.06),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(isDark ? 50 : 15),
            blurRadius: 20,
            offset: const Offset(0, 10),
          )
        ],
      ),
      child: Column(
        children: [
          _buildInputField(
            label: "USERNAME",
            hint: "Enter your username",
            controller: _userController,
            icon: LucideIcons.user,
            sw: sw, sh: sh, th: th, isDark: isDark,
            validator: (v) => (v == null || v.isEmpty) ? "Username is required" : null,
          ),
          const SizedBox(height: 20),
          _buildInputField(
            label: "PASSWORD",
            hint: "Enter your password",
            controller: _passController,
            icon: LucideIcons.lock,
            sw: sw, sh: sh, th: th, isDark: isDark,
            obscureText: !_showPassword,
            suffixIcon: IconButton(
              icon: Icon(
                _showPassword ? LucideIcons.eyeOff : LucideIcons.eye,
                color: isDark ? Colors.white54 : Colors.black45,
                size: sw * 0.05,
              ),
              onPressed: () => setState(() => _showPassword = !_showPassword),
            ),
            validator: (v) => (v == null || v.isEmpty) ? "Password is required" : null,
          ),
          
          // Forgot Password link
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () {}, // Not implemented yet
              child: Text(
                'Forgot Password?',
                style: TextStyle(color: th.colorScheme.primary, fontSize: sw * 0.032, fontWeight: FontWeight.bold),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Submit Button
          SizedBox(
            width: double.infinity,
            height: 54,
            child: ElevatedButton(
              onPressed: authState.isLoading ? null : _onLogin,
              style: ElevatedButton.styleFrom(
                backgroundColor: th.colorScheme.primary,
                foregroundColor: Colors.black, // Since theme primary is light teal
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: authState.isLoading
                  ? LoadingAnimationWidget.inkDrop(color: Colors.black, size: 24)
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text('Sign In', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        const SizedBox(width: 8),
                        Icon(LucideIcons.arrowRight, size: sw * 0.045),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputField({
    required String label,
    required String hint,
    required TextEditingController controller,
    required IconData icon,
    required double sw,
    required double sh,
    required ThemeData th,
    required bool isDark,
    bool obscureText = false,
    Widget? suffixIcon,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: isDark ? Colors.white60 : Colors.black54,
            fontSize: sw * 0.028,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.0,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          obscureText: obscureText,
          style: TextStyle(fontSize: sw * 0.038, fontWeight: FontWeight.w500),
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: Icon(icon, color: th.colorScheme.primary, size: sw * 0.05),
            suffixIcon: suffixIcon,
          ),
          validator: validator,
        ),
      ],
    );
  }

  Widget _buildDivider(double sw, double sh, ThemeData th, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Row(
        children: [
          Expanded(child: Divider(color: (isDark ? Colors.white : Colors.black).withAlpha(30))),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text("or continue with", style: TextStyle(color: Colors.grey, fontSize: sw * 0.03)),
          ),
          Expanded(child: Divider(color: (isDark ? Colors.white : Colors.black).withAlpha(30))),
        ],
      ),
    );
  }

  Widget _buildSocialRow(double sw, double sh, ThemeData th, bool isDark) {
    return Row(
      children: [
        Expanded(child: _buildSocialBtn("Google", LucideIcons.chrome, Colors.red, sw, sh, th, isDark)),
        const SizedBox(width: 12),
        Expanded(child: _buildSocialBtn("Apple", LucideIcons.apple, isDark ? Colors.white : Colors.black, sw, sh, th, isDark)),
      ],
    );
  }

  Widget _buildSocialBtn(String label, IconData icon, Color iconColor, double sw, double sh, ThemeData th, bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? th.colorScheme.surface : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(isDark ? 30 : 8),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: InkWell(
        onTap: () {},
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: iconColor, size: sw * 0.045),
              const SizedBox(width: 8),
              Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSignUpRow(double sw, ThemeData th) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text("Don't have an account?", style: TextStyle(color: Colors.grey, fontSize: 13)),
        TextButton(
          onPressed: () {}, // Not implemented yet
          child: Text("Sign Up", style: TextStyle(color: th.colorScheme.primary, fontWeight: FontWeight.bold, fontSize: 13)),
        ),
      ],
    );
  }

  // Widget _buildDeveloperCredit(double sw, ThemeData th) {
  //   return Row(
  //     mainAxisAlignment: MainAxisAlignment.center,
  //     children: [
  //       const Text("Developed by", style: TextStyle(color: Colors.grey, fontSize: 12)),
  //       const SizedBox(width: 4),
  //       InkWell(
  //         onTap: () async {
  //           final url = Uri.parse('https://afaqtechnologies.com.pk/');
  //           if (await canLaunchUrl(url)) {
  //             await launchUrl(url, mode: LaunchMode.externalApplication);
  //           }
  //         },
  //         child: Text(
  //           "Afaq Technologies",
  //           style: TextStyle(
  //             color: th.colorScheme.primary,
  //             fontWeight: FontWeight.bold,
  //             fontSize: 12,
  //             decoration: TextDecoration.underline,
  //           ),
  //         ),
  //       ),
  //     ],
  //   );
  // }
}