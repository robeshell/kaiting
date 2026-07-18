import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/sound_theme.dart';
import '../../library/scanning/local_library_scanner.dart';
import '../../offline/offline_media_provider.dart';
import '../../playback/playback_controller.dart';
import '../../playback/playback_mode.dart';
import '../../playback/sleep_timer_controller.dart';
import '../../sources/local/local_source_service.dart';
import '../../sources/webdav/webdav_connection_service.dart';
import '../controllers/app_diagnostics_controller.dart';
import '../controllers/offline_download_controller.dart';
import '../widgets/sound_components.dart';
import 'source_settings_screen.dart';

enum SettingsDestination { overview, sources, offline, diagnostics }

enum _SettingsGroup { playback, library, appearance, operation, about }

Color _settingsPrimaryText(BuildContext context) => context.soundPrimaryText
    .withValues(alpha: context.soundPrimaryText.a * 0.88);

Color _settingsSecondaryText(BuildContext context) =>
    context.soundMutedText.withValues(alpha: context.soundMutedText.a * 0.76);

Color _settingsHairline(BuildContext context) =>
    context.soundDivider.withValues(alpha: context.soundDivider.a * 0.68);

extension on _SettingsGroup {
  String get label => switch (this) {
    _SettingsGroup.playback => '播放',
    _SettingsGroup.library => '资料库',
    _SettingsGroup.appearance => '外观',
    _SettingsGroup.operation => '操作',
    _SettingsGroup.about => '关于',
  };
}

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({
    required this.playback,
    required this.localSources,
    required this.scanner,
    required this.onShowKeyboardShortcuts,
    required this.sleepTimer,
    required this.diagnostics,
    this.webDavService,
    this.offline,
    this.initialDestination = SettingsDestination.overview,
    required this.accentPreset,
    required this.onAccentChanged,
    super.key,
  });

  final SoundPlaybackController playback;
  final LocalSourceService localSources;
  final LocalLibraryScanner scanner;
  final WebDavConnectionService? webDavService;
  final OfflineDownloadController? offline;
  final VoidCallback onShowKeyboardShortcuts;
  final SleepTimerController sleepTimer;
  final AppDiagnosticsController diagnostics;
  final SettingsDestination initialDestination;
  final AccentPreset accentPreset;
  final ValueChanged<AccentPreset> onAccentChanged;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late SettingsDestination _destination = widget.initialDestination;
  final ScrollController _overviewScrollController = ScrollController();
  final Map<_SettingsGroup, GlobalKey> _groupKeys = {
    for (final group in _SettingsGroup.values) group: GlobalKey(),
  };
  _SettingsGroup _selectedGroup = _SettingsGroup.playback;
  bool _groupSyncScheduled = false;
  bool _playbackModesExpanded = false;
  bool _sleepTimerExpanded = false;
  bool _accentColorExpanded = false;

  @override
  void initState() {
    super.initState();
    _overviewScrollController.addListener(_scheduleGroupSync);
  }

  @override
  void didUpdateWidget(SettingsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialDestination != widget.initialDestination) {
      _destination = widget.initialDestination;
    }
  }

  @override
  void dispose() {
    _overviewScrollController
      ..removeListener(_scheduleGroupSync)
      ..dispose();
    super.dispose();
  }

  void _scheduleGroupSync() {
    if (_groupSyncScheduled || _destination != SettingsDestination.overview) {
      return;
    }
    _groupSyncScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _groupSyncScheduled = false;
      if (!mounted || _destination != SettingsDestination.overview) return;
      var nearest = _selectedGroup;
      var nearestDistance = double.infinity;
      for (final group in _SettingsGroup.values) {
        final sectionContext = _groupKeys[group]?.currentContext;
        final renderObject = sectionContext?.findRenderObject();
        if (renderObject is! RenderBox || !renderObject.attached) continue;
        final distance = (renderObject.localToGlobal(Offset.zero).dy - 74)
            .abs();
        if (distance < nearestDistance) {
          nearest = group;
          nearestDistance = distance;
        }
      }
      if (nearest != _selectedGroup) setState(() => _selectedGroup = nearest);
    });
  }

  Future<void> _scrollToGroup(_SettingsGroup group) async {
    setState(() => _selectedGroup = group);
    final sectionContext = _groupKeys[group]?.currentContext;
    final renderObject = sectionContext?.findRenderObject();
    if (renderObject is! RenderBox ||
        !renderObject.attached ||
        !_overviewScrollController.hasClients) {
      return;
    }
    final position = _overviewScrollController.position;
    final target =
        (_overviewScrollController.offset +
                renderObject.localToGlobal(Offset.zero).dy -
                72)
            .clamp(position.minScrollExtent, position.maxScrollExtent)
            .toDouble();
    await _overviewScrollController.animateTo(
      target,
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_destination == SettingsDestination.sources) {
      return _withCompactBackNavigation(
        context,
        SourceSettingsScreen(
          localSources: widget.localSources,
          scanner: widget.scanner,
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
    if (_destination == SettingsDestination.diagnostics) {
      return _withCompactBackNavigation(
        context,
        DiagnosticsSettingsView(
          diagnostics: widget.diagnostics,
          onBack: () =>
              setState(() => _destination = SettingsDestination.overview),
        ),
      );
    }

    return AnimatedBuilder(
      animation: Listenable.merge([
        widget.playback,
        widget.sleepTimer,
        widget.diagnostics,
        ?widget.offline,
      ]),
      builder: (context, _) {
        final compact = context.soundIsCompact;
        if (compact) return _buildCompactOverview(context);
        return CustomScrollView(
          key: const ValueKey('settings-overview'),
          controller: _overviewScrollController,
          slivers: [
            SliverPersistentHeader(
              pinned: false,
              delegate: _SettingsTabsHeader(
                selected: _selectedGroup,
                onSelected: (group) => unawaited(_scrollToGroup(group)),
              ),
            ),
            SliverPadding(
              padding: EdgeInsets.fromLTRB(
                context.soundPageGutter,
                14,
                context.soundPageGutter,
                context.soundContentBottomPadding,
              ),
              sliver: SliverToBoxAdapter(
                child: Column(
                  children: [
                    _SettingsSection(
                      key: _groupKeys[_SettingsGroup.playback],
                      title: '播放',
                      flat: true,
                      children: [
                        _SettingsRow(
                          flat: true,
                          icon: _playbackModeIcon(widget.playback.playbackMode),
                          iconColor: SoundColors.accent,
                          title: '播放模式',
                          subtitle: '控制队列结束和切歌时的行为',
                          value: widget.playback.playbackMode.label,
                          expanded: _playbackModesExpanded,
                          onTap: () => setState(
                            () => _playbackModesExpanded =
                                !_playbackModesExpanded,
                          ),
                        ),
                        if (_playbackModesExpanded)
                          _PlaybackModeSelector(
                            selected: widget.playback.playbackMode,
                            onSelected: (mode) {
                              widget.playback.setPlaybackMode(mode);
                              setState(() => _playbackModesExpanded = false);
                            },
                          ),
                        _SettingsRow(
                          key: const ValueKey('settings-sleep-timer-row'),
                          flat: true,
                          icon: Icons.bedtime_outlined,
                          iconColor: SoundColors.webDav,
                          title: '睡眠定时',
                          subtitle: '定时暂停，或在当前歌曲播放结束后停止',
                          value: _sleepTimerLabel(widget.sleepTimer),
                          expanded: _sleepTimerExpanded,
                          onTap: () => setState(
                            () => _sleepTimerExpanded = !_sleepTimerExpanded,
                          ),
                        ),
                        if (_sleepTimerExpanded)
                          _SleepTimerSelector(
                            timer: widget.sleepTimer,
                            hasTrack: widget.playback.displayTrack != null,
                          ),
                      ],
                    ),
                    const SizedBox(height: 28),
                    _SettingsSection(
                      key: _groupKeys[_SettingsGroup.library],
                      title: '资料库',
                      flat: true,
                      children: [
                        _SettingsRow(
                          key: const ValueKey('settings-sources-row'),
                          flat: true,
                          icon: Icons.library_music_rounded,
                          iconColor: SoundColors.local,
                          title: '音乐来源',
                          subtitle: '管理本地文件夹、WebDAV 服务器和扫描目录',
                          onTap: () => setState(
                            () => _destination = SettingsDestination.sources,
                          ),
                        ),
                        if (widget.offline != null)
                          _SettingsRow(
                            key: const ValueKey('settings-offline-row'),
                            flat: true,
                            icon: Icons.download_for_offline_outlined,
                            iconColor: SoundColors.webDav,
                            title: '离线与缓存',
                            subtitle: '管理远程来源的离线歌曲、临时缓存和存储空间',
                            value: _formatBytes(
                              widget.offline!.stats.totalBytes,
                            ),
                            onTap: () => setState(
                              () => _destination = SettingsDestination.offline,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 28),
                    _SettingsSection(
                      key: _groupKeys[_SettingsGroup.appearance],
                      title: '外观',
                      children: [
                        _SettingsRow(
                          key: const ValueKey('settings-accent-row'),
                          icon: Icons.palette_outlined,
                          iconColor: SoundColors.accent,
                          title: '主题色',
                          subtitle: '调整应用按钮和图标的强调色',
                          value: widget.accentPreset.name,
                          expanded: _accentColorExpanded,
                          onTap: () => setState(
                            () => _accentColorExpanded = !_accentColorExpanded,
                          ),
                        ),
                        if (_accentColorExpanded)
                          _AccentPresetSelector(
                            selected: widget.accentPreset,
                            onSelected: widget.onAccentChanged,
                          ),
                      ],
                    ),
                    const SizedBox(height: 28),
                    _SettingsSection(
                      key: _groupKeys[_SettingsGroup.operation],
                      title: '操作',
                      flat: true,
                      children: [
                        if (soundUsesDesktopPlatform)
                          _SettingsRow(
                            flat: true,
                            icon: Icons.keyboard_alt_outlined,
                            iconColor: context.soundSecondaryText,
                            title: '键盘快捷键',
                            subtitle: '查看播放、导航和搜索快捷键',
                            onTap: widget.onShowKeyboardShortcuts,
                          ),
                        _SettingsRow(
                          key: const ValueKey('settings-diagnostics-row'),
                          flat: true,
                          icon: Icons.health_and_safety_outlined,
                          iconColor: widget.diagnostics.problemCount == 0
                              ? context.soundSecondaryText
                              : SoundColors.accent,
                          title: '问题与诊断',
                          subtitle: '查看播放、来源和资料库的最近错误',
                          value: widget.diagnostics.problemCount == 0
                              ? '没有问题'
                              : '${widget.diagnostics.problemCount} 条',
                          onTap: () => setState(
                            () =>
                                _destination = SettingsDestination.diagnostics,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 28),
                    _SettingsSection(
                      key: _groupKeys[_SettingsGroup.about],
                      title: '关于',
                      flat: true,
                      children: const [
                        _SettingsRow(
                          flat: true,
                          icon: Icons.graphic_eq_rounded,
                          iconColor: SoundColors.webDav,
                          title: 'Reverie',
                          subtitle: '跨平台本地与远程音乐播放器',
                          value: '开发版本',
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
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

  Widget _buildCompactOverview(BuildContext context) {
    return CustomScrollView(
      key: const ValueKey('settings-overview'),
      controller: _overviewScrollController,
      slivers: [
        SliverPadding(
          padding: EdgeInsets.fromLTRB(
            context.soundPageGutter,
            12,
            context.soundPageGutter,
            context.soundContentBottomPadding,
          ),
          sliver: SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '设置',
                  key: const ValueKey('compact-settings-title'),
                  style: TextStyle(
                    color: _settingsPrimaryText(context),
                    fontSize: context.soundPageTitleSize,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 22),
                _SettingsSection(
                  key: _groupKeys[_SettingsGroup.playback],
                  title: '播放',
                  children: [
                    _SettingsRow(
                      key: const ValueKey('settings-playback-mode-row'),
                      icon: _playbackModeIcon(widget.playback.playbackMode),
                      iconColor: SoundColors.accent,
                      title: '播放模式',
                      subtitle: '设置队列结束和切歌方式',
                      value: widget.playback.playbackMode.label,
                      onTap: () =>
                          unawaited(_showCompactPlaybackModeSheet(context)),
                    ),
                    _SettingsRow(
                      key: const ValueKey('settings-sleep-timer-row'),
                      icon: Icons.bedtime_outlined,
                      iconColor: SoundColors.webDav,
                      title: '睡眠定时',
                      subtitle: '定时停止播放',
                      value: _sleepTimerLabel(widget.sleepTimer),
                      onTap: () =>
                          unawaited(_showCompactSleepTimerSheet(context)),
                    ),
                  ],
                ),
                const SizedBox(height: 22),
                _SettingsSection(
                  key: _groupKeys[_SettingsGroup.library],
                  title: '资料库',
                  children: [
                    _SettingsRow(
                      key: const ValueKey('settings-sources-row'),
                      icon: Icons.library_music_rounded,
                      iconColor: SoundColors.local,
                      title: '音乐来源',
                      subtitle: '本地文件夹与远程音乐目录',
                      onTap: () => setState(
                        () => _destination = SettingsDestination.sources,
                      ),
                    ),
                    if (widget.offline != null)
                      _SettingsRow(
                        key: const ValueKey('settings-offline-row'),
                        icon: Icons.download_for_offline_outlined,
                        iconColor: SoundColors.webDav,
                        title: '离线与缓存',
                        subtitle: '下载内容与存储空间',
                        value: _formatBytes(widget.offline!.stats.totalBytes),
                        onTap: () => setState(
                          () => _destination = SettingsDestination.offline,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 22),
                _SettingsSection(
                  key: _groupKeys[_SettingsGroup.appearance],
                  title: '外观',
                  children: [
                    _SettingsRow(
                      key: const ValueKey('settings-accent-row'),
                      icon: Icons.palette_outlined,
                      iconColor: SoundColors.accent,
                      title: '主题色',
                      subtitle: '调整应用按钮和图标的强调色',
                      value: widget.accentPreset.name,
                      expanded: _accentColorExpanded,
                      onTap: () => setState(
                        () => _accentColorExpanded = !_accentColorExpanded,
                      ),
                    ),
                    if (_accentColorExpanded)
                      _AccentPresetSelector(
                        selected: widget.accentPreset,
                        onSelected: widget.onAccentChanged,
                      ),
                  ],
                ),
                const SizedBox(height: 22),
                _SettingsSection(
                  key: _groupKeys[_SettingsGroup.operation],
                  title: '支持',
                  children: [
                    _SettingsRow(
                      key: const ValueKey('settings-diagnostics-row'),
                      icon: Icons.health_and_safety_outlined,
                      iconColor: widget.diagnostics.problemCount == 0
                          ? context.soundSecondaryText
                          : SoundColors.accent,
                      title: '问题与诊断',
                      subtitle: '查看播放、来源和资料库问题',
                      value: widget.diagnostics.problemCount == 0
                          ? '正常'
                          : '${widget.diagnostics.problemCount} 条',
                      onTap: () => setState(
                        () => _destination = SettingsDestination.diagnostics,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 22),
                _SettingsSection(
                  key: _groupKeys[_SettingsGroup.about],
                  title: '关于',
                  children: const [
                    _SettingsRow(
                      icon: Icons.graphic_eq_rounded,
                      iconColor: SoundColors.webDav,
                      title: 'Reverie',
                      subtitle: '本地与远程音乐播放器',
                      value: '开发版本',
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
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

class _SettingsTabsHeader extends SliverPersistentHeaderDelegate {
  const _SettingsTabsHeader({required this.selected, required this.onSelected});

  final _SettingsGroup selected;
  final ValueChanged<_SettingsGroup> onSelected;

  @override
  double get minExtent => 46;

  @override
  double get maxExtent => 46;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: EdgeInsets.symmetric(horizontal: context.soundPageGutter),
      child: Row(
        children: [
          for (final group in _SettingsGroup.values)
            _SettingsGroupTab(
              group: group,
              selected: group == selected,
              onTap: () => onSelected(group),
            ),
        ],
      ),
    );
  }

  @override
  bool shouldRebuild(_SettingsTabsHeader oldDelegate) {
    return selected != oldDelegate.selected ||
        onSelected != oldDelegate.onSelected;
  }
}

class _SettingsGroupTab extends StatelessWidget {
  const _SettingsGroupTab({
    required this.group,
    required this.selected,
    required this.onTap,
  });

  final _SettingsGroup group;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      selected: selected,
      button: true,
      child: InkWell(
        key: ValueKey('settings-group-${group.name}'),
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: SizedBox(
          height: 46,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  group.label,
                  style: TextStyle(
                    color: selected
                        ? SoundColors.accent
                        : _settingsSecondaryText(context),
                    fontSize: 12,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 9),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  width: selected ? 20 : 0,
                  height: 2,
                  decoration: BoxDecoration(
                    color: SoundColors.accent,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ],
            ),
          ),
        ),
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
              style: TextStyle(
                color: _settingsPrimaryText(context),
                fontSize: 20,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(
                color: _settingsSecondaryText(context),
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 14),
            for (var index = 0; index < children.length; index++) ...[
              children[index],
              if (index != children.length - 1)
                Divider(
                  height: 1,
                  indent: 4,
                  color: _settingsHairline(context),
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
                    style: TextStyle(
                      color: foreground,
                      fontSize: 14,
                      fontWeight: selected || destructive
                          ? FontWeight.w700
                          : FontWeight.w600,
                    ),
                  ),
                ),
                if (selected)
                  Icon(
                    Icons.check_rounded,
                    size: 20,
                    color: SoundColors.accent,
                  ),
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
    return Padding(
      padding: const EdgeInsets.fromLTRB(38, 4, 0, 14),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final minutes in durations)
            ChoiceChip(
              key: ValueKey('sleep-timer-$minutes'),
              label: Text('$minutes 分钟'),
              visualDensity: VisualDensity.compact,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              selected:
                  timer.mode == SleepTimerMode.duration &&
                  timer.remaining.inMinutes <= minutes &&
                  timer.remaining.inMinutes >= minutes - 1,
              onSelected: (_) => timer.start(Duration(minutes: minutes)),
            ),
          ChoiceChip(
            key: const ValueKey('sleep-timer-end-of-track'),
            label: const Text('播完当前歌曲'),
            visualDensity: VisualDensity.compact,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            selected: timer.mode == SleepTimerMode.endOfTrack,
            onSelected: hasTrack ? (_) => timer.stopAfterCurrentTrack() : null,
          ),
          if (timer.isActive)
            ActionChip(
              key: const ValueKey('sleep-timer-cancel'),
              avatar: const Icon(Icons.close_rounded, size: 15),
              label: const Text('取消定时'),
              visualDensity: VisualDensity.compact,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              onPressed: timer.cancel,
            ),
        ],
      ),
    );
  }
}

class DiagnosticsSettingsView extends StatelessWidget {
  const DiagnosticsSettingsView({
    required this.diagnostics,
    required this.onBack,
    super.key,
  });

  final AppDiagnosticsController diagnostics;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: diagnostics,
      builder: (context, _) => ListView(
        key: const ValueKey('diagnostics-settings'),
        padding: EdgeInsets.fromLTRB(
          context.soundPageGutter,
          20,
          context.soundPageGutter,
          context.soundContentBottomPadding,
        ),
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: IconButton(
              key: const ValueKey('diagnostics-settings-back'),
              onPressed: onBack,
              tooltip: '返回设置',
              icon: const Icon(Icons.arrow_back_rounded),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Text(
                  '问题与诊断',
                  style: TextStyle(
                    fontSize: context.soundPageTitleSize,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.45,
                  ),
                ),
              ),
              TextButton.icon(
                key: const ValueKey('copy-diagnostics'),
                onPressed: () async {
                  await Clipboard.setData(
                    ClipboardData(text: diagnostics.exportText()),
                  );
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('诊断信息已复制，不包含密码')),
                    );
                  }
                },
                icon: const Icon(Icons.copy_all_outlined),
                label: const Text('复制'),
              ),
              if (diagnostics.events.isNotEmpty)
                TextButton(
                  key: const ValueKey('clear-diagnostics'),
                  onPressed: diagnostics.clear,
                  style: context.soundDestructiveButtonStyle,
                  child: const Text('清空'),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '仅记录本次运行中的错误类型和技术信息，不记录 WebDAV 密码。',
            style: TextStyle(
              color: _settingsSecondaryText(context),
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 18),
          if (diagnostics.events.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 28),
              child: Center(
                child: Text(
                  '当前没有已记录的问题',
                  style: TextStyle(color: _settingsSecondaryText(context)),
                ),
              ),
            )
          else
            for (final event in diagnostics.events.reversed)
              _DiagnosticEventCard(event: event),
        ],
      ),
    );
  }
}

class _DiagnosticEventCard extends StatelessWidget {
  const _DiagnosticEventCard({required this.event});

  final DiagnosticEvent event;

  @override
  Widget build(BuildContext context) {
    final localTime = event.occurredAt.toLocal();
    final timestamp =
        '${localTime.hour.toString().padLeft(2, '0')}:'
        '${localTime.minute.toString().padLeft(2, '0')}:'
        '${localTime.second.toString().padLeft(2, '0')}';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 14),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: _settingsHairline(context))),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.error_outline_rounded,
            color: context.soundColors.error,
            size: 17,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  event.failure.title,
                  style: TextStyle(
                    color: _settingsPrimaryText(context),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  event.failure.message,
                  style: TextStyle(
                    color: _settingsSecondaryText(context),
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 7),
                SelectableText(
                  event.failure.rawMessage,
                  style: TextStyle(
                    color: _settingsSecondaryText(context),
                    fontSize: 11,
                  ),
                ),
                if (event.context case final value?) ...[
                  const SizedBox(height: 5),
                  Text(
                    value,
                    style: TextStyle(
                      color: _settingsSecondaryText(context),
                      fontSize: 11,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 10),
          Text(
            timestamp,
            style: TextStyle(
              color: _settingsSecondaryText(context),
              fontSize: 10,
            ),
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
        return ListView(
          key: const ValueKey('offline-settings'),
          padding: EdgeInsets.fromLTRB(
            context.soundPageGutter,
            20,
            context.soundPageGutter,
            context.soundContentBottomPadding,
          ),
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: IconButton(
                key: const ValueKey('offline-settings-back'),
                onPressed: onBack,
                tooltip: '返回设置',
                icon: const Icon(Icons.arrow_back_rounded),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              '离线与缓存',
              style: TextStyle(
                fontSize: context.soundPageTitleSize,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.45,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '主动保存的歌曲不会被临时缓存清理。',
              style: TextStyle(
                color: _settingsSecondaryText(context),
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 22),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _formatBytes(stats.totalBytes),
                    key: const ValueKey('offline-total-size'),
                    style: TextStyle(
                      color: _settingsPrimaryText(context),
                      fontSize: 26,
                      height: 1,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.55,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    'Reverie 当前使用的音频存储',
                    style: TextStyle(
                      color: _settingsSecondaryText(context),
                      fontSize: 11.5,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Divider(height: 1, color: _settingsHairline(context)),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final compact = constraints.maxWidth < 520;
                      final statsRows = [
                        _OfflineStat(
                          icon: Icons.cloud_done_rounded,
                          label: '离线下载',
                          value: _formatBytes(stats.pinnedBytes),
                          detail: '${stats.pinnedEntries} 首',
                          color: SoundColors.webDav,
                        ),
                        _OfflineStat(
                          icon: Icons.bolt_rounded,
                          label: '临时缓存',
                          value: _formatBytes(stats.transientBytes),
                          detail: '${stats.transientEntries} 个文件',
                          color: SoundColors.accent,
                        ),
                      ];
                      return compact
                          ? Column(
                              children: [
                                statsRows.first,
                                Divider(
                                  height: 1,
                                  indent: 32,
                                  color: _settingsHairline(context),
                                ),
                                statsRows.last,
                              ],
                            )
                          : Row(
                              children: [
                                Expanded(child: statsRows.first),
                                Container(
                                  width: 1,
                                  height: 34,
                                  color: _settingsHairline(context),
                                ),
                                Expanded(child: statsRows.last),
                              ],
                            );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),
            _OfflineDownloadsPanel(
              items: offlineItems,
              onCancel: (item) => _cancelDownload(context, item),
              onRetry: (item) => unawaited(_retryDownload(context, item)),
              onRemove: (item) => unawaited(_removeDownload(context, item)),
            ),
            const SizedBox(height: 22),
            _SettingsSection(
              title: '存储管理',
              children: [
                _SettingsRow(
                  key: const ValueKey('clear-transient-cache'),
                  icon: Icons.cleaning_services_outlined,
                  iconColor: SoundColors.webDav,
                  title: '清理临时缓存',
                  subtitle: '只删除播放时生成的缓存，保留主动离线保存的歌曲',
                  value: _formatBytes(stats.transientBytes),
                  onTap: stats.transientEntries == 0
                      ? null
                      : () => unawaited(_clearTransient(context)),
                ),
                _SettingsRow(
                  key: const ValueKey('clear-all-offline'),
                  icon: Icons.delete_sweep_outlined,
                  iconColor: SoundColors.accent,
                  title: '删除全部音频缓存',
                  subtitle: '同时移除离线下载和临时缓存，不影响来源文件',
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
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 10),
          child: Row(
            children: [
              Text(
                '下载与离线内容',
                style: TextStyle(
                  color: _settingsSecondaryText(context),
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              Text(
                '${items.length} 项',
                style: TextStyle(
                  color: _settingsSecondaryText(context),
                  fontSize: 11.5,
                ),
              ),
            ],
          ),
        ),
        if (items.isEmpty)
          const _OfflineDownloadsEmpty()
        else if (items.length <= 5)
          Column(
            children: [
              for (var index = 0; index < items.length; index++) ...[
                _OfflineDownloadRow(
                  item: items[index],
                  onCancel: onCancel,
                  onRetry: onRetry,
                  onRemove: onRemove,
                ),
                if (index != items.length - 1)
                  Divider(
                    height: 1,
                    indent: 42,
                    color: _settingsHairline(context),
                  ),
              ],
            ],
          )
        else
          SizedBox(
            height: 430,
            child: ListView.separated(
              primary: false,
              itemCount: items.length,
              itemBuilder: (context, index) => _OfflineDownloadRow(
                item: items[index],
                onCancel: onCancel,
                onRetry: onRetry,
                onRemove: onRemove,
              ),
              separatorBuilder: (_, _) => Divider(
                height: 1,
                indent: 42,
                color: _settingsHairline(context),
              ),
            ),
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
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 20),
      child: Row(
        children: [
          Icon(
            Icons.download_for_offline_outlined,
            size: 18,
            color: _settingsSecondaryText(context),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '还没有离线内容',
                  style: TextStyle(
                    color: _settingsPrimaryText(context),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '在支持离线的专辑或歌曲菜单中选择“离线保存”。',
                  style: TextStyle(
                    color: _settingsSecondaryText(context),
                    fontSize: 11.5,
                  ),
                ),
              ],
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
        ? task?.error ?? '下载失败'
        : [
            item.artist,
            item.albumTitle,
            if (downloading)
              task?.totalBytes == null
                  ? _formatBytes(task?.receivedBytes ?? 0)
                  : '${_formatBytes(task!.receivedBytes)} / ${_formatBytes(task.totalBytes!)}'
            else
              _formatBytes(item.size),
          ].join(' · ');
    final statusColor = failed
        ? context.soundColors.error
        : downloading
        ? SoundColors.webDav
        : SoundColors.local;
    final status = SizedBox(
      width: 28,
      height: 28,
      child: downloading
          ? Padding(
              padding: const EdgeInsets.all(5),
              child: CircularProgressIndicator(
                value: task?.progress,
                strokeWidth: 2,
                color: statusColor,
              ),
            )
          : Icon(
              failed ? Icons.error_outline_rounded : Icons.cloud_done_rounded,
              size: 18,
              color: statusColor.withValues(alpha: statusColor.a * 0.82),
            ),
    );

    if (context.soundIsCompact) {
      return SoundCompactMediaRow(
        key: ValueKey('offline-item-${item.reference.storageKey}'),
        leading: status,
        title: item.title,
        subtitle: subtitle,
        titleColor: failed ? context.soundColors.error : null,
        trailing: PopupMenuButton<String>(
          key: ValueKey('offline-actions-${item.reference.storageKey}'),
          tooltip: '更多操作 ${item.title}',
          padding: EdgeInsets.zero,
          icon: const Icon(Icons.more_horiz_rounded, size: 21),
          onSelected: (value) {
            if (value == 'cancel') onCancel(item);
            if (value == 'retry') onRetry(item);
            if (value == 'remove') onRemove(item);
          },
          itemBuilder: (_) => [
            if (downloading)
              const PopupMenuItem(value: 'cancel', child: Text('取消下载')),
            if (failed && item.canRetry)
              const PopupMenuItem(value: 'retry', child: Text('重试下载')),
            if (failed)
              const PopupMenuItem(value: 'remove', child: Text('移除失败记录')),
            if (!downloading && !failed)
              const PopupMenuItem(value: 'remove', child: Text('移除离线下载')),
          ],
        ),
      );
    }

    return Padding(
      key: ValueKey('offline-item-${item.reference.storageKey}'),
      padding: const EdgeInsets.fromLTRB(4, 10, 0, 10),
      child: Row(
        children: [
          status,
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: failed
                        ? SoundColors.accent
                        : _settingsPrimaryText(context),
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  maxLines: failed ? 2 : 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: failed
                        ? SoundColors.accent
                        : _settingsSecondaryText(context),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (downloading)
            IconButton(
              key: ValueKey('offline-cancel-${item.reference.storageKey}'),
              onPressed: () => onCancel(item),
              tooltip: '取消下载',
              icon: const Icon(Icons.close_rounded),
            )
          else if (failed)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  key: ValueKey('offline-dismiss-${item.reference.storageKey}'),
                  onPressed: () => onRemove(item),
                  tooltip: '移除失败记录',
                  icon: const Icon(Icons.close_rounded),
                ),
                IconButton(
                  key: ValueKey('offline-retry-${item.reference.storageKey}'),
                  onPressed: item.canRetry ? () => onRetry(item) : null,
                  tooltip: item.canRetry ? '重试下载' : '来源已不在资料库',
                  icon: const Icon(Icons.refresh_rounded),
                ),
              ],
            )
          else
            IconButton(
              key: ValueKey('offline-remove-${item.reference.storageKey}'),
              onPressed: () => onRemove(item),
              tooltip: '移除离线下载',
              icon: const Icon(Icons.delete_outline_rounded),
            ),
        ],
      ),
    );
  }
}

class _OfflineStat extends StatelessWidget {
  const _OfflineStat({
    required this.icon,
    required this.label,
    required this.value,
    required this.detail,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final String detail;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      child: Row(
        children: [
          Icon(icon, color: color.withValues(alpha: color.a * 0.78), size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: _settingsSecondaryText(context),
                    fontSize: 11,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    color: _settingsPrimaryText(context),
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          Text(
            detail,
            style: TextStyle(
              color: _settingsSecondaryText(context),
              fontSize: 11,
            ),
          ),
        ],
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
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
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
  PlaybackMode.sequential => Icons.arrow_right_alt_rounded,
  PlaybackMode.repeatOne => Icons.repeat_one_rounded,
  PlaybackMode.repeatAll => Icons.repeat_rounded,
  PlaybackMode.shuffle => Icons.shuffle_rounded,
};

class _SettingsSection extends StatelessWidget {
  const _SettingsSection({
    required this.title,
    required this.children,
    this.flat = false,
    super.key,
  });

  final String title;
  final List<Widget> children;
  final bool flat;

  @override
  Widget build(BuildContext context) {
    final compact = context.soundIsCompact;
    final rows = Column(
      children: [
        for (var index = 0; index < children.length; index++) ...[
          children[index],
          if (index != children.length - 1)
            Divider(
              height: 1,
              indent: compact ? 4 : 38,
              color: _settingsHairline(context),
            ),
        ],
      ],
    );
    if (flat) {
      return rows;
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 10),
          child: Text(
            title,
            style: TextStyle(
              color: _settingsSecondaryText(context),
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        rows,
      ],
    );
  }
}

class _SettingsRow extends StatelessWidget {
  const _SettingsRow({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    this.flat = false,
    this.value,
    this.onTap,
    this.expanded = false,
    super.key,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final bool flat;
  final String? value;
  final VoidCallback? onTap;
  final bool expanded;

  @override
  Widget build(BuildContext context) {
    final compact = context.soundIsCompact;
    return Semantics(
      button: onTap != null,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: flat ? 0 : 4, vertical: 11),
          child: Row(
            children: [
              if (!compact) ...[
                SizedBox(
                  width: 24,
                  child: Icon(
                    icon,
                    size: 17,
                    color: flat
                        ? _settingsSecondaryText(context)
                        : iconColor.withValues(alpha: iconColor.a * 0.78),
                  ),
                ),
                const SizedBox(width: 14),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: _settingsPrimaryText(context),
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: _settingsSecondaryText(context),
                        fontSize: 11.5,
                      ),
                    ),
                  ],
                ),
              ),
              if (value != null) ...[
                const SizedBox(width: 12),
                Text(
                  value!,
                  style: TextStyle(
                    color: _settingsSecondaryText(context),
                    fontSize: 11.5,
                  ),
                ),
              ],
              if (onTap != null) ...[
                const SizedBox(width: 8),
                Icon(
                  expanded
                      ? Icons.keyboard_arrow_up_rounded
                      : Icons.chevron_right_rounded,
                  size: 18,
                  color: _settingsSecondaryText(context),
                ),
              ],
            ],
          ),
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
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 680 ? 4 : 2;
        const gap = 8.0;
        final itemWidth =
            (constraints.maxWidth - 38 - gap * (columns - 1)) / columns;
        return Padding(
          padding: const EdgeInsets.fromLTRB(38, 7, 0, 13),
          child: Wrap(
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
          ),
        );
      },
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
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                    color: selected
                        ? SoundColors.accent
                        : _settingsSecondaryText(context),
                  ),
                ),
              ),
              if (selected)
                Icon(Icons.check_rounded, size: 17, color: SoundColors.accent),
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
      padding: const EdgeInsets.fromLTRB(4, 7, 0, 13),
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          for (final preset in SoundColors.accentPresets)
            _AccentPresetSwatch(
              preset: preset,
              selected: preset.id == selected.id,
              onTap: () => onSelected(preset),
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
          borderRadius: BorderRadius.circular(14),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: preset.accent,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: selected
                    ? _settingsPrimaryText(context)
                    : Colors.transparent,
                width: selected ? 3 : 0,
              ),
              boxShadow: selected
                  ? [
                      BoxShadow(
                        color: preset.accent.withValues(alpha: 0.35),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ]
                  : null,
            ),
            child: selected
                ? Icon(Icons.check_rounded, color: preset.onAccent, size: 20)
                : null,
          ),
        ),
      ),
    );
  }
}
