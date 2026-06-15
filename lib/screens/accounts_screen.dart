import 'package:flutter/material.dart';

import '../models/game_library_entry.dart';
import '../models/steam_account.dart';
import '../state/app_controller.dart';
import '../utils/formatters.dart';
import '../widgets/app_empty_state.dart';
import '../widgets/dialogs.dart';
import '../widgets/game_icon.dart';
import '../widgets/steam_avatar.dart';
import 'library_screen.dart';

class AccountsScreen extends StatelessWidget {
  const AccountsScreen({
    required this.controller,
    required this.onOpenSettings,
    required this.onShowLibraryForAccount,
    super.key,
  });

  final AppController controller;
  final VoidCallback onOpenSettings;
  final ValueChanged<SteamAccount> onShowLibraryForAccount;

  @override
  Widget build(BuildContext context) {
    if (!controller.hasApiKey) {
      return AppEmptyState(
        icon: Icons.key_outlined,
        title: '需要配置 Steam API Key',
        message: 'GameDeck 使用 Steam Web API 读取公开资料和游戏库，API Key 只保存在本机。',
        action: FilledButton.icon(
          onPressed: onOpenSettings,
          icon: const Icon(Icons.settings_outlined),
          label: const Text('去设置'),
        ),
      );
    }

    if (controller.accounts.isEmpty) {
      return AppEmptyState(
        icon: Icons.person_add_alt_1_outlined,
        title: '还没有 Steam 账号',
        message: '添加 SteamID64 或个人主页 URL 后，可以合并搜索多个账号的游戏库。',
        action: FilledButton.icon(
          onPressed: () => showAddAccountSheet(context, controller),
          icon: const Icon(Icons.add),
          label: const Text('添加账号'),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
      itemBuilder: (context, index) {
        if (index == 0) {
          return _OverviewSection(controller: controller);
        }
        final accountIndex = index - 1;
        final account = controller.accounts[accountIndex];
        return _AccountTile(
          account: account,
          isSyncing: controller.isSyncingAccount(account.steamId),
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (context) => AccountDetailScreen(
                  account: account,
                  controller: controller,
                  onShowLibrary: () => onShowLibraryForAccount(account),
                ),
              ),
            );
          },
        );
      },
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemCount: controller.accounts.length + 1,
    );
  }
}

Future<void> showAddAccountSheet(
  BuildContext context,
  AppController controller,
) async {
  final textController = TextEditingController();
  var isSubmitting = false;

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setState) {
          Future<void> submit() async {
            setState(() => isSubmitting = true);
            try {
              await controller.addAccount(textController.text);
              if (context.mounted) {
                Navigator.of(context).pop();
                showAppSnackBar(context, '账号已添加并完成 Steam 同步。');
              }
            } on Object catch (error) {
              if (context.mounted) {
                showAppSnackBar(context, error.toString());
              }
            } finally {
              if (context.mounted) {
                setState(() => isSubmitting = false);
              }
            }
          }

          return Padding(
            padding: EdgeInsets.fromLTRB(
              20,
              0,
              20,
              MediaQuery.viewInsetsOf(context).bottom + 20,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  '添加 Steam 账号',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: textController,
                  enabled: !isSubmitting,
                  textInputAction: TextInputAction.done,
                  decoration: const InputDecoration(
                    labelText: 'SteamID64 或个人主页 URL',
                    hintText: 'https://steamcommunity.com/id/example',
                    border: OutlineInputBorder(),
                  ),
                  onSubmitted: (_) => isSubmitting ? null : submit(),
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: isSubmitting ? null : submit,
                  icon: isSubmitting
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.add),
                  label: const Text('添加'),
                ),
              ],
            ),
          );
        },
      );
    },
  );
}

class AccountDetailScreen extends StatelessWidget {
  const AccountDetailScreen({
    required this.account,
    required this.controller,
    required this.onShowLibrary,
    super.key,
  });

  final SteamAccount account;
  final AppController controller;
  final VoidCallback onShowLibrary;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final current = controller.accounts.firstWhere(
          (item) => item.steamId == account.steamId,
          orElse: () => account,
        );
        final isSyncing = controller.isSyncingAccount(current.steamId);
        return Scaffold(
          appBar: AppBar(title: const Text('账号详情')),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Row(
                children: [
                  SteamAvatar(
                    imageUrl: current.avatarUrl,
                    label: current.personaName,
                    size: 64,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          current.personaName,
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        const SizedBox(height: 4),
                        Text(current.steamId),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              _MetricRow(label: '个人资料', value: current.isPublic ? '公开' : '受限'),
              _MetricRow(label: '游戏数', value: '${current.gameCount}'),
              _MetricRow(
                label: '总游玩时长',
                value: formatPlaytime(current.totalPlaytimeMinutes),
              ),
              _MetricRow(
                label: '上次同步',
                value: formatDateTime(current.lastSyncedAt),
              ),
              if (current.lastError != null) ...[
                const SizedBox(height: 12),
                Text(
                  current.lastError!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: isSyncing
                    ? null
                    : () async {
                        await controller.syncAccount(current.steamId);
                        if (context.mounted) {
                          showAppSnackBar(context, 'Steam 同步已完成。');
                        }
                      },
                icon: isSyncing
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.sync),
                label: const Text('同步 Steam'),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () {
                  Navigator.of(context).pop();
                  onShowLibrary();
                },
                icon: const Icon(Icons.search),
                label: const Text('查看该账号游戏库'),
              ),
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: () async {
                  final confirmed = await confirmDestructiveAction(
                    context: context,
                    title: '删除账号？',
                    message: '只会删除 GameDeck 本地缓存，不会影响 Steam 账号。',
                    confirmLabel: '删除',
                  );
                  if (!confirmed) {
                    return;
                  }
                  await controller.deleteAccount(current.steamId);
                  if (context.mounted) {
                    Navigator.of(context).pop();
                  }
                },
                icon: const Icon(Icons.delete_outline),
                label: const Text('删除账号'),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _AccountTile extends StatelessWidget {
  const _AccountTile({
    required this.account,
    required this.isSyncing,
    required this.onTap,
  });

  final SteamAccount account;
  final bool isSyncing;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      child: ListTile(
        onTap: onTap,
        leading: SteamAvatar(
          imageUrl: account.avatarUrl,
          label: account.personaName,
        ),
        title: Text(account.personaName),
        subtitle: Text(
          '游戏 ${account.gameCount} · 总时长 ${formatPlaytime(account.totalPlaytimeMinutes)}\n'
          '上次同步：${formatDateTime(account.lastSyncedAt)}',
        ),
        isThreeLine: true,
        trailing: isSyncing
            ? const SizedBox.square(
                dimension: 22,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Icon(Icons.chevron_right, color: theme.colorScheme.outline),
      ),
    );
  }
}

class _OverviewSection extends StatelessWidget {
  const _OverviewSection({required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final games = controller.games;
    final uniqueAppIds = games.map((game) => game.appId).toSet();
    final duplicatedCount = uniqueAppIds
        .where((appId) => games.where((game) => game.appId == appId).length > 1)
        .length;
    final unplayedCount = uniqueAppIds
        .where(
          (appId) => games
              .where((game) => game.appId == appId)
              .every((game) => game.playtimeForeverMinutes <= 0),
        )
        .length;
    final topGames = controller
        .libraryEntries(sort: LibrarySort.totalPlaytime)
        .take(3)
        .toList();
    final recentGames = controller
        .libraryEntries(sort: LibrarySort.lastPlayed)
        .where((game) => game.lastPlayedAt.millisecondsSinceEpoch > 0)
        .take(5)
        .toList();
    final metrics = [
      ('账号', '${controller.accounts.length}', Icons.people_outline),
      ('去重游戏', '${uniqueAppIds.length}', Icons.library_books_outlined),
      ('拥有记录', '${games.length}', Icons.stacked_bar_chart_outlined),
      (
        '总游玩',
        formatPlaytime(
          controller.accounts.fold(
            0,
            (total, account) => total + account.totalPlaytimeMinutes,
          ),
        ),
        Icons.timer_outlined,
      ),
      ('重复拥有', '$duplicatedCount', Icons.copy_all_outlined),
      ('未启动', '$unplayedCount', Icons.hourglass_empty_outlined),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Card(
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          '总览',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                      _MetadataCacheStatus(
                        controller: controller,
                        totalCount: uniqueAppIds.length,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 78,
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    scrollDirection: Axis.horizontal,
                    itemBuilder: (context, index) {
                      final metric = metrics[index];
                      return _OverviewMetric(
                        label: metric.$1,
                        value: metric.$2,
                        icon: metric.$3,
                      );
                    },
                    separatorBuilder: (_, _) => const SizedBox(width: 8),
                    itemCount: metrics.length,
                  ),
                ),
                if (recentGames.isNotEmpty) ...[
                  const Divider(height: 24),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '最近玩过',
                          style: Theme.of(context).textTheme.labelLarge,
                        ),
                        const SizedBox(height: 8),
                        for (final game in recentGames)
                          _CompactGameRow(
                            game: game,
                            trailing: formatLastPlayed(game.lastPlayedAt),
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                  builder: (context) => GameDetailScreen(
                                    entry: game,
                                    controller: controller,
                                  ),
                                ),
                              );
                            },
                          ),
                      ],
                    ),
                  ),
                ],
                if (topGames.isNotEmpty) ...[
                  const Divider(height: 24),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '最常玩',
                          style: Theme.of(context).textTheme.labelLarge,
                        ),
                        const SizedBox(height: 6),
                        for (final game in topGames)
                          _CompactGameRow(
                            game: game,
                            trailing: formatPlaytime(game.totalPlaytimeMinutes),
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                  builder: (context) => GameDetailScreen(
                                    entry: game,
                                    controller: controller,
                                  ),
                                ),
                              );
                            },
                          ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _CompactGameRow extends StatelessWidget {
  const _CompactGameRow({
    required this.game,
    required this.trailing,
    required this.onTap,
  });

  final GameLibraryEntry game;
  final String trailing;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(
          children: [
            GameIcon(imageUrl: game.iconUrl, width: 54, height: 30),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                game.displayName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              trailing,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MetadataCacheStatus extends StatelessWidget {
  const _MetadataCacheStatus({
    required this.controller,
    required this.totalCount,
  });

  final AppController controller;
  final int totalCount;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final label =
        '详情 ${controller.cachedMetadataCount}/$totalCount'
        '${controller.isCachingMetadata && controller.pendingMetadataCount > 0 ? ' · ${controller.pendingMetadataCount}' : ''}';
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (controller.isCachingMetadata)
          SizedBox.square(
            dimension: 14,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: colorScheme.primary,
            ),
          )
        else if (controller.hasIncompleteMetadataCache)
          Icon(Icons.info_outline, size: 14, color: colorScheme.outline),
        if (controller.isCachingMetadata ||
            controller.hasIncompleteMetadataCache)
          const SizedBox(width: 4),
        Text(label, style: Theme.of(context).textTheme.labelMedium),
      ],
    );
  }
}

class _OverviewMetric extends StatelessWidget {
  const _OverviewMetric({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return SizedBox(
      width: 116,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            children: [
              Icon(icon, size: 18, color: colorScheme.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      value,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MetricRow extends StatelessWidget {
  const _MetricRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
