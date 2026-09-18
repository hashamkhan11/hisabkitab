import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:hisabshare/models/model.dart';
import 'package:hisabshare/screens/add_contact.dart';
import 'package:hisabshare/screens/category_transactions_page.dart';
import 'package:hisabshare/screens/contact_detail.dart';
import 'package:hisabshare/screens/notifications.dart';
import 'package:hisabshare/screens/settings.dart';
import 'package:hisabshare/services/transaction_service.dart';
import 'package:hisabshare/theme/app_theme.dart';
import 'package:hisabshare/widgets/hisaab.dart';
import 'package:hisabshare/widgets/add_category.dart';
import 'package:hisabshare/widgets/quick_transaction_sheet.dart';
import 'package:hisabshare/repositories/category_repository.dart';
import 'package:hisabshare/repositories/contact_repository.dart';
import 'package:hisabshare/repositories/summary_repository.dart';
import 'package:hisabshare/repositories/notification_repository.dart';
import 'package:hisabshare/providers/current_user_provider.dart';

class Homepage extends StatefulWidget {
  const Homepage({super.key});

  @override
  State<Homepage> createState() => _HomepageState();
}

class _HomepageState extends State<Homepage> {
  int _selectedIndex = 0;
  List<CategoryModel> taskList = [];
  bool _isLoading = true;

  List<Map<String, String>> _allContacts = [];
  Future<List<Map<String, dynamic>>>? _recentTxnsFuture;

  @override
  void initState() {
    super.initState();
    _loadCategories();
    context.read<CurrentUserProvider>().load();
  }

  void _addCategory(CategoryModel newCategory) {
    setState(() {
      taskList.insert(taskList.length - 1, newCategory); // before "+Add"
    });
  }

  Future<void> _loadCategories() async {
    setState(() => _isLoading = true);
    try {
      final categories = await CategoryRepository.loadOrInitializeCategories();
      setState(() {
        taskList = categories;
        _isLoading = false;
      });
      _loadRecentTxns();
    } catch (_) {
      setState(() => _isLoading = false);
    }
  }

  /// Fans out across every real category's contacts to build the dashboard's
  /// "Recent Transactions" feed - there's no backend endpoint that aggregates
  /// transactions across contacts/categories, so this merges them client-side
  /// (via TransactionService.recentAcrossContacts) instead.
  Future<void> _loadRecentTxns() async {
    final realCategories = taskList.where((c) => !c.isLast).toList();
    if (realCategories.isEmpty) {
      setState(() {
        _allContacts = [];
        _recentTxnsFuture = Future.value(const []);
      });
      return;
    }
    try {
      final lists = await Future.wait(realCategories.map((c) => ContactRepository.listContacts(c.id)));
      final combined = <Map<String, String>>[];
      for (var i = 0; i < realCategories.length; i++) {
        for (final contact in lists[i]) {
          combined.add({
            'id': contact['id'] as String,
            'name': contact['name'] as String,
            'categoryId': realCategories[i].id,
          });
        }
      }
      if (!mounted) return;
      setState(() {
        _allContacts = combined;
        _recentTxnsFuture = combined.isEmpty
            ? Future.value(const [])
            : TransactionService.recentAcrossContacts(combined, limit: 5);
      });
    } catch (_) {
      if (mounted) setState(() => _recentTxnsFuture = Future.value(const []));
    }
  }

  void _deleteCategory(CategoryModel category) {
    if (!category.isLast) {
      setState(() {
        taskList.removeWhere((c) => c.id == category.id);
      });
    }
  }

  Future<void> _quickAddCategory() async {
    final newCategory = await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      builder: (_) => const AddCategorySheet(),
    );
    if (newCategory != null && newCategory is CategoryModel) {
      _addCategory(newCategory);
    }
  }

  /// Zero-category / zero-contact detection has no backend aggregate, so
  /// it's done client-side on tap: categories are already loaded in
  /// [taskList], contacts need an explicit fan-out fetch (acceptable since
  /// it only runs on an explicit FAB tap, not on every frame).
  Future<void> _quickAddTransaction() async {
    final realCategories = taskList.where((c) => !c.isLast).toList();
    if (realCategories.isEmpty) {
      await _promptAddCategoryFirst();
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );
    Map<String, List<Map<String, dynamic>>> contactsByCategory = {};
    try {
      final lists = await Future.wait(realCategories.map((c) => ContactRepository.listContacts(c.id)));
      contactsByCategory = {
        for (var i = 0; i < realCategories.length; i++) realCategories[i].id: lists[i],
      };
    } catch (_) {
      // Leave contactsByCategory empty; falls through to the zero-contact guidance below.
    } finally {
      if (mounted) Navigator.pop(context);
    }
    if (!mounted) return;

    final hasAnyContact = contactsByCategory.values.any((l) => l.isNotEmpty);
    if (!hasAnyContact) {
      await _promptAddContactFirst(realCategories);
      return;
    }

    final added = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      builder: (_) => QuickTransactionSheet(
        categories: realCategories,
        contactsByCategory: contactsByCategory,
      ),
    );
    if (added == true) _loadRecentTxns();
  }

  Future<void> _promptAddCategoryFirst() async {
    final proceed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      builder: (_) => const _GuidedEmptyStateSheet(
        icon: Icons.category_rounded,
        title: 'Add a category first',
        message: 'You need at least one category before you can record a transaction.',
        actionLabel: 'Add category',
      ),
    );
    if (proceed != true || !mounted) return;

    await _quickAddCategory();
    if (!mounted) return;

    final realCategories = taskList.where((c) => !c.isLast).toList();
    if (realCategories.isNotEmpty) {
      await _promptAddContactFirst([realCategories.last]);
    }
  }

  Future<void> _promptAddContactFirst(List<CategoryModel> categories) async {
    final proceed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      builder: (_) => const _GuidedEmptyStateSheet(
        icon: Icons.person_add_alt_1_rounded,
        title: 'Add a contact first',
        message: 'You need at least one contact before you can record a transaction.',
        actionLabel: 'Add contact',
      ),
    );
    if (proceed != true || !mounted) return;

    CategoryModel? target = categories.length == 1 ? categories.first : null;
    target ??= await showModalBottomSheet<CategoryModel>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      builder: (_) => _CategoryPickerSheet(categories: categories),
    );
    if (target == null || !mounted) return;

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddContactPage(categoryId: target!.id, categoryName: target.title),
      ),
    );
  }

  void _goToTab(int index) => setState(() => _selectedIndex = index);

  List<Widget> _pages() => [
        _DashboardTab(
          isLoading: _isLoading,
          categories: taskList,
          recentTxnsFuture: _recentTxnsFuture,
          allContacts: _allContacts,
          onSeeAllCategories: () => _goToTab(1),
          onOpenProfile: () => _goToTab(3),
          onOpenNotifications: () => _goToTab(2),
        ),
        _CategoriesTab(
          isLoading: _isLoading,
          categories: taskList,
          onAddCategory: _addCategory,
          onDeleteCategory: _deleteCategory,
        ),
        NotificationPage(onBackToHome: () => _goToTab(0)),
        SettingsPage(onBackToHome: () => _goToTab(0)),
      ];

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        bottom: false,
        child: IndexedStack(index: _selectedIndex, children: _pages()),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _quickAddTransaction,
        tooltip: 'Quick transaction',
        child: const Icon(Icons.add, size: 28),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: _BottomBar(
        selectedIndex: _selectedIndex,
        onTap: _goToTab,
        surface: c.surface,
        border: c.border,
      ),
    );
  }
}

class _BottomBar extends StatelessWidget {
  final int selectedIndex;
  final void Function(int) onTap;
  final Color surface;
  final Color border;

  const _BottomBar({
    required this.selectedIndex,
    required this.onTap,
    required this.surface,
    required this.border,
  });

  @override
  Widget build(BuildContext context) {
    return BottomAppBar(
      color: surface,
      shape: const CircularNotchedRectangle(),
      notchMargin: 8,
      elevation: 0,
      child: SizedBox(
        height: 62,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _navItem(context, icon: Icons.home_rounded, label: 'Home', index: 0),
            _navItem(context, icon: Icons.grid_view_rounded, label: 'Categories', index: 1),
            const SizedBox(width: 48), // room for the notched FAB
            _navItem(
              context,
              icon: Icons.notifications_rounded,
              label: 'Alerts',
              index: 2,
              badgeStream: NotificationRepository.notificationsStream(),
            ),
            _navItem(context, icon: Icons.settings_rounded, label: 'Settings', index: 3),
          ],
        ),
      ),
    );
  }

  Widget _navItem(
    BuildContext context, {
    required IconData icon,
    required String label,
    required int index,
    Stream<List<Map<String, dynamic>>>? badgeStream,
  }) {
    final c = context.appColors;
    final selected = index == selectedIndex;
    final color = selected ? c.accentStrong : c.textMuted;

    Widget iconWidget = Icon(icon, color: color, size: 26);
    if (badgeStream != null) {
      iconWidget = StreamBuilder<List<Map<String, dynamic>>>(
        stream: badgeStream,
        builder: (context, snapshot) {
          final unread = (snapshot.data ?? const [])
              .where((n) => n['is_read'] != true)
              .length;
          return Stack(
            clipBehavior: Clip.none,
            children: [
              Icon(icon, color: color, size: 26),
              if (unread > 0)
                Positioned(
                  right: -2,
                  top: -2,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: c.danger,
                      shape: BoxShape.circle,
                      border: Border.all(color: c.surface, width: 1.5),
                    ),
                  ),
                ),
            ],
          );
        },
      );
    }

    return InkWell(
      onTap: () => onTap(index),
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: iconWidget,
      ),
    );
  }
}

class _DashboardTab extends StatelessWidget {
  final bool isLoading;
  final List<CategoryModel> categories;
  final Future<List<Map<String, dynamic>>>? recentTxnsFuture;
  final List<Map<String, String>> allContacts;
  final VoidCallback onSeeAllCategories;
  final VoidCallback onOpenProfile;
  final VoidCallback onOpenNotifications;

  const _DashboardTab({
    required this.isLoading,
    required this.categories,
    required this.recentTxnsFuture,
    required this.allContacts,
    required this.onSeeAllCategories,
    required this.onOpenProfile,
    required this.onOpenNotifications,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    final previewCategories = categories.where((cat) => !cat.isLast).take(5).toList();

    return RefreshIndicator(
      onRefresh: () async {},
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
        children: [
          _Header(onOpenProfile: onOpenProfile, onOpenNotifications: onOpenNotifications),
          const SizedBox(height: 8),
          _HeroBalanceCard(),
          const SizedBox(height: 22),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Categories', style: Theme.of(context).textTheme.titleMedium),
              GestureDetector(
                onTap: onSeeAllCategories,
                child: Text(
                  'See all',
                  style: TextStyle(color: context.appColors.accentStrong, fontWeight: FontWeight.w600, fontSize: 13),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (previewCategories.isEmpty)
            _EmptyCategoriesHint(onTap: onSeeAllCategories)
          else
            SizedBox(
              height: 92,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: previewCategories.length,
                separatorBuilder: (_, __) => const SizedBox(width: 14),
                itemBuilder: (context, index) => _CategoryChip(category: previewCategories[index]),
              ),
            ),
          if (recentTxnsFuture != null) ...[
            const SizedBox(height: 22),
            _RecentTransactionsSection(future: recentTxnsFuture!, allContacts: allContacts),
          ],
        ],
      ),
    );
  }
}

class _RecentTransactionsSection extends StatelessWidget {
  final Future<List<Map<String, dynamic>>> future;
  final List<Map<String, String>> allContacts;

  const _RecentTransactionsSection({required this.future, required this.allContacts});

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox.shrink();
        }
        final txns = snapshot.data ?? [];
        if (txns.isEmpty) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Recent Transactions', style: Theme.of(context).textTheme.titleMedium),
                GestureDetector(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => AllTransactionsPage(contacts: allContacts)),
                  ),
                  child: Text(
                    'View all',
                    style: TextStyle(color: c.accentStrong, fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(
                color: c.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: c.border),
              ),
              child: Column(
                children: [
                  for (var i = 0; i < txns.length; i++) ...[
                    if (i > 0) Divider(height: 1, color: c.border),
                    _RecentTxnRow(txn: txns[i]),
                  ],
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _RecentTxnRow extends StatelessWidget {
  final Map<String, dynamic> txn;

  const _RecentTxnRow({required this.txn});

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final isReceive = txn['type'] == 'Receive';
    final amount = (txn['credit'] as num?)?.toDouble() ?? 0.0;
    final date = txn['date'] as DateTime;
    final contactName = txn['contactName'] as String? ?? '';

    return InkWell(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ContactDetailPage(
            categoryId: txn['categoryId'] as String? ?? '',
            contactId: txn['contactId'] as String,
            contactName: contactName,
            isSharedView: false,
          ),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isReceive ? c.accentSoft : c.dangerSoft,
                shape: BoxShape.circle,
              ),
              child: Icon(
                isReceive ? Icons.south_west_rounded : Icons.north_east_rounded,
                size: 16,
                color: isReceive ? c.accentStrong : c.danger,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(contactName, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14.5)),
                  const SizedBox(height: 2),
                  Text(
                    DateFormat('MMM d, yyyy').format(date),
                    style: TextStyle(fontSize: 12, color: c.textMuted),
                  ),
                ],
              ),
            ),
            Text(
              'Rs ${amount.toStringAsFixed(0)}',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 14.5,
                color: isReceive ? c.accentStrong : c.danger,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final VoidCallback onOpenProfile;
  final VoidCallback onOpenNotifications;

  const _Header({required this.onOpenProfile, required this.onOpenNotifications});

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    return Row(
      children: [
        GestureDetector(
          onTap: onOpenProfile,
          child: Consumer<CurrentUserProvider>(
            builder: (context, userProvider, _) {
              final imageUrl = userProvider.user?['image_url'] as String?;
              return CircleAvatar(
                radius: 22,
                backgroundColor: c.accentSoft,
                backgroundImage: (imageUrl != null && imageUrl.isNotEmpty)
                    ? CachedNetworkImageProvider(imageUrl) as ImageProvider
                    : null,
                child: (imageUrl == null || imageUrl.isEmpty)
                    ? Icon(Icons.person_rounded, color: c.accentStrong)
                    : null,
              );
            },
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Consumer<CurrentUserProvider>(
            builder: (context, userProvider, _) {
              final name = (userProvider.user?['username'] as String?)?.trim();
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Welcome back', style: TextStyle(color: c.textMuted, fontSize: 12)),
                  Text(
                    (name == null || name.isEmpty) ? 'HisabShare' : name,
                    style: Theme.of(context).textTheme.titleMedium,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              );
            },
          ),
        ),
        GestureDetector(
          onTap: onOpenNotifications,
          child: Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: c.surface,
              borderRadius: BorderRadius.circular(13),
              border: Border.all(color: c.border),
            ),
            child: Icon(Icons.notifications_rounded, color: c.textMuted, size: 20),
          ),
        ),
      ],
    );
  }
}

class _HeroBalanceCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [c.accent, c.accentStrong],
        ),
        boxShadow: [
          BoxShadow(color: c.accent.withValues(alpha: .35), blurRadius: 24, offset: const Offset(0, 10)),
        ],
      ),
      child: StreamBuilder<Map<String, dynamic>>(
        stream: SummaryRepository.balanceStream(),
        builder: (context, snapshot) {
          final data = snapshot.data;
          final totalReceive = ((data?['total_receive'] ?? 0) as num).toDouble();
          final totalSend = ((data?['total_send'] ?? 0) as num).toDouble();
          final net = totalReceive - totalSend;
          final loading = !snapshot.hasData;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'NET BALANCE',
                style: TextStyle(
                  color: c.onAccent.withValues(alpha: .85),
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(height: 6),
              loading
                  ? SizedBox(
                      height: 32,
                      child: SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2.4, color: c.onAccent),
                      ),
                    )
                  : Text(
                      'Rs ${_format(net.abs())}',
                      style: TextStyle(
                        color: c.onAccent,
                        fontSize: 30,
                        fontWeight: FontWeight.w700,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
              if (loading) ...[
                const SizedBox(height: 2),
                Text(
                  'Loading your balance…',
                  style: TextStyle(color: c.onAccent.withValues(alpha: .9), fontSize: 12.5),
                ),
              ],
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _StatChip(
                      icon: Icons.call_received_rounded,
                      label: 'Apko Milenge',
                      value: totalReceive,
                      onAccent: c.onAccent,
                      loading: loading,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _StatChip(
                      icon: Icons.call_made_rounded,
                      label: 'Apko Dene Hain',
                      value: totalSend,
                      onAccent: c.onAccent,
                      loading: loading,
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  static String _format(double value) {
    final s = value.toStringAsFixed(0);
    final buffer = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      final posFromEnd = s.length - i;
      buffer.write(s[i]);
      if (posFromEnd > 1 && posFromEnd % 3 == 1) buffer.write(',');
    }
    return buffer.toString();
  }
}

class _StatChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final double value;
  final Color onAccent;
  final bool loading;

  const _StatChip({
    required this.icon,
    required this.label,
    required this.value,
    required this.onAccent,
    required this.loading,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: onAccent.withValues(alpha: .16),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: onAccent.withValues(alpha: .9), size: 13),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(color: onAccent.withValues(alpha: .9), fontSize: 11, fontWeight: FontWeight.w500),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            loading ? '—' : 'Rs ${_HeroBalanceCard._format(value)}',
            style: TextStyle(
              color: onAccent,
              fontSize: 15,
              fontWeight: FontWeight.w700,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyCategoriesHint extends StatelessWidget {
  final VoidCallback onTap;
  const _EmptyCategoriesHint({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: c.surfaceAlt,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: c.border),
        ),
        child: Row(
          children: [
            Icon(Icons.category_rounded, color: c.accentStrong),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'No categories yet — tap to add your first one.',
                style: TextStyle(color: c.textMuted, fontSize: 13),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  final CategoryModel category;
  const _CategoryChip({required this.category});

  @override
  Widget build(BuildContext context) {
    final bg = category.bgColor ?? context.appColors.accentSoft;
    final iconColor = category.iconColor ?? context.appColors.accentStrong;
    return GestureDetector(
      onTap: () => Categories.openCategory(context, category),
      child: SizedBox(
        width: 70,
        child: Column(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(18)),
              child: Icon(category.iconData ?? Icons.category, color: iconColor, size: 26),
            ),
            const SizedBox(height: 6),
            Text(
              category.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 11.5, color: context.appColors.textMuted, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
    );
  }
}

class _GuidedEmptyStateSheet extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final String actionLabel;

  const _GuidedEmptyStateSheet({
    required this.icon,
    required this.title,
    required this.message,
    required this.actionLabel,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(color: c.border, borderRadius: BorderRadius.circular(2)),
          ),
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(color: c.accentSoft, shape: BoxShape.circle),
            child: Icon(icon, color: c.accentStrong, size: 30),
          ),
          const SizedBox(height: 16),
          Text(title, style: Theme.of(context).textTheme.titleLarge, textAlign: TextAlign.center),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(color: c.textMuted, fontSize: 13.5),
          ),
          const SizedBox(height: 22),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(actionLabel),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Not now'),
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryPickerSheet extends StatelessWidget {
  final List<CategoryModel> categories;

  const _CategoryPickerSheet({required this.categories});

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 18),
              decoration: BoxDecoration(color: c.border, borderRadius: BorderRadius.circular(2)),
            ),
          ),
          Text('Add contact to which category?', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          ...categories.map((category) => ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: category.bgColor ?? c.accentSoft,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(category.iconData ?? Icons.category, color: category.iconColor ?? c.accentStrong),
                ),
                title: Text(category.title),
                trailing: Icon(Icons.chevron_right_rounded, color: c.textMuted),
                onTap: () => Navigator.pop(context, category),
              )),
        ],
      ),
    );
  }
}

class _CategoriesTab extends StatelessWidget {
  final bool isLoading;
  final List<CategoryModel> categories;
  final void Function(CategoryModel) onAddCategory;
  final void Function(CategoryModel) onDeleteCategory;

  const _CategoriesTab({
    required this.isLoading,
    required this.categories,
    required this.onAddCategory,
    required this.onDeleteCategory,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Categories'), automaticallyImplyLeading: false),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : categories.isEmpty
                    ? Center(
                        child: Text(
                          'No categories found',
                          style: TextStyle(color: context.appColors.textMuted),
                        ),
                      )
                    : Padding(
                        padding: const EdgeInsets.only(bottom: 90),
                        child: Categories(
                          categoryList: categories,
                          onAddCategory: onAddCategory,
                          onDeleteCategory: onDeleteCategory,
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}
