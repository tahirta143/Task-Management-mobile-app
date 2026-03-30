import 'dart:math';

import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';
import '../../../provider/admin_provider.dart';
import '../../../models/user_model.dart';

class AdminUsersScreen extends StatefulWidget {
  const AdminUsersScreen({super.key});

  @override
  State<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends State<AdminUsersScreen> {
  final _userController = TextEditingController();
  final _emailController = TextEditingController();
  final _passController = TextEditingController();
  
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AdminProvider>().fetchUsers();
    });
  }

  @override
  void dispose() {
    _userController.dispose();
    _emailController.dispose();
    _passController.dispose();
    super.dispose();
  }

  void _onCreateUser() async {
    if (_userController.text.isEmpty || _emailController.text.isEmpty || _passController.text.isEmpty) return;
    
    final ap = context.read<AdminProvider>();
    try {
      await ap.createUser({
        'username': _userController.text.trim(),
        'email': _emailController.text.trim(),
        'password': _passController.text,
        'role': 'user', // Default for now
      });
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  void _showAddUserPopup() {
    final th = Theme.of(context);
    final isDark = th.brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final double width = MediaQuery.of(context).size.width;
        final double modalWidth = min(width * 0.95, 500);

        return Center(
          child: Container(
            width: modalWidth,
            height: MediaQuery.of(context).size.height * 0.85,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: th.scaffoldBackgroundColor,
              borderRadius: const BorderRadius.only(topLeft: Radius.circular(32), topRight: Radius.circular(32)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 24),
                    decoration: BoxDecoration(color: Colors.grey.withAlpha(100), borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Create staff user', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                    IconButton(icon: const Icon(LucideIcons.x), onPressed: () => Navigator.pop(ctx)),
                  ],
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: ListView(
                    children: [
                      Center(
                        child: Container(
                          height: 96,
                          width: 96,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.grey.withAlpha(100), width: 2, style: BorderStyle.none),
                            color: isDark ? Colors.white.withAlpha(20) : Colors.black.withAlpha(10),
                          ),
                          child: const Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(LucideIcons.camera, size: 20, color: Colors.grey),
                              SizedBox(height: 4),
                              Text('PHOTO', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey)),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      _buildLabel('Username'),
                      TextField(controller: _userController, decoration: const InputDecoration(border: OutlineInputBorder())),
                      const SizedBox(height: 16),
                      _buildLabel('Email'),
                      TextField(controller: _emailController, decoration: const InputDecoration(border: OutlineInputBorder())),
                      const SizedBox(height: 16),
                      _buildLabel('Password'),
                      TextField(controller: _passController, obscureText: true, decoration: const InputDecoration(border: OutlineInputBorder())),
                      const SizedBox(height: 32),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: th.colorScheme.primary,
                            foregroundColor: Colors.black,
                            padding: const EdgeInsets.symmetric(vertical: 16)
                          ),
                          onPressed: _onCreateUser,
                          child: const Text('Create', style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      )
                    ],
                  ),
                )
              ],
            ),
          ),
        );
      }
    );
  }

  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Text(text, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final th = Theme.of(context);
    final isDark = th.brightness == Brightness.dark;
    final w = MediaQuery.of(context).size.width;

    // Responsive grid behavior
    int cols = 2;
    if (w > 800) cols = 4;
    else if (w > 600) cols = 3;

    final ap = Provider.of<AdminProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Users', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        centerTitle: false,
      ),
      body: ap.isLoading && ap.users.isEmpty
        ? const Center(child: CircularProgressIndicator())
        : SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.0, end: 1.0),
              duration: const Duration(milliseconds: 300),
              builder: (context, value, child) {
                return Opacity(
                  opacity: value,
                  child: Transform.translate(
                    offset: Offset(0, 10 * (1 - value)),
                    child: child,
                  ),
                );
              },
              child: const Text('Admin', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Colors.grey)),
            ),
            const SizedBox(height: 4),
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.0, end: 1.0),
              duration: const Duration(milliseconds: 400),
              builder: (context, value, child) {
                return Opacity(
                  opacity: value,
                  child: Transform.translate(
                    offset: Offset(0, 10 * (1 - value)),
                    child: child,
                  ),
                );
              },
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Staff Directory', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: -0.5)),
                  ElevatedButton.icon(
                    onPressed: _showAddUserPopup,
                    icon: const Icon(LucideIcons.plus, size: 16),
                    label: const Text('Add User'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: th.colorScheme.primary,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    ),
                  )
                ],
              ),
            ),
            const SizedBox(height: 24),
            
            GridView.builder(
              physics: const NeverScrollableScrollPhysics(),
              shrinkWrap: true,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: cols,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: 0.8,
              ),
              itemCount: ap.users.length,
              itemBuilder: (context, index) {
                final u = ap.users[index];
                final initials = u.username.isNotEmpty ? u.username.substring(0, 1).toUpperCase() : 'U';
                return TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0.0, end: 1.0),
                  duration: Duration(milliseconds: 400 + (index * 100)),
                  builder: (context, value, child) {
                    return Opacity(
                      opacity: value,
                      child: Transform.translate(
                        offset: Offset(0, 20 * (1 - value)),
                        child: child,
                      ),
                    );
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white.withAlpha(13) : Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: isDark ? Colors.white.withAlpha(25) : Colors.black.withAlpha(13)),
                      boxShadow: isDark
                          ? null
                          : [
                              BoxShadow(
                                color: Colors.black.withAlpha(8),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              )
                            ],
                    ),
                    child: Stack(
                      children: [
                        Positioned(
                          top: 8,
                          right: 8,
                          child: IconButton(
                            icon: const Icon(LucideIcons.moreVertical, size: 18),
                            color: Colors.grey,
                            onPressed: () {},
                          )
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 12),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                                CircleAvatar(
                                  radius: 36,
                                  backgroundColor: th.colorScheme.primary.withAlpha(50),
                                  backgroundImage: u.profileImageUrl != null
                                      ? NetworkImage(u.profileImageUrl!)
                                      : null,
                                  child: u.profileImageUrl == null
                                      ? Text(
                                          initials,
                                          style: TextStyle(
                                              fontSize: 24,
                                              fontWeight: FontWeight.bold,
                                              color: th.colorScheme.primary),
                                        )
                                      : null,
                                ),
                              const SizedBox(height: 16),
                              Text(
                                u.username,
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                u.email ?? '',
                                style: const TextStyle(fontSize: 10, color: Colors.grey),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const Spacer(),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                decoration: BoxDecoration(
                                  color: isDark ? Colors.white.withAlpha(10) : Colors.black.withAlpha(5),
                                  border: Border.all(color: Colors.grey.withAlpha(50)),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Text(u.role.toUpperCase(), style: const TextStyle(fontSize: 10), textAlign: TextAlign.center),
                              )
                            ],
                          ),
                        )
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
