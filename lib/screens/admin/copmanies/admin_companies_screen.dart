import 'dart:math';

import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';
import '../../../provider/admin_provider.dart';
import '../../../models/company_model.dart';

class AdminCompaniesScreen extends StatefulWidget {
  const AdminCompaniesScreen({super.key});

  @override
  State<AdminCompaniesScreen> createState() => _AdminCompaniesScreenState();
}

class _AdminCompaniesScreenState extends State<AdminCompaniesScreen> {
  final _nameController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AdminProvider>().fetchCompanies();
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _onCreateCompany() async {
    if (_nameController.text.trim().isEmpty) return;
    
    final ap = context.read<AdminProvider>();
    try {
      await ap.createCompany(_nameController.text.trim());
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  void _showCreateCompanyPopup() {
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
            height: MediaQuery.of(context).size.height * 0.4, // Shorter since it's just one field
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
                    const Text('Create company', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                    IconButton(icon: const Icon(LucideIcons.x), onPressed: () => Navigator.pop(ctx)),
                  ],
                ),
                const SizedBox(height: 24),
                _buildLabel('Name'),
                TextField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    hintText: 'E.g. North Region Ops',
                    border: OutlineInputBorder(),
                  ),
                ),
                const Spacer(),
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('Cancel', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: th.colorScheme.primary,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        onPressed: _onCreateCompany,
                        child: const Text('Create', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        );
      },
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

    int cols = 2;
    if (w > 800) cols = 4;
    else if (w > 600) cols = 3;

    final ap = Provider.of<AdminProvider>(context);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: th.scaffoldBackgroundColor,
        elevation: 0,
        title: const Text('Admin Companies', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        centerTitle: false,
      ),
      body: ap.isLoading && ap.companies.isEmpty
        ? const Center(child: CircularProgressIndicator())
        : SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildAnimatedBlock(0, const Text('Admin', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Colors.grey))),
            const SizedBox(height: 4),
            _buildAnimatedBlock(100, Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Companies', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: -0.5)),
                ElevatedButton.icon(
                  onPressed: _showCreateCompanyPopup,
                  icon: const Icon(LucideIcons.plus, size: 16),
                  label: const Text('Create'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: th.colorScheme.primary,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  ),
                )
              ],
            )),
            const SizedBox(height: 24),

            _buildAnimatedBlock(200, _buildCompaniesGrid(isDark, th, cols, ap.companies)),
          ],
        ),
      ),
    );
  }

  Widget _buildAnimatedBlock(int delayMs, Widget child) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 400 + delayMs),
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 20 * (1 - value)),
            child: child,
          ),
        );
      },
      child: child,
    );
  }

  Widget _buildCompaniesGrid(bool isDark, ThemeData th, int cols, List<Company> items) {
    if (items.isEmpty) {
      return const Center(child: Padding(padding: EdgeInsets.all(32.0), child: Text('No companies found.', style: TextStyle(color: Colors.grey))));
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withAlpha(13) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: isDark ? Colors.white.withAlpha(25) : Colors.black.withAlpha(13)),
        boxShadow: isDark ? null : [BoxShadow(color: Colors.black.withAlpha(8), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Company list', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 16),
          GridView.builder(
            physics: const NeverScrollableScrollPhysics(),
            shrinkWrap: true,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
               crossAxisCount: cols,
               crossAxisSpacing: 12,
               mainAxisSpacing: 12,
               childAspectRatio: 2.5,
            ),
            itemCount: items.length,
            itemBuilder: (context, index) {
              final c = items[index];
              return _buildAnimatedBlock(index * 100, Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white.withAlpha(10) : Colors.black.withAlpha(5),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.grey.withAlpha(50)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      c.name,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '#${c.id}',
                      style: const TextStyle(fontSize: 10, color: Colors.grey),
                    ),
                  ],
                ),
              ));
            },
          )
        ],
      ),
    );
  }
}
