import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'package:scn_jobs/domain/entities/app_notification.dart';
import 'package:scn_jobs/presentation/providers/notifications/notification_sync_controller.dart';
import 'package:scn_jobs/presentation/providers/notifications/notifications_providers.dart';
import 'package:scn_jobs/presentation/shared_widgets/empty_state.dart';

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  Future<void> _onTap(
      BuildContext context,
      WidgetRef ref,
      AppNotification notification,
      ) async {
    // No `ref.invalidate` needed — `notificationsListProvider` streams
    // Isar changes, so the card flips to "read" on its own.
    await ref
        .read(notificationLocalDataSourceProvider)
        .markRead(notification.id);

    if (notification.applicationId != null && context.mounted) {
      context.push('/applications/${notification.applicationId}');
    }
  }

  Future<void> _onRefresh(BuildContext context, WidgetRef ref) async {
    final ok = await ref.read(notificationSyncControllerProvider.notifier).refresh();
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Couldn't refresh. Check your connection.")),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notificationsAsync = ref.watch(notificationsListProvider);
    final unreadCount = ref.watch(unreadNotificationsCountProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          if (unreadCount > 0)
            TextButton(
              onPressed: () => ref
                  .read(notificationLocalDataSourceProvider)
                  .markAllRead(),
              child: const Text('Mark all read'),
            ),
        ],
      ),
      body: notificationsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => EmptyState(
          icon: Icons.error_outline_rounded,
          message: "Couldn't load notifications.",
          actionLabel: 'Retry',
          onAction: () => ref.invalidate(notificationsListProvider),
        ),
        data: (notifications) {
          return RefreshIndicator(
            onRefresh: () => _onRefresh(context, ref),
            child: notifications.isEmpty
            // Scrollable even when empty, otherwise pull-to-refresh
            // can't be triggered on an empty list.
                ? ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                SizedBox(
                  height: MediaQuery.of(context).size.height * 0.6,
                  child: const EmptyState(
                    icon: Icons.notifications_none_rounded,
                    message: 'No notifications yet.',
                  ),
                ),
              ],
            )
                : ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              itemCount: notifications.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final n = notifications[index];
                return Card(
                  margin: EdgeInsets.zero,
                  color: n.isRead ? null : theme.colorScheme.primaryContainer,
                  child: ListTile(
                    onTap: () => _onTap(context, ref, n),
                    title: Text(n.title),
                    subtitle: Text(n.body),
                    trailing: Text(
                      DateFormat('d MMM').format(n.receivedAt),
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
