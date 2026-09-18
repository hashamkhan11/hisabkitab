import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:hisabshare/repositories/notification_repository.dart';
import 'package:hisabshare/services/api_client.dart';
import 'package:hisabshare/services/transaction_service.dart';
import 'package:hisabshare/theme/app_theme.dart';
import 'package:hisabshare/widgets/header_icon_button.dart';

class NotificationPage extends StatefulWidget {
  final VoidCallback onBackToHome;

  const NotificationPage({required this.onBackToHome, super.key});

  @override
  State<NotificationPage> createState() => _NotificationPageState();
}

class _NotificationPageState extends State<NotificationPage> {
  final Set<String> _selected = {};
  final Set<String> _removedIds = {};

  // Transaction-request rows being accepted/rejected right now, and the
  // outcome of ones already resolved this session - applied on top of
  // whatever the ~15s poll last returned, so the buttons don't linger and
  // the user gets instant feedback instead of waiting for the next tick.
  final Set<String> _processingIds = {};
  final Map<String, String> _resolvedOverride = {};

  bool get _selectionMode => _selected.isNotEmpty;

  void _toggleSelected(String id) {
    setState(() {
      if (_selected.contains(id)) {
        _selected.remove(id);
      } else {
        _selected.add(id);
      }
    });
  }

  Future<void> _deleteOne(String id) async {
    await NotificationRepository.delete(id);
    if (mounted) setState(() => _removedIds.add(id));
  }

  Future<void> _deleteSelected() async {
    final ids = _selected.toList();
    try {
      await NotificationRepository.bulkDelete(ids);
      if (mounted) {
        setState(() {
          _removedIds.addAll(ids);
          _selected.clear();
        });
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to delete notifications. Please try again.')),
        );
      }
    }
  }

  Future<void> _respondToRequest(
    String notificationId,
    String transactionId, {
    required bool accept,
  }) async {
    if (_processingIds.contains(notificationId)) return;
    setState(() => _processingIds.add(notificationId));
    try {
      if (accept) {
        await TransactionService.acceptTransaction(transactionId);
      } else {
        await TransactionService.rejectTransaction(transactionId);
      }
      if (!mounted) return;
      setState(() {
        _processingIds.remove(notificationId);
        _resolvedOverride[notificationId] = accept ? 'accepted' : 'rejected';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(accept ? 'Transaction accepted' : 'Transaction rejected')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _processingIds.remove(notificationId));
      final message = e is ApiException
          ? e.message
          : 'Failed to ${accept ? 'accept' : 'reject'} transaction. Please try again.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          action: SnackBarAction(
            label: 'Retry',
            onPressed: () => _respondToRequest(notificationId, transactionId, accept: accept),
          ),
        ),
      );
    }
  }

  Future<void> _clearAll(List<Map<String, dynamic>> visibleItems) async {
    final c = context.appColors;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Clear all notifications?'),
        content: const Text('This will permanently remove every notification. This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text('Clear all', style: TextStyle(color: c.danger)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await NotificationRepository.clearAll();
      if (mounted) {
        setState(() {
          _removedIds.addAll(visibleItems.map((n) => n['id'] as String));
        });
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to clear notifications. Please try again.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    return Scaffold(
      appBar: _selectionMode ? _buildSelectionAppBar(c) : _buildDefaultAppBar(),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: NotificationRepository.notificationsStream(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(child: Text('Error loading notifications'));
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final items = (snapshot.data ?? [])
              .where((n) => !_removedIds.contains(n['id']))
              .toList();

          if (items.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(color: c.accentSoft, shape: BoxShape.circle),
                    child: Icon(Icons.notifications_none_rounded, size: 34, color: c.accentStrong),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'No notifications yet',
                    style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w600, color: c.textColor),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "You're all caught up",
                    style: TextStyle(fontSize: 13, color: c.textMuted),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.only(top: 4, bottom: 16),
            itemCount: items.length,
            itemBuilder: (context, index) {
              final rawData = items[index];
              final id = rawData['id'] as String;
              final override = _resolvedOverride[id];
              final data = override == null ? rawData : {...rawData, 'status': override};

              return Dismissible(
                key: ValueKey(id),
                direction: _selectionMode ? DismissDirection.none : DismissDirection.endToStart,
                background: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  padding: const EdgeInsets.symmetric(horizontal: 22),
                  alignment: Alignment.centerRight,
                  decoration: BoxDecoration(
                    color: c.danger,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Icon(Icons.delete_rounded, color: c.onAccent),
                ),
                confirmDismiss: (_) async {
                  try {
                    await _deleteOne(id);
                    return true;
                  } catch (_) {
                    if (!context.mounted) return false;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Failed to delete notification. Please try again.')),
                    );
                    return false;
                  }
                },
                child: _NotificationCard(
                  data: data,
                  selectionMode: _selectionMode,
                  selected: _selected.contains(id),
                  isProcessing: _processingIds.contains(id),
                  onTap: () async {
                    if (_selectionMode) {
                      _toggleSelected(id);
                      return;
                    }
                    if (data['is_read'] != true) {
                      await NotificationRepository.markRead(id);
                    }
                  },
                  onLongPress: () => _toggleSelected(id),
                  onAccept: () {
                    final transactionId = data['transaction_id'] as String?;
                    if (transactionId != null) {
                      _respondToRequest(id, transactionId, accept: true);
                    }
                  },
                  onReject: () {
                    final transactionId = data['transaction_id'] as String?;
                    if (transactionId != null) {
                      _respondToRequest(id, transactionId, accept: false);
                    }
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }

  AppBar _buildDefaultAppBar() {
    return AppBar(
      leadingWidth: 68,
      leading: Padding(
        padding: const EdgeInsets.only(left: 16),
        child: HeaderIconButton(icon: Icons.arrow_back_rounded, onTap: widget.onBackToHome),
      ),
      title: const Text('Notifications'),
      centerTitle: false,
      titleSpacing: 0,
      actions: [
        HeaderIconButton(
          icon: Icons.done_all_rounded,
          tooltip: 'Mark all as read',
          onTap: () async => NotificationRepository.markAllRead(),
        ),
        const SizedBox(width: 8),
        StreamBuilder<List<Map<String, dynamic>>>(
          stream: NotificationRepository.notificationsStream(),
          builder: (context, snapshot) {
            final items = (snapshot.data ?? [])
                .where((n) => !_removedIds.contains(n['id']))
                .toList();
            return HeaderIconButton(
              icon: Icons.delete_sweep_rounded,
              tooltip: 'Clear all',
              onTap: items.isEmpty ? null : () => _clearAll(items),
            );
          },
        ),
        const SizedBox(width: 16),
      ],
    );
  }

  AppBar _buildSelectionAppBar(AppColors c) {
    return AppBar(
      leadingWidth: 68,
      leading: Padding(
        padding: const EdgeInsets.only(left: 16),
        child: HeaderIconButton(icon: Icons.close_rounded, onTap: () => setState(_selected.clear)),
      ),
      title: Text('${_selected.length} selected'),
      centerTitle: false,
      titleSpacing: 0,
      actions: [
        HeaderIconButton(
          icon: Icons.delete_rounded,
          tooltip: 'Delete selected',
          iconColor: c.danger,
          bgColor: c.dangerSoft,
          onTap: _deleteSelected,
        ),
        const SizedBox(width: 16),
      ],
    );
  }
}

class _NotificationCard extends StatelessWidget {
  final Map<String, dynamic> data;
  final bool selectionMode;
  final bool selected;
  final bool isProcessing;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final VoidCallback onAccept;
  final VoidCallback onReject;

  const _NotificationCard({
    required this.data,
    required this.selectionMode,
    required this.selected,
    required this.isProcessing,
    required this.onTap,
    required this.onLongPress,
    required this.onAccept,
    required this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final title = data['title'] ?? 'No Title';
    final body = data['body'] ?? 'No Body';
    final createdAt = data['created_at'] as String?;
    final time = createdAt != null
        ? DateFormat('MMM d, yyyy • hh:mm a').format(DateTime.parse(createdAt))
        : '';
    final isRead = data['is_read'] == true;
    final isRejected = data['status'] == 'rejected';

    final iconBg = selectionMode
        ? (selected ? c.accentSoft : c.surfaceAlt)
        : (isRejected ? c.dangerSoft : c.accentSoft);
    final iconColor = selectionMode
        ? (selected ? c.accentStrong : c.textMuted)
        : (isRejected ? c.danger : (isRead ? c.textMuted : c.accentStrong));

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: selected ? c.accentSoft : c.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: selected ? c.accentStrong : c.border, width: selected ? 1.5 : 1),
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          onLongPress: onLongPress,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(color: iconBg, borderRadius: BorderRadius.circular(13)),
                  child: Icon(
                    selectionMode
                        ? (selected ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded)
                        : Icons.notifications_rounded,
                    color: iconColor,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontWeight: isRead ? FontWeight.w600 : FontWeight.w700,
                          fontSize: 14.5,
                          color: c.textColor,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        body,
                        style: TextStyle(color: c.textMuted, fontSize: 13, height: 1.3),
                      ),
                      const SizedBox(height: 6),
                      Text(time, style: TextStyle(fontSize: 11.5, color: c.textMuted)),
                      if (!selectionMode && data['type'] == 'transaction_request') ...[
                        const SizedBox(height: 8),
                        _buildRequestFooter(c),
                      ],
                    ],
                  ),
                ),
                if (!selectionMode && !isRead)
                  Container(
                    width: 9,
                    height: 9,
                    margin: const EdgeInsets.only(top: 4),
                    decoration: BoxDecoration(color: c.accentStrong, shape: BoxShape.circle),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRequestFooter(AppColors c) {
    if (isProcessing) {
      return Row(
        children: [
          SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(strokeWidth: 2, color: c.accentStrong),
          ),
          const SizedBox(width: 8),
          Text('Processing…', style: TextStyle(color: c.textMuted, fontSize: 12.5)),
        ],
      );
    }

    final status = data['status'] as String?;
    if (status == 'accepted') {
      return _ResolvedBadge(icon: Icons.check_circle_rounded, label: 'Accepted', color: c.accentStrong);
    }
    if (status == 'rejected') {
      return _ResolvedBadge(icon: Icons.cancel_rounded, label: 'Rejected', color: c.danger);
    }

    return Row(
      children: [
        Expanded(child: _RequestActionButton(label: 'Accept', color: c.accentStrong, bg: c.accentSoft, onPressed: onAccept)),
        const SizedBox(width: 8),
        Expanded(child: _RequestActionButton(label: 'Reject', color: c.danger, bg: c.dangerSoft, onPressed: onReject)),
      ],
    );
  }
}

class _RequestActionButton extends StatelessWidget {
  final String label;
  final Color color;
  final Color bg;
  final VoidCallback onPressed;

  const _RequestActionButton({required this.label, required this.color, required this.bg, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onPressed,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 12.5),
          ),
        ),
      ),
    );
  }
}

class _ResolvedBadge extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _ResolvedBadge({required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerRight,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: color),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 12.5)),
        ],
      ),
    );
  }
}
