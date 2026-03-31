import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';
import '../../../models/user_model.dart';
import '../../../provider/admin_provider.dart';
import '../../../services/socket_service.dart';
import '../../../widgets/custom_loader.dart';

class AdminUsersScreen extends StatefulWidget {
  const AdminUsersScreen({super.key});

  @override
  State<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends State<AdminUsersScreen> {
  final _userController = TextEditingController();
  final _emailController = TextEditingController();
  final _passController = TextEditingController();
  final _profileImageController = TextEditingController();
  int? _selectedCompanyId;
  User? _editingUser;
  bool _isSaving = false;
  bool _isScreenLoading = true;
  
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ap = context.read<AdminProvider>();
      ap.fetchUsers();
      ap.fetchCompanies();
      
      Future.delayed(const Duration(milliseconds: 1000), () {
        if (mounted) setState(() => _isScreenLoading = false);
      });
    });
  }

  @override
  void dispose() {
    _userController.dispose();
    _emailController.dispose();
    _passController.dispose();
    _profileImageController.dispose();
    super.dispose();
  }

  void _onSaveUser() async {
    final ap = context.read<AdminProvider>();
    if (_userController.text.isEmpty || _emailController.text.isEmpty) return;
    if (_editingUser == null && _passController.text.isEmpty) return;

    setState(() { _isSaving = true; });

    try {
      final Map<String, dynamic> payload = {
        'username': _userController.text.trim(),
        'email': _emailController.text.trim(),
        'companyId': _selectedCompanyId,
        'profileImageUrl': _profileImageController.text.trim().isEmpty ? null : _profileImageController.text.trim(),
      };

      if (_passController.text.isNotEmpty) {
        payload['password'] = _passController.text;
      }

      if (_editingUser != null) {
        await ap.updateUser(_editingUser!.id, payload);
      } else {
        await ap.createUser(payload);
      }

      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    } finally {
      if (mounted) setState(() { _isSaving = false; });
    }
  }

  void _onDeleteUser(User user) async {
    final ap = context.read<AdminProvider>();
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete User'),
        content: Text('Are you sure you want to remove ${user.username}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true), 
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete')
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await ap.deleteUser(user.id);
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  void _showAddUserPopup({User? user}) {
    final th = Theme.of(context);
    final isDark = th.brightness == Brightness.dark;

    setState(() {
      _editingUser = user;
      if (user != null) {
        _userController.text = user.username;
        _emailController.text = user.email ?? '';
        _passController.clear();
        _selectedCompanyId = user.companyId;
        _profileImageController.text = user.profileImageUrl ?? '';
      } else {
        _userController.clear();
        _emailController.clear();
        _passController.clear();
        _selectedCompanyId = null;
        _profileImageController.clear();
      }
    });

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final adminProv = context.watch<AdminProvider>();
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
                        Text(_editingUser != null ? 'Edit user' : 'Create staff user', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                        IconButton(icon: const Icon(LucideIcons.x), onPressed: () => Navigator.pop(ctx)),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Expanded(
                      child: ListView(
                        children: [
                          Center(
                            child: InkWell(
                              onTap: () async {
                                final ImagePicker picker = ImagePicker();
                                final XFile? image = await picker.pickImage(source: ImageSource.gallery);
                                if (image != null) {
                                  try {
                                    setModalState(() => _isSaving = true);
                                    final String url = await adminProv.uploadProfileImage(File(image.path));
                                    setModalState(() {
                                      _profileImageController.text = url;
                                      _isSaving = false;
                                    });
                                  } catch (e) {
                                    setModalState(() => _isSaving = false);
                                    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
                                  }
                                }
                              },
                              child: Container(
                                height: 96,
                                width: 96,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.grey.withAlpha(100), width: 2),
                                  color: isDark ? Colors.white.withAlpha(20) : Colors.black.withAlpha(10),
                                  image: _profileImageController.text.isNotEmpty 
                                    ? DecorationImage(
                                        image: NetworkImage(
                                          _profileImageController.text.startsWith('http') 
                                            ? _profileImageController.text 
                                            : '${context.read<SocketService>().baseUrl}${_profileImageController.text.startsWith('/') ? '' : '/'}${_profileImageController.text}'
                                        ), 
                                        fit: BoxFit.cover
                                      )
                                    : null,
                                ),
                                child: _profileImageController.text.isEmpty ? const Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(LucideIcons.camera, size: 20, color: Colors.grey),
                                    SizedBox(height: 4),
                                    Text('GALLERY', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey)),
                                  ],
                                ) : null,
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
                          _buildLabel('Password ${user != null ? "(leave blank to keep)" : ""}'),
                          TextField(
                            controller: _passController, 
                            obscureText: true, 
                            decoration: InputDecoration(
                              border: const OutlineInputBorder(),
                              hintText: user != null ? '••••••••' : null,
                            )
                          ),
                          const SizedBox(height: 16),
                          _buildLabel('Company (Optional)'),
                          DropdownButtonFormField<int?>(
                            initialValue: _selectedCompanyId,
                            decoration: const InputDecoration(border: OutlineInputBorder()),
                            items: [
                              const DropdownMenuItem(value: null, child: Text('No company')),
                              ...adminProv.companies.map((c) => DropdownMenuItem(value: c.id, child: Text(c.name))),
                            ],
                            onChanged: (val) => setModalState(() => _selectedCompanyId = val),
                          ),
                          const SizedBox(height: 32),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: th.colorScheme.primary,
                                foregroundColor: Colors.black,
                                padding: const EdgeInsets.symmetric(vertical: 16)
                              ),
                              onPressed: _isSaving ? null : _onSaveUser,
                              child: Text(_isSaving ? 'Saving...' : (user != null ? 'Save Changes' : 'Create'), style: const TextStyle(fontWeight: FontWeight.bold)),
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
    if (_isScreenLoading) {
      return const Scaffold(body: CustomLoader(fullScreen: true));
    }

    final ap = Provider.of<AdminProvider>(context);
    final th = Theme.of(context);
    final isDark = th.brightness == Brightness.dark;
    final w = MediaQuery.of(context).size.width;

    // Responsive grid behavior
    int cols = 2;
    if (w > 1200) cols = 5;
    else if (w > 900) cols = 4;
    else if (w > 600) cols = 3;
    
    double aspectRatio = 0.7;
    if (w > 1200) aspectRatio = 1.1;
    else if (w > 900) aspectRatio = 1.0;
    else if (w > 450) aspectRatio = 0.8;

    return Container(
      color: Colors.transparent,
      child: RefreshIndicator(
        onRefresh: () async {
          await ap.fetchUsers();
          await ap.fetchCompanies();
        },
        child: ap.isLoading
            ? LayoutBuilder(
                builder: (context, constraints) {
                  return SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    child: ConstrainedBox(
                      constraints:
                          BoxConstraints(minHeight: constraints.maxHeight),
                      child: const Center(
                        child: CustomLoader(),
                      ),
                    ),
                  );
                },
              )
            : SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('ADMIN', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: th.colorScheme.primary, letterSpacing: 1.5)),
                    const Text('Staff Directory', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  ],
                ),
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
            const SizedBox(height: 24),
            
            GridView.builder(
              physics: const NeverScrollableScrollPhysics(),
              shrinkWrap: true,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: cols,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: aspectRatio,
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
                          child: PopupMenuButton<String>(
                            icon: const Icon(LucideIcons.moreVertical, size: 18, color: Colors.grey),
                            onSelected: (val) {
                              if (val == 'edit') _showAddUserPopup(user: u);
                              if (val == 'delete') _onDeleteUser(u);
                            },
                            itemBuilder: (ctx) => [
                              const PopupMenuItem(value: 'edit', child: Row(children: [Icon(LucideIcons.pencil, size: 14), SizedBox(width: 8), Text('Edit')])),
                              const PopupMenuItem(value: 'delete', child: Row(children: [Icon(LucideIcons.trash2, size: 14, color: Colors.red), SizedBox(width: 8), Text('Delete', style: TextStyle(color: Colors.red))])),
                            ],
                          )
                        ),
                        Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const SizedBox(height: 8),
                              CircleAvatar(
                                radius: 32,
                                backgroundColor: th.colorScheme.primary.withAlpha(30),
                                backgroundImage: u.profileImageUrl != null && u.profileImageUrl!.isNotEmpty
                                    ? NetworkImage(
                                        u.profileImageUrl!.startsWith('http')
                                            ? u.profileImageUrl!
                                            : '${context.read<SocketService>().baseUrl}${u.profileImageUrl!.startsWith('/') ? '' : '/'}${u.profileImageUrl!}'
                                      )
                                    : null,
                                child: (u.profileImageUrl == null || u.profileImageUrl!.isEmpty)
                                    ? Text(
                                        initials,
                                        style: TextStyle(
                                            fontSize: 24,
                                            fontWeight: FontWeight.bold,
                                            color: th.colorScheme.primary),
                                      )
                                    : null,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                u.username,
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                u.email ?? '',
                                style: const TextStyle(fontSize: 10, color: Colors.grey),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const Spacer(),
                              Theme(
                                data: th.copyWith(canvasColor: th.scaffoldBackgroundColor),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12),
                                  decoration: BoxDecoration(
                                    color: isDark ? Colors.white.withAlpha(10) : Colors.black.withAlpha(5),
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(color: Colors.grey.withAlpha(30)),
                                  ),
                                  child: DropdownButtonHideUnderline(
                                    child: DropdownButton<int?>(
                                      value: u.companyId,
                                      isExpanded: true,
                                      icon: const Icon(LucideIcons.chevronDown, size: 14),
                                      style: TextStyle(fontSize: 10, color: isDark ? Colors.white70 : Colors.black87),
                                      items: [
                                        const DropdownMenuItem(value: null, child: Text('No Company')),
                                        ...ap.companies.map((c) => DropdownMenuItem(value: c.id, child: Text(c.name, overflow: TextOverflow.ellipsis))),
                                      ],
                                      onChanged: (val) async {
                                        try {
                                          await ap.setUserCompany(u.id, val);
                                        } catch (e) {
                                          if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
                                        }
                                      },
                                    ),
                                  ),
                                ),
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
    ));
  }
}
