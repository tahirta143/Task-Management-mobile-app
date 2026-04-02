import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;

import '../provider/theme_provider.dart';
import '../provider/notification_provider.dart';
import '../services/socket_service.dart';
import '../services/local_notification_service.dart';
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
  Widget? _adminView;
  String? _adminTitle;
  bool _notifPanelOpen = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadInitialData();
      _initNotificationSocket();
    });
  }

  void _loadInitialData() {
    final auth = context.read<AuthProvider>();
    context.read<TaskProvider>().fetchTasks();
    if (auth.user?['role'] == 'admin') {
      context.read<AdminProvider>().fetchDashboardReport();
    }
  }

  Future<void> _initNotificationSocket() async {
    final ss = SocketService();
    await ss.connect();

    // Join the personal user room so the server can push events directly
    // to this user (task:assigned, task:new_message)
    if (ss.socket.connected) {
      debugPrint('MainAppScaffold: Joining User Room');
      ss.joinUserRoom();
    } else {
      ss.socket.on('connect', (_) {
        debugPrint('MainAppScaffold: Late Joining User Room');
        ss.joinUserRoom();
      });
    }

    // ── Task assignment notifications ──────────────────────────────────────
    ss.listenForTaskAssigned((payload) {
      if (!mounted) return;
      final notif = AppNotification.fromTaskAssigned(payload);
      // 1. Add to in-app notification panel + show in-app toast
      context.read<NotificationProvider>().addNotification(notif);
      _showNotificationToast(notif);
      // 2. Show OS system tray notification (works when screen is locked)
      LocalNotificationService().showTaskAssigned(
        taskId: notif.taskId ?? 0,
        taskTitle: notif.body,
      );
    });

    // ── Chat message notifications ─────────────────────────────────────────
    ss.listenForNewChatMessage((payload) {
      if (!mounted) return;
      final notif = AppNotification.fromChatMessage(payload);
      final last = payload['lastMessage'] as Map<String, dynamic>?;
      final sender = last?['senderUsername'] as String? ?? 'New message';
      final content = last?['type'] == 'image'
          ? '📷 Image'
          : (last?['content'] as String? ?? 'New message');
      final taskId = payload['taskId'] is int
          ? payload['taskId'] as int
          : int.tryParse('${payload['taskId'] ?? ''}') ?? 0;
      // 1. Add to in-app notification panel + show in-app toast
      context.read<NotificationProvider>().addNotification(notif);
      _showNotificationToast(notif);
      // 2. Show OS system tray notification (works when screen is locked)
      LocalNotificationService().showChatMessage(
        taskId: taskId,
        senderName: sender,
        message: content,
      );
    });
  }

  void _showNotificationToast(AppNotification notif) {
    if (!mounted) return;
    final overlay = Overlay.of(context);
    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => _NotificationToast(
        notification: notif,
        onDismiss: () => entry.remove(),
      ),
    );
    overlay.insert(entry);
    Future.delayed(const Duration(seconds: 4), () {
      if (entry.mounted) entry.remove();
    });
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
      _adminView = null;
      _adminTitle = null;
      _notifPanelOpen = false;
    });
  }

  void _onDrawerMainTapped(int index) {
    Navigator.of(context).pop(); // close drawer
    setState(() {
      _bottomNavIndex = index;
      _adminView = null;
      _adminTitle = null;
      _notifPanelOpen = false;
    });
  }

  void _navigateToAdmin(Widget screen, String title) {
    Navigator.of(context).pop();
    setState(() {
      _adminView = screen;
      _adminTitle = title;
      _notifPanelOpen = false;
    });
  }

  @override
  void dispose() {
    SocketService().stopListeningForTaskAssigned();
    SocketService().stopListeningForNewChatMessage();
    super.dispose();
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
          // ── Notification Bell ──────────────────────────────────────────
          Consumer<NotificationProvider>(
            builder: (context, np, _) {
              return GestureDetector(
                onTap: () {
                  setState(() => _notifPanelOpen = !_notifPanelOpen);
                  if (!_notifPanelOpen) np.markAllRead();
                },
                child: Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _notifPanelOpen
                              ? th.colorScheme.primary.withAlpha(30)
                              : Colors.transparent,
                        ),
                        child: Icon(
                          _notifPanelOpen
                              ? LucideIcons.bellRing
                              : LucideIcons.bell,
                          size: 20,
                          color: _notifPanelOpen
                              ? th.colorScheme.primary
                              : null,
                        ),
                      ),
                      if (np.unreadCount > 0)
                        Positioned(
                          top: 4,
                          right: 4,
                          child: Container(
                            padding: const EdgeInsets.all(3),
                            decoration: BoxDecoration(
                              color: Colors.redAccent,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: th.scaffoldBackgroundColor,
                                width: 1.5,
                              ),
                            ),
                            constraints: const BoxConstraints(
                                minWidth: 16, minHeight: 16),
                            child: Text(
                              np.unreadCount > 99
                                  ? '99+'
                                  : '${np.unreadCount}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 8,
                                fontWeight: FontWeight.bold,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
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
      body: Stack(
        children: [
          _adminView ?? _screens[_bottomNavIndex],
          // Notification slide-in panel (Now wrapped correctly for the Stack)
          Positioned.fill(
            child: AnimatedSlide(
              offset: _notifPanelOpen ? Offset.zero : const Offset(0, -1),
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
              child: AnimatedOpacity(
                opacity: _notifPanelOpen ? 1 : 0,
                duration: const Duration(milliseconds: 250),
                child: _notifPanelOpen
                    ? _NotificationPanel(
                        onClose: () {
                          setState(() => _notifPanelOpen = false);
                          context.read<NotificationProvider>().markAllRead();
                        },
                      )
                    : const SizedBox.shrink(),
              ),
            ),
          ),
        ],
      ),
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

  Widget _buildAdminDrawer(
      BuildContext context, bool isDark, ThemeData th) {
    return Drawer(
      backgroundColor: th.scaffoldBackgroundColor,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(
                  horizontal: 24.0, vertical: 32.0),
              decoration: BoxDecoration(
                color: th.colorScheme.primary
                    .withAlpha(isDark ? 25 : 40),
                borderRadius: const BorderRadius.only(
                    bottomRight: Radius.circular(40)),
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
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(
                              left: 12.0, bottom: 8.0, top: 4.0),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              'MAIN NAVIGATION',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: isDark
                                    ? Colors.white54
                                    : Colors.black54,
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
                        if (context
                                .watch<AuthProvider>()
                                .user?['role'] ==
                            'admin') ...[
                          Padding(
                            padding: const EdgeInsets.only(
                                left: 12.0, bottom: 8.0, top: 12.0),
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                'ADMINISTRATOR',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: isDark
                                      ? Colors.white54
                                      : Colors.black54,
                                  letterSpacing: 1.5,
                                ),
                              ),
                            ),
                          ),
                          _NavItem(
                            icon: LucideIcons.users,
                            label: 'Users',
                            onTap: () => _navigateToAdmin(
                                const AdminUsersScreen(),
                                'Staff Directory'),
                          ),
                          _NavItem(
                            icon: LucideIcons.barChart3,
                            label: 'Reports',
                            onTap: () => _navigateToAdmin(
                                const AdminReportsScreen(),
                                'Reports & Analytics'),
                          ),
                          _NavItem(
                            icon: LucideIcons.building2,
                            label: 'Companies',
                            onTap: () => _navigateToAdmin(
                                const AdminCompaniesScreen(),
                                'Companies'),
                          ),
                          _NavItem(
                            icon: LucideIcons.checkSquare,
                            label: 'Tasks',
                            onTap: () => _navigateToAdmin(
                                const AdminTasksScreen(), 'Admin Tasks'),
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
                  color: isDark
                      ? Colors.white.withOpacity(0.05)
                      : Colors.black.withOpacity(0.03),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: isDark
                        ? Colors.white.withOpacity(0.1)
                        : Colors.black.withOpacity(0.05),
                  ),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      backgroundColor:
                          isDark ? Colors.white24 : Colors.black12,
                      child: Text(
                        (context
                                    .read<AuthProvider>()
                                    .user?['username'] ??
                                'U')
                            .substring(0, 1)
                            .toUpperCase(),
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            (context
                                        .read<AuthProvider>()
                                        .user?['role'] ??
                                    'USER')
                                .toUpperCase(),
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              color: isDark
                                  ? Colors.white54
                                  : Colors.black54,
                              letterSpacing: 1.0,
                            ),
                          ),
                          Text(
                            context
                                    .read<AuthProvider>()
                                    .user?['username'] ??
                                'Current User',
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
              padding: const EdgeInsets.symmetric(horizontal: 16.0)
                  .copyWith(bottom: 16.0),
              child: SizedBox(
                width: double.infinity,
                child: TextButton(
                  style: TextButton.styleFrom(
                    backgroundColor: Colors.red.withOpacity(0.1),
                    foregroundColor: Colors.red,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  onPressed: () async {
                    await context.read<AuthProvider>().logout();
                    if (mounted) {
                      Navigator.of(context).pushReplacementNamed('/');
                    }
                  },
                  child: const Text('Logout',
                      style: TextStyle(fontWeight: FontWeight.bold)),
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
        padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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

// ─── Notification Panel ────────────────────────────────────────────────────────

class _NotificationPanel extends StatelessWidget {
  final VoidCallback onClose;

  const _NotificationPanel({required this.onClose});

  @override
  Widget build(BuildContext context) {
    final th = Theme.of(context);
    final isDark = th.brightness == Brightness.dark;
    final np = context.watch<NotificationProvider>();
    final notifs = np.notifications;

    return GestureDetector(
      onTap: onClose,
      behavior: HitTestBehavior.opaque,
      child: Stack(
          children: [
            // Backdrop
            Container(color: Colors.black.withAlpha(80)),
            // Panel
            Align(
              alignment: Alignment.topCenter,
              child: GestureDetector(
                onTap: () {}, // prevent backdrop tap propagating
                child: Container(
                  width: double.infinity,
                  constraints: const BoxConstraints(
                      maxWidth: 480, maxHeight: 500),
                  margin:
                      const EdgeInsets.fromLTRB(12, 8, 12, 0),
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF1A1D24)
                        : Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: isDark
                          ? Colors.white.withAlpha(15)
                          : Colors.black.withAlpha(10),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black
                            .withAlpha(isDark ? 80 : 30),
                        blurRadius: 24,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Header
                      Padding(
                        padding: const EdgeInsets.fromLTRB(
                            20, 16, 12, 8),
                        child: Row(
                          children: [
                            Icon(
                              LucideIcons.bell,
                              size: 16,
                              color: th.colorScheme.primary,
                            ),
                            const SizedBox(width: 8),
                            const Text(
                              'Notifications',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                letterSpacing: -0.3,
                              ),
                            ),
                            if (np.unreadCount > 0) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding:
                                    const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.redAccent,
                                  borderRadius:
                                      BorderRadius.circular(8),
                                ),
                                child: Text(
                                  '${np.unreadCount}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                            const Spacer(),
                            if (notifs.isNotEmpty)
                              TextButton(
                                onPressed: () => np.clearAll(),
                                style: TextButton.styleFrom(
                                  foregroundColor: Colors.grey,
                                  padding: EdgeInsets.zero,
                                  minimumSize:
                                      const Size(60, 32),
                                ),
                                child: const Text('Clear all',
                                    style: TextStyle(
                                        fontSize: 12)),
                              ),
                            IconButton(
                              icon: const Icon(LucideIcons.x,
                                  size: 18),
                              onPressed: onClose,
                              color: Colors.grey,
                              visualDensity:
                                  VisualDensity.compact,
                            ),
                          ],
                        ),
                      ),
                      const Divider(height: 1, thickness: 1),
                      // List
                      Flexible(
                        child: notifs.isEmpty
                            ? Padding(
                                padding:
                                    const EdgeInsets.all(40),
                                child: Column(
                                  mainAxisSize:
                                      MainAxisSize.min,
                                  children: [
                                    Icon(
                                      LucideIcons.bellOff,
                                      size: 36,
                                      color: isDark
                                          ? Colors.white24
                                          : Colors.black26,
                                    ),
                                    const SizedBox(height: 12),
                                    Text(
                                      'No notifications yet',
                                      style: TextStyle(
                                        color: isDark
                                            ? Colors.white38
                                            : Colors.black38,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            : ListView.separated(
                                shrinkWrap: true,
                                padding:
                                    const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 8),
                                itemCount: notifs.length,
                                separatorBuilder: (_, __) =>
                                    const SizedBox(height: 4),
                                itemBuilder: (context, index) {
                                  final n = notifs[index];
                                  return _NotifTile(
                                    notification: n,
                                    onTap: () =>
                                        np.markRead(n.id),
                                  );
                                },
                              ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      );
  }
}

class _NotifTile extends StatelessWidget {
  final AppNotification notification;
  final VoidCallback onTap;

  const _NotifTile(
      {required this.notification, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final th = Theme.of(context);
    final isDark = th.brightness == Brightness.dark;
    final isUnread = !notification.read;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(
            horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isUnread
              ? th.colorScheme.primary
                  .withAlpha(isDark ? 25 : 18)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isUnread
                ? th.colorScheme.primary.withAlpha(60)
                : (isDark
                    ? Colors.white.withAlpha(8)
                    : Colors.black.withAlpha(6)),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: th.colorScheme.primary
                    .withAlpha(isDark ? 40 : 30),
              ),
              child: Icon(
                notification.title == 'New Message'
                    ? LucideIcons.messageSquare
                    : LucideIcons.clipboardList,
                size: 16,
                color: th.colorScheme.primary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    notification.title,
                    style: TextStyle(
                      fontWeight: isUnread
                          ? FontWeight.bold
                          : FontWeight.w500,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    notification.body,
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark
                          ? Colors.white60
                          : Colors.black54,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    DateFormat('hh:mm a · MMM d')
                        .format(notification.createdAt),
                    style: TextStyle(
                      fontSize: 10,
                      color: isDark
                          ? Colors.white38
                          : Colors.black38,
                    ),
                  ),
                ],
              ),
            ),
            if (isUnread)
              Container(
                width: 8,
                height: 8,
                margin: const EdgeInsets.only(top: 4),
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.redAccent,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ─── Notification Toast (top overlay) ─────────────────────────────────────────

class _NotificationToast extends StatefulWidget {
  final AppNotification notification;
  final VoidCallback onDismiss;

  const _NotificationToast(
      {required this.notification, required this.onDismiss});

  @override
  State<_NotificationToast> createState() =>
      _NotificationToastState();
}

class _NotificationToastState extends State<_NotificationToast>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 350),
  )..forward();

  late final Animation<Offset> _slide = Tween<Offset>(
    begin: const Offset(0, -1.5),
    end: Offset.zero,
  ).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOutBack));

  late final Animation<double> _fade =
      CurvedAnimation(parent: _ctrl, curve: Curves.easeIn);

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final th = Theme.of(context);
    final isDark = th.brightness == Brightness.dark;

    return Positioned(
      top: MediaQuery.of(context).padding.top + 80,
      left: 16,
      right: 16,
      child: SlideTransition(
        position: _slide,
        child: FadeTransition(
          opacity: _fade,
          child: GestureDetector(
            onTap: widget.onDismiss,
            child: Material(
              color: Colors.transparent,
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF1E2130)
                      : Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color:
                        th.colorScheme.primary.withAlpha(80),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: th.colorScheme.primary
                          .withAlpha(40),
                      blurRadius: 20,
                      offset: const Offset(0, 6),
                    ),
                    BoxShadow(
                      color: Colors.black
                          .withAlpha(isDark ? 60 : 20),
                      blurRadius: 12,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: th.colorScheme.primary
                            .withAlpha(30),
                      ),
                      child: Icon(
                        LucideIcons.clipboardList,
                        size: 18,
                        color: th.colorScheme.primary,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.notification.title,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            widget.notification.body,
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark
                                  ? Colors.white60
                                  : Colors.black54,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    GestureDetector(
                      onTap: widget.onDismiss,
                      child: const Padding(
                        padding: EdgeInsets.all(4),
                        child: Icon(LucideIcons.x,
                            size: 16, color: Colors.grey),
                      ),
                    ),
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
