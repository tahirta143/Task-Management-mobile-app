import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../provider/theme_provider.dart';
import 'dashboard/dashboard_screen.dart';
import 'board_screen/board_screen.dart';
// import 'progress_screen/progress_screen.dart';
import 'chat_screen/chat_screen.dart';

import '../provider/auth_provider.dart';
import '../provider/task_provider.dart';
import '../provider/admin_provider.dart';
import 'admin/users/admin_users_screen.dart';
import 'admin/reports/admin_reports_screen.dart';
import 'admin/copmanies/admin_companies_screen.dart';
import 'admin/tasks/admin_tasks_screen.dart';

class MainAppScaffold extends StatefulWidget {
  const MainAppScaffold({super.key});

  @override
  State<MainAppScaffold> createState() => _MainAppScaffoldState();
}

class _MainAppScaffoldState extends State<MainAppScaffold> {
  int _bottomNavIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadInitialData();
    });
  }

  void _loadInitialData() {
    final auth = context.read<AuthProvider>();
    context.read<TaskProvider>().fetchTasks();
    if (auth.user?['role'] == 'admin') {
      context.read<AdminProvider>().fetchDashboardReport();
    }
  }

  late final List<Widget> _screens = [
    DashboardScreen(onNavigateToBoard: () => _onBottomNavTapped(1)),
    const BoardScreen(),
    // const ProgressScreen(),
    const ChatScreen(),
  ];

  void _onBottomNavTapped(int index) {
    setState(() {
      _bottomNavIndex = index;
    });
  }

  void _onDrawerMainTapped(int index) {
    Navigator.of(context).pop(); // close drawer
    setState(() {
      _bottomNavIndex = index;
    });
  }

  void _navigateToAdmin(Widget screen) {
    // Close the drawer
    Navigator.of(context).pop();
    // Navigate safely atop the MainAppScaffold
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
  }

  @override
  Widget build(BuildContext context) {
    final th = Theme.of(context);
    final isDark = th.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: th.scaffoldBackgroundColor,
        elevation: 0,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.only(
            bottomLeft: Radius.circular(32),
            bottomRight: Radius.circular(32),
          ),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Enterprise',
              style: TextStyle(
                fontSize: 10,
                color: th.colorScheme.primary,
                fontWeight: FontWeight.w600,
                letterSpacing: 2.0,
              ),
            ),
            const Text(
              'Task OS',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                letterSpacing: -0.5,
              ),
            ),
          ],
        ),
        centerTitle: false,
        actions: [
          IconButton(
            icon: Icon(isDark ? LucideIcons.sun : LucideIcons.moon),
            onPressed: () {
              Provider.of<ThemeProvider>(context, listen: false).toggleTheme();
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      drawer: _buildAdminDrawer(context, isDark, th),
      body: _screens[_bottomNavIndex],
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: th.scaffoldBackgroundColor,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(32),
            topRight: Radius.circular(32),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(isDark ? 50 : 20),
              blurRadius: 20,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(32),
            topRight: Radius.circular(32),
          ),
          child: BottomNavigationBar(
            currentIndex: _bottomNavIndex,
            onTap: _onBottomNavTapped,
            type: BottomNavigationBarType.fixed,
            selectedItemColor: th.colorScheme.primary,
            unselectedItemColor: isDark ? Colors.white54 : Colors.black54,
            backgroundColor: th.scaffoldBackgroundColor,
            elevation: 0,
            items: const [
              BottomNavigationBarItem(
                icon: Icon(LucideIcons.layoutDashboard),
                label: 'Dashboard',
              ),
              BottomNavigationBarItem(
                icon: Icon(LucideIcons.listTodo),
                label: 'Board',
              ),
              // BottomNavigationBarItem(
              //   icon: Icon(LucideIcons.trendingUp),
              //   label: 'Progress',
              // ),
              BottomNavigationBarItem(
                icon: Icon(LucideIcons.messageSquare),
                label: 'Chat',
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAdminDrawer(BuildContext context, bool isDark, ThemeData th) {
    return Drawer(
      backgroundColor: th.scaffoldBackgroundColor,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
              decoration: BoxDecoration(
                color: th.colorScheme.primary.withAlpha(isDark ? 25 : 40),
                borderRadius: const BorderRadius.only(bottomRight: Radius.circular(40)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Enterprise',
                    style: TextStyle(
                      fontSize: 11,
                      color: th.colorScheme.primary,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 2.0,
                    ),
                  ),
                  const Text(
                    'Task OS',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      letterSpacing: -1.0,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ListView(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(left: 12.0, bottom: 8.0, top: 4.0),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'MAIN NAVIGATION',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white54 : Colors.black54,
                              letterSpacing: 1.5,
                            ),
                          ),
                        ),
                      ),
                      _NavItem(
                        icon: LucideIcons.layoutDashboard,
                        label: 'Dashboard',
                        onTap: () => _onDrawerMainTapped(0),
                      ),
                      _NavItem(
                        icon: LucideIcons.listTodo,
                        label: 'Board',
                        onTap: () => _onDrawerMainTapped(1),
                      ),
                      // _NavItem(
                      //   icon: LucideIcons.trendingUp,
                      //   label: 'Progress',
                      //   onTap: () => _onDrawerMainTapped(2),
                      // ),
                      _NavItem(
                        icon: LucideIcons.messageSquare,
                        label: 'Chat',
                        onTap: () => _onDrawerMainTapped(2),
                      ),
                      if (context.watch<AuthProvider>().user?['role'] == 'admin') ...[
                        Padding(
                          padding: const EdgeInsets.only(left: 12.0, bottom: 8.0, top: 12.0),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              'ADMINISTRATOR',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white54 : Colors.black54,
                                letterSpacing: 1.5,
                              ),
                            ),
                          ),
                        ),
                        _NavItem(
                          icon: LucideIcons.users,
                          label: 'Users',
                          onTap: () => _navigateToAdmin(const AdminUsersScreen()),
                        ),
                        _NavItem(
                          icon: LucideIcons.barChart3,
                          label: 'Reports',
                          onTap: () => _navigateToAdmin(const AdminReportsScreen()),
                        ),
                        _NavItem(
                          icon: LucideIcons.building2,
                          label: 'Companies',
                          onTap: () => _navigateToAdmin(const AdminCompaniesScreen()),
                        ),
                        _NavItem(
                          icon: LucideIcons.checkSquare,
                          label: 'System Tasks',
                          onTap: () => _navigateToAdmin(const AdminTasksScreen()),
                        ),
                      ],
                    ],
                  ),
                ),
                ],
              ),
            ),
            // Bottom Profile Section
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.03),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.05),
                  ),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: isDark ? Colors.white24 : Colors.black12,
                      child: Text(
                        (context.read<AuthProvider>().user?['username'] ?? 'U').substring(0, 1).toUpperCase(),
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            (context.read<AuthProvider>().user?['role'] ?? 'USER').toUpperCase(),
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white54 : Colors.black54,
                              letterSpacing: 1.0,
                            ),
                          ),
                          Text(
                            context.read<AuthProvider>().user?['username'] ?? 'Current User',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0).copyWith(bottom: 16.0),
              child: SizedBox(
                width: double.infinity,
                child: TextButton(
                  style: TextButton.styleFrom(
                    backgroundColor: Colors.red.withOpacity(0.1),
                    foregroundColor: Colors.red,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  onPressed: () async {
                    await context.read<AuthProvider>().logout();
                    if (mounted) {
                      Navigator.of(context).pushReplacementNamed('/');
                    }
                  },
                  child: const Text('Logout', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            )
          ],
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final th = Theme.of(context);
    final isDark = th.brightness == Brightness.dark;

    final fg = isDark ? Colors.white : Colors.black;
    final muted = isDark ? Colors.white54 : Colors.black54;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        margin: const EdgeInsets.only(bottom: 4),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 20,
              color: muted,
            ),
            const SizedBox(width: 16),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: fg,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
