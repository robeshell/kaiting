import 'package:flutter/material.dart';

import '../../core/sound_theme.dart';

class SourceSettingsScreen extends StatelessWidget {
  const SourceSettingsScreen({
    required this.onOpenPlaybackValidation,
    super.key,
  });

  final VoidCallback onOpenPlaybackValidation;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(32, 36, 32, 140),
      children: [
        const Text(
          '来源',
          style: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.8,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          '管理音乐所在的位置。连接信息和纳入资料库的文件夹彼此独立。',
          style: TextStyle(color: Colors.white54, fontSize: 13),
        ),
        const SizedBox(height: 30),
        Row(
          children: [
            const Expanded(
              child: Text(
                '音乐来源',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
              ),
            ),
            FilledButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.add_rounded),
              label: const Text('添加来源'),
              style: FilledButton.styleFrom(
                backgroundColor: SoundColors.accent,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        const _SourceCard(
          icon: Icons.folder_rounded,
          iconColor: SoundColors.local,
          title: '本机音乐',
          subtitle: '/Users/you/Music',
          status: '已索引 248 首歌曲',
          folders: ['Music', 'Downloads/Hi-Res'],
        ),
        const SizedBox(height: 14),
        const _SourceCard(
          icon: Icons.cloud_rounded,
          iconColor: SoundColors.webDav,
          title: '家庭 NAS',
          subtitle: 'https://nas.local/dav',
          status: '在线 · 上次扫描于 8 分钟前',
          folders: ['音乐/华语', '音乐/欧美'],
        ),
        const SizedBox(height: 30),
        const _FirstReleaseNote(),
        const SizedBox(height: 14),
        OutlinedButton.icon(
          onPressed: onOpenPlaybackValidation,
          icon: const Icon(Icons.science_outlined),
          label: const Text('打开播放验证工具'),
        ),
      ],
    );
  }
}

class _SourceCard extends StatelessWidget {
  const _SourceCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.status,
    required this.folders,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final String status;
  final List<String> folders;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 520;
        return Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.045),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withValues(alpha: 0.11)),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: iconColor.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(icon, color: iconColor),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.white54,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (!compact) ...[
                    const _OnlineDot(),
                    const SizedBox(width: 7),
                    Text(
                      status,
                      style: const TextStyle(
                        fontSize: 11,
                        color: Colors.white54,
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  IconButton(
                    onPressed: () {},
                    icon: const Icon(Icons.more_horiz_rounded),
                  ),
                ],
              ),
              if (compact)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Row(
                    children: [
                      const _OnlineDot(),
                      const SizedBox(width: 7),
                      Expanded(
                        child: Text(
                          status,
                          style: const TextStyle(
                            fontSize: 11,
                            color: Colors.white54,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 15),
              Divider(color: Colors.white.withValues(alpha: 0.07), height: 1),
              const SizedBox(height: 12),
              for (final folder in folders)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    children: [
                      SizedBox(width: compact ? 0 : 58),
                      const Icon(
                        Icons.folder_open_rounded,
                        size: 16,
                        color: Colors.white54,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          folder,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 13),
                        ),
                      ),
                      TextButton(onPressed: () {}, child: const Text('重新扫描')),
                    ],
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _OnlineDot extends StatelessWidget {
  const _OnlineDot();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 8,
      height: 8,
      decoration: const BoxDecoration(
        color: SoundColors.local,
        shape: BoxShape.circle,
      ),
    );
  }
}

class _FirstReleaseNote extends StatelessWidget {
  const _FirstReleaseNote();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: SoundColors.accent.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: SoundColors.accent.withValues(alpha: 0.18)),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.science_outlined, color: SoundColors.accent, size: 20),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              '首个验证版本只实现本地文件夹和 WebDAV。SMB、在线歌词与在线封面会等播放底座稳定后再评估。',
              style: TextStyle(
                fontSize: 12,
                height: 1.5,
                color: Colors.white70,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
