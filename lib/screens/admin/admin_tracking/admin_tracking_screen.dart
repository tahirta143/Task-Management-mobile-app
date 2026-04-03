import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../provider/admin_provider.dart';
import '../../../models/session_model.dart';
import '../../../widgets/custom_loader.dart';

class AdminTrackingScreen extends StatefulWidget {
  const AdminTrackingScreen({super.key});

  @override
  State<AdminTrackingScreen> createState() => _AdminTrackingScreenState();
}

class _AdminTrackingScreenState extends State<AdminTrackingScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AdminProvider>().fetchTrackedSessions();
    });
  }

  @override
  Widget build(BuildContext context) {
    final th = Theme.of(context);
    final isDark = th.brightness == Brightness.dark;
    final screenWidth = MediaQuery.of(context).size.width;

    final double horizontalPadding = screenWidth < 360
        ? 10.0
        : screenWidth < 600
        ? 16.0
        : 20.0;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F1113) : const Color(0xFFF8F9FA),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(th, horizontalPadding, screenWidth),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: 8.0),
            child: _buildSearchBar(isDark, th),
          ),
          Expanded(
            child: Consumer<AdminProvider>(
              builder: (context, provider, child) {
                if (provider.isLoading && provider.sessions.isEmpty) {
                  return const Center(child: CustomLoader());
                }

                final filteredSessions = provider.sessions.where((s) {
                  final name = s.user.username.toLowerCase();
                  final query = _searchQuery.toLowerCase();
                  return name.contains(query);
                }).toList();

                if (filteredSessions.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(LucideIcons.shieldAlert, size: 48, color: Colors.grey.withAlpha(100)),
                        const SizedBox(height: 16),
                        const Text('No active sessions found', style: TextStyle(color: Colors.grey)),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: EdgeInsets.all(horizontalPadding),
                  itemCount: filteredSessions.length,
                  itemBuilder: (context, index) {
                    final session = filteredSessions[index];
                    return _SessionCard(session: session);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(ThemeData th, double horizontalPadding, double screenWidth) {
    final double titleFontSize = screenWidth < 360
        ? 20.0
        : screenWidth >= 900
        ? 26.0
        : 24.0;

    return Padding(
      padding: EdgeInsets.fromLTRB(horizontalPadding, 8, horizontalPadding, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Live Monitoring',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: th.colorScheme.primary,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Active User Sessions',
            style: TextStyle(
              fontSize: titleFontSize,
              fontWeight: FontWeight.bold,
              letterSpacing: -1,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar(bool isDark, ThemeData th) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withAlpha(15) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: isDark
            ? null
            : [BoxShadow(color: Colors.black.withAlpha(5), blurRadius: 15, offset: const Offset(0, 5))],
      ),
      child: TextField(
        controller: _searchController,
        style: const TextStyle(fontSize: 14),
        decoration: InputDecoration(
          hintText: 'Search by user...',
          hintStyle: TextStyle(color: Colors.grey.withAlpha(150)),
          prefixIcon: Icon(LucideIcons.search, size: 18, color: th.colorScheme.primary),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
            icon: const Icon(LucideIcons.x, size: 16),
            onPressed: () {
              _searchController.clear();
              setState(() => _searchQuery = '');
            },
          )
              : null,
        ),
        onChanged: (value) => setState(() => _searchQuery = value),
      ),
    );
  }
}

class _SessionCard extends StatelessWidget {
  final SessionTracking session;

  const _SessionCard({required this.session});

  @override
  Widget build(BuildContext context) {
    final th = Theme.of(context);
    final isDark = th.brightness == Brightness.dark;
    final lastSeen = DateFormat('MMM dd, HH:mm').format(session.lastSeenAt);
    final screenWidth = MediaQuery.of(context).size.width;

    final double avatarRadius = screenWidth < 360
        ? 18.0
        : screenWidth >= 600
        ? 28.0
        : 24.0;

    final double cardPaddingH = screenWidth < 360
        ? 12.0
        : screenWidth >= 600
        ? 22.0
        : 20.0;

    final double statsPaddingV = screenWidth < 360 ? 12.0 : 20.0;
    final double statsPaddingH = screenWidth < 360
        ? 10.0
        : screenWidth >= 600
        ? 28.0
        : 24.0;

    final double usernameFontSize = screenWidth < 360
        ? 13.0
        : screenWidth >= 600
        ? 16.0
        : 15.0;

    final double statValueFontSize = screenWidth < 360
        ? 10.0
        : screenWidth >= 600
        ? 12.0
        : 11.0;

    final double cardBottomMargin = screenWidth >= 900 ? 20.0 : 16.0;

    return Container(
      margin: EdgeInsets.only(bottom: cardBottomMargin),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withAlpha(13) : Colors.white,
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: isDark ? Colors.white.withAlpha(25) : Colors.black.withAlpha(5)),
        boxShadow: isDark
            ? null
            : [BoxShadow(color: Colors.black.withAlpha(8), blurRadius: 20, offset: const Offset(0, 10))],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(32),
        child: Column(
          children: [
            // Card Header
            Padding(
              padding: EdgeInsets.all(cardPaddingH),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: th.colorScheme.primary.withAlpha(50), width: 2),
                    ),
                    child: CircleAvatar(
                      radius: avatarRadius,
                      backgroundColor: isDark ? Colors.white10 : Colors.black.withAlpha(5),
                      backgroundImage: session.user.profileImageUrl != null
                          ? NetworkImage(session.user.profileImageUrl!)
                          : null,
                      child: session.user.profileImageUrl == null
                          ? Text(
                        session.user.username[0].toUpperCase(),
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: screenWidth < 360 ? 13.0 : 16.0,
                        ),
                      )
                          : null,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          session.user.username,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: usernameFontSize,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: th.colorScheme.primary.withAlpha(30),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                session.user.role.toUpperCase(),
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                  color: th.colorScheme.primary,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Icon(LucideIcons.globe, size: 10, color: Colors.grey.withAlpha(150)),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                session.ipAddress ?? 'Unknown IP',
                                style: const TextStyle(fontSize: 10, color: Colors.grey),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  _buildActionButton(context, session, th, isDark),
                ],
              ),
            ),

            // Stats Row
            Container(
              padding: EdgeInsets.symmetric(vertical: statsPaddingV, horizontal: statsPaddingH),
              decoration: BoxDecoration(
                color: isDark ? Colors.white.withAlpha(10) : Colors.black.withAlpha(2),
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(32)),
              ),
              child: IntrinsicHeight(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildMiniStat(LucideIcons.monitor, 'Device', session.userAgent ?? 'Unknown', statValueFontSize),
                    VerticalDivider(color: Colors.grey.withAlpha(50), thickness: 1, indent: 5, endIndent: 5),
                    _buildMiniStat(LucideIcons.clock, 'Last Seen', lastSeen, statValueFontSize),
                    VerticalDivider(color: Colors.grey.withAlpha(50), thickness: 1, indent: 5, endIndent: 5),
                    _buildMiniStat(LucideIcons.link, 'Sockets', '${session.socketConnectionCount}', statValueFontSize),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMiniStat(IconData icon, String label, String value, double valueFontSize) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, size: 16, color: Colors.grey),
          const SizedBox(height: 6),
          Text(label, style: const TextStyle(fontSize: 9, color: Colors.grey)),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(fontSize: valueFontSize, fontWeight: FontWeight.bold),
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(BuildContext context, SessionTracking session, ThemeData th, bool isDark) {
    return PopupMenuButton<String>(
      padding: EdgeInsets.zero,
      icon: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isDark ? Colors.white10 : Colors.black.withAlpha(5),
          shape: BoxShape.circle,
        ),
        child: const Icon(LucideIcons.moreVertical, size: 18),
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      onSelected: (value) {
        if (value == 'kill') _confirmKill(context, session);
        else if (value == 'kill_all') _confirmKillAll(context, session);
      },
      itemBuilder: (context) => [
        const PopupMenuItem(
          value: 'kill',
          child: Row(
            children: [
              Icon(LucideIcons.logOut, size: 16, color: Colors.red),
              SizedBox(width: 12),
              Text('Kill Session', style: TextStyle(fontSize: 14)),
            ],
          ),
        ),
        const PopupMenuItem(
          value: 'kill_all',
          child: Row(
            children: [
              Icon(LucideIcons.shieldOff, size: 16, color: Colors.red),
              SizedBox(width: 12),
              Text('Kill All Sessions', style: TextStyle(fontSize: 14)),
            ],
          ),
        ),
      ],
    );
  }

  void _confirmKill(BuildContext context, SessionTracking session) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('Kill Session?'),
        content: const Text('This will force the user to log out immediately on this device.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () async {
              Navigator.pop(context);
              try {
                await context.read<AdminProvider>().killSession(session.sessionTokenId);
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
              }
            },
            child: const Text('Kill Session'),
          ),
        ],
      ),
    );
  }

  void _confirmKillAll(BuildContext context, SessionTracking session) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('Kill All Sessions?'),
        content: Text('This will log out ${session.user.username} from ALL devices immediately.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () async {
              Navigator.pop(context);
              try {
                await context.read<AdminProvider>().killAllUserSessions(session.user.id);
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
              }
            },
            child: const Text('Kill All'),
          ),
        ],
      ),
    );
  }
}