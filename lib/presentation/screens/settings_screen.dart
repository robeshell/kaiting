import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../app_update/app_update_service.dart';
import '../../app_update/app_update_ui.dart';
import '../../core/sound_theme.dart';
import '../../core/now_playing_style.dart';
import '../../library/scanning/local_library_scanner.dart';
import '../../offline/offline_media_provider.dart';
import '../../playback/playback_controller.dart';
import '../../playback/playback_mode.dart';
import '../../playback/sleep_timer_controller.dart';
import '../../sources/local/local_source_service.dart';
import '../../sources/webdav/webdav_connection_service.dart';
import '../controllers/offline_download_controller.dart';
import '../widgets/settings_components.dart';
import '../widgets/sound_components.dart';
import 'source_settings_screen.dart';

enum SettingsDestination { overview, sources, offline }

Color _settingsPrimaryText(BuildContext context) => context.settingsPrimary;

Color _settingsSecondaryText(BuildContext context) => context.settingsSecondary;

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({
    required this.playback,
    required this.localSources,
    required this.scanner,
    required this.onShowKeyboardShortcuts,
    required this.sleepTimer,
    this.webDavService,
    this.offline,
    this.initialDestination = SettingsDestination.overview,
    required this.accentPreset,
    required this.onAccentChanged,
    required this.skinPreset,
    required this.onSkinChanged,
    this.nowPlayingStyle = NowPlayingStyle.classic,
    this.onNowPlayingStyleChanged,
    this.openLyricsByDefault = false,
    this.onOpenLyricsByDefaultChanged,
    super.key,
  });

  final SoundPlaybackController playback;
  final LocalSourceService localSources;
  final LocalLibraryScanner scanner;
  final WebDavConnectionService? webDavService;
  final OfflineDownloadController? offline;
  final VoidCallback onShowKeyboardShortcuts;
  final SleepTimerController sleepTimer;
  final SettingsDestination initialDestination;
  final AccentPreset accentPreset;
  final ValueChanged<AccentPreset> onAccentChanged;
  final SoundSkinPreset skinPreset;
  final ValueChanged<SoundSkinPreset> onSkinChanged;
  final NowPlayingStyle nowPlayingStyle;
  final ValueChanged<NowPlayingStyle>? onNowPlayingStyleChanged;
  final bool openLyricsByDefault;
  final ValueChanged<bool>? onOpenLyricsByDefaultChanged;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late SettingsDestination _destination = widget.initialDestination;
  bool _playbackModesExpanded = false;
  bool _sleepTimerExpanded = false;
  String _appVersion = '—';

  @override
  void initState() {
    super.initState();
    unawaited(_loadAppVersion());
  }

  Future<void> _loadAppVersion() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      if (mounted) setState(() => _appVersion = packageInfo.version);
    } on MissingPluginException {
      // Widget tests and custom embedders may not provide package metadata.
    } on PlatformException {
      // Keep the neutral placeholder if the platform cannot read its package.
    }
  }

  @override
  void didUpdateWidget(SettingsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialDestination != widget.initialDestination) {
      _destination = widget.initialDestination;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_destination == SettingsDestination.sources) {
      return _withCompactBackNavigation(
        context,
        SourceSettingsScreen(
          localSources: widget.localSources,
          scanner: widget.scanner,
          playback: widget.playback,
          webDavService: widget.webDavService,
          onBack: () =>
              setState(() => _destination = SettingsDestination.overview),
        ),
      );
    }
    if (_destination == SettingsDestination.offline && widget.offline != null) {
      return _withCompactBackNavigation(
        context,
        OfflineSettingsView(
          offline: widget.offline!,
          onBack: () =>
              setState(() => _destination = SettingsDestination.overview),
        ),
      );
    }

    return AnimatedBuilder(
      animation: Listenable.merge([
        widget.playback,
        widget.sleepTimer,
        ?widget.offline,
      ]),
      builder: (context, _) {
        return ColoredBox(
          color: context.settingsCanvas,
          child: SoundSettingsScrollView(
            key: const ValueKey('settings-overview'),
            padding: EdgeInsets.fromLTRB(
              context.soundPageGutter,
              context.soundIsCompact ? 12 : 18,
              context.soundPageGutter,
              context.soundContentBottomPadding,
            ),
            children: [
              if (!context.soundIsCompact) ...[
                const SoundSettingsPageHeader(title: '设置'),
                const SizedBox(height: SoundSettingsMetrics.sectionGap),
              ],
              ..._buildOverviewSections(context),
            ],
          ),
        );
      },
    );
  }

  Widget _withCompactBackNavigation(BuildContext context, Widget child) {
    if (!context.soundIsCompact) return child;
    return PopScope<void>(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && mounted) {
          setState(() => _destination = SettingsDestination.overview);
        }
      },
      child: child,
    );
  }

  List<Widget> _buildOverviewSections(BuildContext context) {
    final compact = context.soundIsCompact;
    const gap = SizedBox(height: SoundSettingsMetrics.sectionGap);
    return [
      _SettingsSection(
        title: '播放',
        children: [
          SoundSettingsRow(
            key: const ValueKey('settings-playback-mode-row'),
            title: '播放模式',
            value: widget.playback.playbackMode.label,
            expanded: !compact && _playbackModesExpanded,
            onTap: () => compact
                ? unawaited(_showCompactPlaybackModeSheet(context))
                : setState(
                    () => _playbackModesExpanded = !_playbackModesExpanded,
                  ),
          ),
          if (!compact && _playbackModesExpanded)
            _PlaybackModeSelector(
              selected: widget.playback.playbackMode,
              onSelected: (mode) {
                widget.playback.setPlaybackMode(mode);
                setState(() => _playbackModesExpanded = false);
              },
            ),
          SoundSettingsRow(
            key: const ValueKey('settings-sleep-timer-row'),
            title: '睡眠定时',
            value: _sleepTimerLabel(widget.sleepTimer),
            expanded: !compact && _sleepTimerExpanded,
            onTap: () => compact
                ? unawaited(_showCompactSleepTimerSheet(context))
                : setState(() => _sleepTimerExpanded = !_sleepTimerExpanded),
          ),
          if (!compact && _sleepTimerExpanded)
            _SleepTimerSelector(
              timer: widget.sleepTimer,
              hasTrack: widget.playback.displayTrack != null,
            ),
        ],
      ),
      gap,
      _SettingsSection(
        title: '资料库',
        children: [
          SoundSettingsRow(
            key: const ValueKey('settings-sources-row'),
            title: '音乐来源',
            onTap: () =>
                setState(() => _destination = SettingsDestination.sources),
          ),
          if (widget.offline != null)
            SoundSettingsRow(
              key: const ValueKey('settings-offline-row'),
              title: '离线与缓存',
              value: _formatBytes(widget.offline!.stats.totalBytes),
              onTap: () =>
                  setState(() => _destination = SettingsDestination.offline),
            ),
        ],
      ),
      gap,
      _SettingsSection(
        title: '外观',
        showDividers: false,
        children: [
          const SoundSettingsBlockLabel('皮肤'),
          _SkinPresetSelector(
            selected: widget.skinPreset,
            onSelected: widget.onSkinChanged,
          ),
          const SoundSettingsBlockLabel('主题色'),
          _AccentPresetSelector(
            selected: widget.accentPreset,
            onSelected: widget.onAccentChanged,
          ),
          const SoundSettingsBlockLabel('播放器样式'),
          _NowPlayingStyleSelector(
            selected: widget.nowPlayingStyle,
            onSelected: widget.onNowPlayingStyleChanged ?? (_) {},
          ),
          _SettingsToggleRow(
            key: const ValueKey('settings-open-lyrics-default-row'),
            title: '默认打开歌词',
            value: widget.openLyricsByDefault,
            onChanged: widget.onOpenLyricsByDefaultChanged ?? (_) {},
          ),
        ],
      ),
      if (!compact && soundUsesDesktopPlatform) ...[
        gap,
        _SettingsSection(
          title: '操作',
          children: [
            SoundSettingsRow(
              title: '键盘快捷键',
              onTap: widget.onShowKeyboardShortcuts,
            ),
          ],
        ),
      ],
      gap,
      _SettingsSection(
        title: '关于',
        children: [
          _AboutInfoRow(label: '版本', value: _appVersion),
          SoundSettingsRow(
            key: const ValueKey('settings-check-update-row'),
            title: '检查更新',
            onTap: () => unawaited(_checkForUpdate(context)),
          ),
        ],
      ),
    ];
  }

  Future<void> _checkForUpdate(BuildContext context) async {
    final result = await AppUpdateService().checkForUpdate();
    if (!context.mounted) return;
    await showAppUpdateFlow(context, result: result);
  }

  Future<void> _showCompactPlaybackModeSheet(BuildContext context) {
    return showSoundBottomSheet<void>(
      context,
      maxWidth: 560,
      builder: (sheetContext) => _CompactSettingsSheet(
        title: '播放模式',
        subtitle: '选择队列结束和切歌时的行为',
        children: [
          for (final mode in PlaybackMode.values)
            _CompactSettingsOption(
              key: ValueKey('settings-playback-mode-${mode.name}'),
              label: mode.label,
              selected: mode == widget.playback.playbackMode,
              onTap: () {
                widget.playback.setPlaybackMode(mode);
                Navigator.pop(sheetContext);
              },
            ),
        ],
      ),
    );
  }

  Future<void> _showCompactSleepTimerSheet(BuildContext context) {
    const durations = [15, 30, 45, 60];
    return showSoundBottomSheet<void>(
      context,
      maxWidth: 560,
      builder: (sheetContext) => _CompactSettingsSheet(
        title: '睡眠定时',
        subtitle: '到时自动暂停播放',
        children: [
          for (final minutes in durations)
            _CompactSettingsOption(
              key: ValueKey('sleep-timer-$minutes'),
              label: '$minutes 分钟',
              selected:
                  widget.sleepTimer.mode == SleepTimerMode.duration &&
                  widget.sleepTimer.remaining.inMinutes <= minutes &&
                  widget.sleepTimer.remaining.inMinutes >= minutes - 1,
              onTap: () {
                widget.sleepTimer.start(Duration(minutes: minutes));
                Navigator.pop(sheetContext);
              },
            ),
          _CompactSettingsOption(
            key: const ValueKey('sleep-timer-end-of-track'),
            label: '播完当前歌曲',
            selected: widget.sleepTimer.mode == SleepTimerMode.endOfTrack,
            enabled: widget.playback.displayTrack != null,
            onTap: () {
              widget.sleepTimer.stopAfterCurrentTrack();
              Navigator.pop(sheetContext);
            },
          ),
          if (widget.sleepTimer.isActive)
            _CompactSettingsOption(
              key: const ValueKey('sleep-timer-cancel'),
              label: '关闭睡眠定时',
              destructive: true,
              onTap: () {
                widget.sleepTimer.cancel();
                Navigator.pop(sheetContext);
              },
            ),
        ],
      ),
    );
  }
}

class _CompactSettingsSheet extends StatelessWidget {
  const _CompactSettingsSheet({
    required this.title,
    required this.subtitle,
    required this.children,
  });

  final String title;
  final String subtitle;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: _settingsPrimaryText(context),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: _settingsSecondaryText(context),
              ),
            ),
            const SizedBox(height: 14),
            for (var index = 0; index < children.length; index++) ...[
              children[index],
              if (index != children.length - 1)
                Divider(
                  height: 1,
                  indent: 4,
                  color: context.settingsHairline,
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _CompactSettingsOption extends StatelessWidget {
  const _CompactSettingsOption({
    required this.label,
    required this.onTap,
    this.selected = false,
    this.enabled = true,
    this.destructive = false,
    super.key,
  });

  final String label;
  final VoidCallback onTap;
  final bool selected;
  final bool enabled;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final activeColor = destructive
        ? context.soundColors.error
        : selected
        ? SoundColors.accent
        : _settingsPrimaryText(context);
    final foreground = enabled
        ? activeColor
        : _settingsSecondaryText(context).withValues(alpha: 0.42);
    return Semantics(
      button: true,
      selected: selected,
      enabled: enabled,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(SoundRadii.control),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 7),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    label,
                    style: context.soundListTitleStyle.copyWith(
                      color: foreground,
                    ),
                  ),
                ),
                if (selected)
                  Icon(KaitingIcons.check, size: 20, color: SoundColors.accent),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

String _sleepTimerLabel(SleepTimerController timer) {
  return switch (timer.mode) {
    SleepTimerMode.off => '关闭',
    SleepTimerMode.endOfTrack => '播完当前歌曲',
    SleepTimerMode.duration => _formatRemaining(timer.remaining),
  };
}

String _formatRemaining(Duration duration) {
  final totalMinutes = duration.inMinutes;
  final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
  return '$totalMinutes:$seconds';
}

class _SleepTimerSelector extends StatelessWidget {
  const _SleepTimerSelector({required this.timer, required this.hasTrack});

  final SleepTimerController timer;
  final bool hasTrack;

  @override
  Widget build(BuildContext context) {
    const durations = [15, 30, 45, 60];
    final selected = timer.mode == SleepTimerMode.endOfTrack
        ? -1
        : timer.mode == SleepTimerMode.duration
        ? durations.firstWhere(
            (minutes) =>
                timer.remaining.inMinutes <= minutes &&
                timer.remaining.inMinutes >= minutes - 1,
            orElse: () => 0,
          )
        : 0;
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 4, 14, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SoundChoiceStrip<int>(
            wrap: true,
            selected: selected,
            onSelected: (value) => value == -1
                ? timer.stopAfterCurrentTrack()
                : timer.start(Duration(minutes: value)),
            options: [
              for (final minutes in durations)
                SoundChoiceOption(
                  key: ValueKey('sleep-timer-$minutes'),
                  value: minutes,
                  label: '$minutes 分钟',
                ),
              SoundChoiceOption(
                key: const ValueKey('sleep-timer-end-of-track'),
                value: -1,
                label: '播完当前歌曲',
                enabled: hasTrack,
              ),
            ],
          ),
          if (timer.isActive)
            TextButton.icon(
              key: const ValueKey('sleep-timer-cancel'),
              onPressed: timer.cancel,
              style: context.soundDestructiveButtonStyle,
              icon: const Icon(KaitingIcons.close, size: 16),
              label: const Text('取消定时'),
            ),
        ],
      ),
    );
  }
}

class OfflineSettingsView extends StatelessWidget {
  const OfflineSettingsView({
    required this.offline,
    required this.onBack,
    super.key,
  });

  final OfflineDownloadController offline;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: offline,
      builder: (context, _) {
        final stats = offline.stats;
        final offlineItems = offline.offlineItems;
        return SoundSettingsScrollView(
          key: const ValueKey('offline-settings'),
          padding: EdgeInsets.fromLTRB(
            context.soundPageGutter,
            20,
            context.soundPageGutter,
            context.soundContentBottomPadding,
          ),
          children: [
            SoundSettingsBackButton(
              onPressed: onBack,
              buttonKey: const ValueKey('offline-settings-back'),
            ),
            const SizedBox(height: SoundSettingsMetrics.sectionGap),
            _OfflineStorageOverview(stats: stats),
            const SizedBox(height: SoundSettingsMetrics.sectionGap),
            _OfflineDownloadsPanel(
              items: offlineItems,
              onCancel: (item) => _cancelDownload(context, item),
              onRetry: (item) => unawaited(_retryDownload(context, item)),
              onRemove: (item) => unawaited(_removeDownload(context, item)),
            ),
            const SizedBox(height: SoundSettingsMetrics.sectionGap),
            _SettingsSection(
              title: '存储管理',
              children: [
                SoundSettingsRow(
                  key: const ValueKey('clear-transient-cache'),
                  title: '清理临时缓存',
                  value: _formatBytes(stats.transientBytes),
                  onTap: stats.transientEntries == 0
                      ? null
                      : () => unawaited(_clearTransient(context)),
                ),
                SoundSettingsRow(
                  key: const ValueKey('clear-all-offline'),
                  title: '删除全部音频缓存',
                  value: '${stats.totalEntries} 个文件',
                  onTap: stats.totalEntries == 0
                      ? null
                      : () => unawaited(_clearAll(context)),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  Future<void> _clearTransient(BuildContext context) async {
    final removed = await offline.clearTransient();
    if (context.mounted) _showStorageMessage(context, '已清理 $removed 个临时缓存文件');
  }

  void _cancelDownload(BuildContext context, OfflineDownloadItem item) {
    offline.cancelReference(item.reference);
    _showStorageMessage(context, '已取消「${item.title}」的下载');
  }

  Future<void> _retryDownload(
    BuildContext context,
    OfflineDownloadItem item,
  ) async {
    try {
      await offline.retry(item.reference);
      if (context.mounted) {
        _showStorageMessage(context, '「${item.title}」已可离线播放');
      }
    } on OfflineDownloadCancelledException {
      // Explicit cancellation has its own feedback.
    } catch (_) {
      if (!context.mounted) return;
      final error =
          offline.taskForReference(item.reference)?.error ?? '重试失败，请检查网络与来源设置';
      _showStorageMessage(context, error);
    }
  }

  Future<void> _removeDownload(
    BuildContext context,
    OfflineDownloadItem item,
  ) async {
    final failed = item.task?.state == OfflineDownloadTaskState.failed;
    if (!failed) {
      final confirmed = await _confirmRemoveDownload(context, item.title);
      if (!confirmed || !context.mounted) return;
    }
    try {
      await offline.removeReference(item.reference);
      if (context.mounted) {
        _showStorageMessage(
          context,
          failed ? '已移除失败记录' : '已移除「${item.title}」的离线下载',
        );
      }
    } catch (error) {
      if (context.mounted) {
        _showStorageMessage(
          context,
          error.toString().replaceFirst('Bad state: ', ''),
        );
      }
    }
  }

  Future<void> _clearAll(BuildContext context) async {
    final confirmed = await _confirmClearAll(context);
    if (!confirmed || !context.mounted) return;
    final removed = await offline.clearAll();
    if (context.mounted) _showStorageMessage(context, '已删除 $removed 个缓存文件');
  }
}

class _OfflineStorageOverview extends StatelessWidget {
  const _OfflineStorageOverview({required this.stats});

  final OfflineStorageStats stats;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SoundSettingsSectionLabel('存储占用'),
        SoundSettingsGroup(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _formatBytes(stats.totalBytes),
                    key: const ValueKey('offline-total-size'),
                    style: TextStyle(
                      color: _settingsPrimaryText(context),
                      fontSize: 24,
                      height: 1.1,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.45,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '音频文件合计 · ${stats.totalEntries} 个',
                    style: TextStyle(
                      color: context.settingsMuted,
                      fontSize: 12,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
            _OfflineStatRow(
              label: '离线下载',
              value: _formatBytes(stats.pinnedBytes),
              detail: '${stats.pinnedEntries} 首',
            ),
            _OfflineStatRow(
              label: '临时缓存',
              value: _formatBytes(stats.transientBytes),
              detail: '${stats.transientEntries} 个文件',
            ),
          ],
        ),
      ],
    );
  }
}

class _OfflineStatRow extends StatelessWidget {
  const _OfflineStatRow({
    required this.label,
    required this.value,
    required this.detail,
  });

  final String label;
  final String value;
  final String detail;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: context.soundListTitleStyle.copyWith(
                color: _settingsPrimaryText(context),
              ),
            ),
          ),
          Text(
            detail,
            style: TextStyle(color: context.settingsMuted, fontSize: 12),
          ),
          const SizedBox(width: 12),
          Text(
            value,
            style: TextStyle(
              color: _settingsSecondaryText(context),
              fontSize: 13,
              fontWeight: FontWeight.w600,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

class _OfflineDownloadsPanel extends StatelessWidget {
  const _OfflineDownloadsPanel({
    required this.items,
    required this.onCancel,
    required this.onRetry,
    required this.onRemove,
  });

  final List<OfflineDownloadItem> items;
  final ValueChanged<OfflineDownloadItem> onCancel;
  final ValueChanged<OfflineDownloadItem> onRetry;
  final ValueChanged<OfflineDownloadItem> onRemove;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SoundSettingsSectionLabel(
          '下载与离线内容',
          trailing: Text('${items.length} 项'),
        ),
        if (items.isEmpty)
          const SoundSettingsGroup(children: [_OfflineDownloadsEmpty()])
        else if (items.length <= 5)
          SoundSettingsGroup(
            children: [
              for (final item in items)
                _OfflineDownloadRow(
                  item: item,
                  onCancel: onCancel,
                  onRetry: onRetry,
                  onRemove: onRemove,
                ),
            ],
          )
        else
          SoundSettingsGroup(
            children: [
              SizedBox(
                height: 430,
                child: ListView.separated(
                  primary: false,
                  padding: EdgeInsets.zero,
                  itemCount: items.length,
                  itemBuilder: (context, index) => _OfflineDownloadRow(
                    item: items[index],
                    onCancel: onCancel,
                    onRetry: onRetry,
                    onRemove: onRemove,
                  ),
                  separatorBuilder: (_, _) => Divider(
                    height: 1,
                    indent: 14,
                    endIndent: 14,
                    color: context.settingsHairline,
                  ),
                ),
              ),
            ],
          ),
      ],
    );
  }
}

class _OfflineDownloadsEmpty extends StatelessWidget {
  const _OfflineDownloadsEmpty();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 16, 14, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '还没有离线内容',
            style: context.soundListTitleStyle.copyWith(
              color: _settingsPrimaryText(context),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '在专辑或歌曲菜单中选择「离线保存」。',
            style: TextStyle(
              color: context.settingsMuted,
              fontSize: 12,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}

class _OfflineDownloadRow extends StatelessWidget {
  const _OfflineDownloadRow({
    required this.item,
    required this.onCancel,
    required this.onRetry,
    required this.onRemove,
  });

  final OfflineDownloadItem item;
  final ValueChanged<OfflineDownloadItem> onCancel;
  final ValueChanged<OfflineDownloadItem> onRetry;
  final ValueChanged<OfflineDownloadItem> onRemove;

  @override
  Widget build(BuildContext context) {
    final task = item.task;
    final downloading = task?.state == OfflineDownloadTaskState.downloading;
    final failed = task?.state == OfflineDownloadTaskState.failed;
    final subtitle = failed
        ? (task?.error ?? '下载失败')
        : [
            if (item.artist.trim().isNotEmpty) item.artist.trim(),
            if (downloading)
              task?.totalBytes == null
                  ? _formatBytes(task?.receivedBytes ?? 0)
                  : '${_formatBytes(task!.receivedBytes)} / ${_formatBytes(task.totalBytes!)}'
            else
              _formatBytes(item.size),
          ].where((part) => part.isNotEmpty).join(' · ');

    final titleColor = failed
        ? context.soundColors.error
        : _settingsPrimaryText(context);
    final subtitleColor = failed
        ? context.soundColors.error
        : context.settingsMuted;

    final menu = SoundMenuButton<String>(
      key: ValueKey('offline-actions-${item.reference.storageKey}'),
      tooltip: '更多操作 ${item.title}',
      menuTitle: item.title,
      padding: const EdgeInsets.all(8),
      icon: const Icon(KaitingIcons.moreHorizontal, size: 20),
      onSelected: (value) {
        if (value == 'cancel') onCancel(item);
        if (value == 'retry') onRetry(item);
        if (value == 'remove') onRemove(item);
      },
      actions: [
        if (downloading)
          const SoundMenuAction(
            value: 'cancel',
            label: '取消下载',
            icon: KaitingIcons.close,
            destructive: true,
          ),
        if (failed && item.canRetry)
          const SoundMenuAction(
            value: 'retry',
            label: '重试下载',
            icon: KaitingIcons.refresh,
          ),
        if (failed)
          const SoundMenuAction(
            value: 'remove',
            label: '移除失败记录',
            icon: KaitingIcons.delete,
            destructive: true,
            dividerBefore: true,
          ),
        if (!downloading && !failed)
          const SoundMenuAction(
            value: 'remove',
            label: '移除离线下载',
            icon: KaitingIcons.delete,
            destructive: true,
          ),
      ],
    );

    final compact = context.soundIsCompact;
    final row = Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                item.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.soundListTitleStyle.copyWith(color: titleColor),
              ),
              if (subtitle.isNotEmpty) ...[
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  maxLines: failed && !compact ? 2 : 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: subtitleColor,
                    fontSize: 12,
                    height: 1.3,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ],
          ),
        ),
        if (downloading) ...[
          SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              value: task?.progress,
              strokeWidth: 2,
            ),
          ),
          const SizedBox(width: 2),
        ],
        if (compact)
          menu
        else if (downloading)
          IconButton(
            key: ValueKey('offline-cancel-${item.reference.storageKey}'),
            onPressed: () => onCancel(item),
            tooltip: '取消下载',
            icon: const Icon(KaitingIcons.close, size: 20),
            visualDensity: VisualDensity.compact,
          )
        else if (failed) ...[
          IconButton(
            key: ValueKey('offline-dismiss-${item.reference.storageKey}'),
            onPressed: () => onRemove(item),
            tooltip: '移除失败记录',
            icon: const Icon(KaitingIcons.close, size: 20),
            visualDensity: VisualDensity.compact,
          ),
          IconButton(
            key: ValueKey('offline-retry-${item.reference.storageKey}'),
            onPressed: item.canRetry ? () => onRetry(item) : null,
            tooltip: item.canRetry ? '重试下载' : '来源已不在资料库',
            icon: const Icon(KaitingIcons.refresh, size: 20),
            visualDensity: VisualDensity.compact,
          ),
        ] else
          IconButton(
            key: ValueKey('offline-remove-${item.reference.storageKey}'),
            onPressed: () => onRemove(item),
            tooltip: '移除离线下载',
            icon: const Icon(KaitingIcons.delete, size: 20),
            visualDensity: VisualDensity.compact,
          ),
      ],
    );

    return Padding(
      key: ValueKey('offline-item-${item.reference.storageKey}'),
      padding: const EdgeInsets.fromLTRB(14, 0, 6, 0),
      child: compact
          ? SizedBox(height: 64, child: row)
          : Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: row,
            ),
    );
  }
}

Future<bool> _confirmRemoveDownload(BuildContext context, String title) async {
  return await showDialog<bool>(
        context: context,
        builder: (dialogContext) => SoundDialog(
          maxWidth: 400,
          title: const Text('移除离线下载？'),
          content: Text(
            '将删除「$title」的本地副本，不会影响音乐来源中的原文件。',
            style: TextStyle(color: dialogContext.soundMutedText),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              style: dialogContext.soundDestructiveButtonStyle,
              child: const Text('移除'),
            ),
          ],
        ),
      ) ??
      false;
}

Future<bool> _confirmClearAll(BuildContext context) async {
  return await showDialog<bool>(
        context: context,
        builder: (dialogContext) => SoundDialog(
          maxWidth: 400,
          title: const Text('删除全部缓存？'),
          content: Text(
            '离线保存的歌曲也会被删除。WebDAV 和本地来源中的原文件不会受到影响。',
            style: TextStyle(color: dialogContext.soundMutedText),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              style: dialogContext.soundDestructiveButtonStyle,
              child: const Text('全部删除'),
            ),
          ],
        ),
      ) ??
      false;
}

void _showStorageMessage(BuildContext context, String message) {
  showSoundSnackBar(context, message);
}

String _formatBytes(int bytes) {
  if (bytes < 1024) return '$bytes B';
  final kib = bytes / 1024;
  if (kib < 1024) return '${kib.toStringAsFixed(kib >= 100 ? 0 : 1)} KB';
  final mib = kib / 1024;
  if (mib < 1024) return '${mib.toStringAsFixed(mib >= 100 ? 0 : 1)} MB';
  final gib = mib / 1024;
  return '${gib.toStringAsFixed(gib >= 100 ? 0 : 1)} GB';
}

IconData _playbackModeIcon(PlaybackMode mode) => switch (mode) {
  PlaybackMode.sequential => KaitingIcons.sequence,
  PlaybackMode.repeatOne => KaitingIcons.repeatOne,
  PlaybackMode.repeatAll => KaitingIcons.repeatAll,
  PlaybackMode.shuffle => KaitingIcons.shuffle,
};

class _SettingsSection extends StatelessWidget {
  const _SettingsSection({
    this.title,
    required this.children,
    this.showDividers = true,
  });

  final String? title;
  final List<Widget> children;
  final bool showDividers;

  @override
  Widget build(BuildContext context) {
    final title = this.title;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (title != null) SoundSettingsSectionLabel(title),
        SoundSettingsGroup(showDividers: showDividers, children: children),
      ],
    );
  }
}

class _AboutInfoRow extends StatelessWidget {
  const _AboutInfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 46),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        child: Row(
          children: [
            SizedBox(
              width: 52,
              child: Text(
                label,
                style: context.soundListTitleStyle.copyWith(
                  color: _settingsSecondaryText(context),
                  fontWeight: FontWeight.w400,
                ),
              ),
            ),
            Expanded(
              child: SelectableText(
                value,
                style: context.soundListTitleStyle.copyWith(
                  color: _settingsPrimaryText(context),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlaybackModeSelector extends StatelessWidget {
  const _PlaybackModeSelector({
    required this.selected,
    required this.onSelected,
  });

  final PlaybackMode selected;
  final ValueChanged<PlaybackMode> onSelected;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 4, 14, 13),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final columns = constraints.maxWidth >= 620 ? 4 : 2;
          const gap = 8.0;
          final itemWidth =
              (constraints.maxWidth - gap * (columns - 1)) / columns;
          return Wrap(
            spacing: gap,
            runSpacing: gap,
            children: [
              for (final mode in PlaybackMode.values)
                SizedBox(
                  width: itemWidth,
                  child: _PlaybackModeChoice(
                    key: ValueKey('settings-playback-mode-${mode.name}'),
                    mode: mode,
                    selected: mode == selected,
                    onTap: () => onSelected(mode),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _PlaybackModeChoice extends StatelessWidget {
  const _PlaybackModeChoice({
    required this.mode,
    required this.selected,
    required this.onTap,
    super.key,
  });

  final PlaybackMode mode;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(SoundRadii.pill),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          height: 36,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: selected
                ? SoundColors.accent.withValues(alpha: 0.09)
                : context.soundTint(0.022),
            borderRadius: BorderRadius.circular(SoundRadii.pill),
          ),
          child: Row(
            children: [
              Icon(
                _playbackModeIcon(mode),
                size: 16,
                color: selected
                    ? SoundColors.accent
                    : context.soundSecondaryText,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  mode.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                    color: selected
                        ? SoundColors.accent
                        : _settingsSecondaryText(context),
                  ),
                ),
              ),
              if (selected)
                Icon(KaitingIcons.check, size: 17, color: SoundColors.accent),
            ],
          ),
        ),
      ),
    );
  }
}

class _NowPlayingStyleSelector extends StatelessWidget {
  const _NowPlayingStyleSelector({
    required this.selected,
    required this.onSelected,
  });

  final NowPlayingStyle selected;
  final ValueChanged<NowPlayingStyle> onSelected;

  @override
  Widget build(BuildContext context) {
    return Padding(
      key: const ValueKey('now-playing-style-selector'),
      padding: const EdgeInsets.fromLTRB(14, 6, 14, 14),
      child: LayoutBuilder(
        builder: (context, constraints) {
          const spacing = 10.0;
          const columns = 2;
          final width =
              (constraints.maxWidth - spacing * (columns - 1)) / columns;
          return Wrap(
            spacing: spacing,
            runSpacing: spacing,
            children: [
              for (final style in NowPlayingStyle.values)
                SizedBox(
                  width: width,
                  child: _NowPlayingStyleCard(
                    style: style,
                    selected: style == selected,
                    onTap: () => onSelected(style),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _SettingsToggleRow extends StatelessWidget {
  const _SettingsToggleRow({
    required this.title,
    required this.value,
    required this.onChanged,
    super.key,
  });

  final String title;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      toggled: value,
      child: InkWell(
        onTap: () => onChanged(!value),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minHeight: SoundSettingsMetrics.rowMinHeight(context),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        style: context.soundListTitleStyle.copyWith(
                          color: _settingsPrimaryText(context),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                SoundSwitch(value: value, onChanged: onChanged),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NowPlayingStyleCard extends StatelessWidget {
  const _NowPlayingStyleCard({
    required this.style,
    required this.selected,
    required this.onTap,
  });

  final NowPlayingStyle style;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: '${style.label}播放器样式',
      child: Tooltip(
        message: style.description,
        child: InkWell(
          key: ValueKey('now-playing-style-${style.id}'),
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: selected
                  ? SoundColors.accent.withValues(alpha: 0.055)
                  : context.soundTint(0.018),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: selected ? SoundColors.accent : context.soundDivider,
                width: selected ? 2 : 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AspectRatio(
                  aspectRatio: 1.65,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: Row(
                        children: [
                          Expanded(
                            child: Center(
                              child: FractionallySizedBox(
                                widthFactor: 0.64,
                                child: AspectRatio(
                                  aspectRatio: 1,
                                  child: style == NowPlayingStyle.vinyl
                                      ? DecoratedBox(
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            color: _settingsPrimaryText(
                                              context,
                                            ).withValues(alpha: 0.82),
                                          ),
                                          child: Center(
                                            child: FractionallySizedBox(
                                              widthFactor: 0.42,
                                              heightFactor: 0.42,
                                              child: DecoratedBox(
                                                decoration: BoxDecoration(
                                                  shape: BoxShape.circle,
                                                  color: SoundColors.accent
                                                      .withValues(
                                                        alpha: selected
                                                            ? 0.72
                                                            : 0.42,
                                                      ),
                                                ),
                                              ),
                                            ),
                                          ),
                                        )
                                      : DecoratedBox(
                                          decoration: BoxDecoration(
                                            color: SoundColors.accent
                                                .withValues(
                                                  alpha: selected ? 0.72 : 0.42,
                                                ),
                                            borderRadius: BorderRadius.circular(
                                              4,
                                            ),
                                          ),
                                        ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 7),
                          Expanded(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                for (final factor in const [
                                  0.72,
                                  1.0,
                                  0.84,
                                  0.6,
                                ])
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 2.5,
                                    ),
                                    child: FractionallySizedBox(
                                      alignment: Alignment.centerLeft,
                                      widthFactor: factor,
                                      child: Container(
                                        height: 4,
                                        color: factor == 1.0
                                            ? SoundColors.accent.withValues(
                                                alpha: 0.78,
                                              )
                                            : context.soundMutedText.withValues(
                                                alpha: 0.42,
                                              ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 7),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        style.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: selected
                              ? SoundColors.accent
                              : _settingsPrimaryText(context),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SkinPresetSelector extends StatelessWidget {
  const _SkinPresetSelector({required this.selected, required this.onSelected});

  final SoundSkinPreset selected;
  final ValueChanged<SoundSkinPreset> onSelected;

  @override
  Widget build(BuildContext context) {
    final presets = SoundSkins.presets;
    return Padding(
      key: const ValueKey('skin-preset-selector'),
      padding: const EdgeInsets.fromLTRB(14, 6, 14, 14),
      child: SizedBox(
        height: 108,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 2),
          itemCount: presets.length,
          separatorBuilder: (_, _) => const SizedBox(width: 12),
          itemBuilder: (context, index) {
            final preset = presets[index];
            return _SkinPresetCard(
              preset: preset,
              selected: preset.id == selected.id,
              onTap: () => onSelected(preset),
            );
          },
        ),
      ),
    );
  }
}

class _SkinPresetCard extends StatelessWidget {
  const _SkinPresetCard({
    required this.preset,
    required this.selected,
    required this.onTap,
  });

  final SoundSkinPreset preset;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: '${preset.name} 皮肤',
      child: Tooltip(
        message: preset.description,
        child: InkWell(
          key: ValueKey('skin-preset-${preset.id}'),
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                width: 104,
                height: 68,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: selected
                        ? SoundColors.accent
                        : context.settingsHairline,
                    width: selected ? 2 : 1,
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(11),
                  child: ColoredBox(
                    color: preset.canvas,
                    child: Center(
                      child: FractionallySizedBox(
                        widthFactor: 0.74,
                        heightFactor: 0.64,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: preset.elevated,
                            borderRadius: BorderRadius.circular(7),
                            border: Border.all(color: preset.glass.border),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(8),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  width: 13,
                                  height: 4,
                                  decoration: BoxDecoration(
                                    color: SoundColors.accent,
                                    borderRadius: BorderRadius.circular(2),
                                  ),
                                ),
                                const Spacer(),
                                FractionallySizedBox(
                                  widthFactor: 0.78,
                                  child: Container(
                                    height: 3.5,
                                    decoration: BoxDecoration(
                                      color: preset.glass.primaryText
                                          .withValues(alpha: 0.22),
                                      borderRadius: BorderRadius.circular(2),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 5),
                                FractionallySizedBox(
                                  widthFactor: 0.52,
                                  child: Container(
                                    height: 3.5,
                                    decoration: BoxDecoration(
                                      color: preset.glass.secondaryText
                                          .withValues(alpha: 0.32),
                                      borderRadius: BorderRadius.circular(2),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 7),
              Text(
                preset.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: selected
                      ? SoundColors.accent
                      : _settingsSecondaryText(context),
                  fontSize: 12,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AccentPresetSelector extends StatelessWidget {
  const _AccentPresetSelector({
    required this.selected,
    required this.onSelected,
  });

  final AccentPreset selected;
  final ValueChanged<AccentPreset> onSelected;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 6, 14, 14),
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          for (final preset in SoundColors.accentPresets)
            _AccentPresetSwatch(
              preset: preset,
              selected: preset.id == selected.id,
              onTap: () => onSelected(preset),
            ),
          _CustomAccentSwatch(
            selected: selected.id == 'custom',
            color: selected.id == 'custom'
                ? selected.accent
                : SoundColors.accent,
            onTap: () async {
              final custom = await showDialog<AccentPreset>(
                context: context,
                builder: (context) =>
                    _CustomAccentDialog(initialColor: selected.accent),
              );
              if (custom != null) onSelected(custom);
            },
          ),
        ],
      ),
    );
  }
}

class _AccentPresetSwatch extends StatelessWidget {
  const _AccentPresetSwatch({
    required this.preset,
    required this.selected,
    required this.onTap,
  });

  final AccentPreset preset;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: '${preset.name} 主题色',
      child: Tooltip(
        message: preset.name,
        child: InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: preset.accent,
              shape: BoxShape.circle,
              border: Border.all(
                color: selected
                    ? _settingsPrimaryText(context)
                    : Colors.transparent,
                width: 1.5,
              ),
            ),
            child: selected
                ? Center(
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: preset.onAccent,
                        shape: BoxShape.circle,
                      ),
                    ),
                  )
                : null,
          ),
        ),
      ),
    );
  }
}

class _CustomAccentSwatch extends StatelessWidget {
  const _CustomAccentSwatch({
    required this.selected,
    required this.color,
    required this.onTap,
  });

  final bool selected;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: '自定义主题色',
      child: Tooltip(
        message: '自定义主题色',
        child: InkWell(
          key: const ValueKey('custom-accent-swatch'),
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              gradient: selected
                  ? null
                  : const SweepGradient(
                      colors: [
                        Color(0xFFFF5A4D),
                        Color(0xFFC7842F),
                        Color(0xFF3F9E98),
                        Color(0xFF6673C7),
                        Color(0xFF8067BC),
                        Color(0xFFD95770),
                        Color(0xFFFF5A4D),
                      ],
                    ),
              color: selected ? color : null,
              shape: BoxShape.circle,
              border: Border.all(
                color: selected
                    ? _settingsPrimaryText(context)
                    : context.soundDivider,
                width: selected ? 1.5 : 1,
              ),
            ),
            child: Center(
              child: Text(
                '+',
                style: TextStyle(
                  color: selected
                      ? AccentPreset.readableForeground(color)
                      : Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  height: 1,
                  shadows: selected
                      ? null
                      : const [Shadow(color: Color(0x66000000), blurRadius: 3)],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CustomAccentDialog extends StatefulWidget {
  const _CustomAccentDialog({required this.initialColor});

  final Color initialColor;

  @override
  State<_CustomAccentDialog> createState() => _CustomAccentDialogState();
}

class _CustomAccentDialogState extends State<_CustomAccentDialog> {
  late double _hue;
  late double _saturation;
  late double _brightness;

  Color get _color =>
      HSVColor.fromAHSV(1, _hue, _saturation, _brightness).toColor();

  @override
  void initState() {
    super.initState();
    final hsv = HSVColor.fromColor(widget.initialColor);
    _hue = hsv.hue;
    _saturation = hsv.saturation.clamp(0.30, 1);
    _brightness = hsv.value.clamp(0.40, 0.88);
  }

  @override
  Widget build(BuildContext context) {
    Widget slider({
      required Key key,
      required String label,
      required double value,
      required double min,
      required double max,
      required ValueChanged<double> onChanged,
    }) {
      return Row(
        children: [
          SizedBox(
            width: 52,
            child: Text(
              label,
              style: TextStyle(
                color: _settingsSecondaryText(context),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Slider(
              key: key,
              value: value,
              min: min,
              max: max,
              activeColor: _color,
              onChanged: onChanged,
            ),
          ),
        ],
      );
    }

    return SoundDialog(
      title: const Text('自定义主题色'),
      maxWidth: 440,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AnimatedContainer(
            key: const ValueKey('custom-accent-preview'),
            duration: const Duration(milliseconds: 100),
            height: 86,
            decoration: BoxDecoration(
              color: _color,
              borderRadius: BorderRadius.circular(14),
            ),
            alignment: Alignment.center,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: AccentPreset.readableForeground(_color),
                foregroundColor: _color,
              ),
              onPressed: () {},
              icon: const Icon(KaitingIcons.play),
              label: const Text('主题色预览'),
            ),
          ),
          const SizedBox(height: 18),
          slider(
            key: const ValueKey('custom-accent-hue'),
            label: '色相',
            value: _hue,
            min: 0,
            max: 360,
            onChanged: (value) => setState(() => _hue = value),
          ),
          slider(
            key: const ValueKey('custom-accent-saturation'),
            label: '饱和度',
            value: _saturation,
            min: 0.30,
            max: 1,
            onChanged: (value) => setState(() => _saturation = value),
          ),
          slider(
            key: const ValueKey('custom-accent-brightness'),
            label: '明度',
            value: _brightness,
            min: 0.40,
            max: 0.88,
            onChanged: (value) => setState(() => _brightness = value),
          ),
          const SizedBox(height: 4),
          Text(
            '为保证按钮和图标清晰可读，饱和度与明度限制在安全范围内。',
            style: TextStyle(
              color: _settingsSecondaryText(context),
              fontSize: 12,
              height: 1.4,
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        FilledButton(
          key: const ValueKey('apply-custom-accent'),
          onPressed: () =>
              Navigator.of(context).pop(AccentPreset.custom(_color)),
          child: const Text('使用此颜色'),
        ),
      ],
    );
  }
}
