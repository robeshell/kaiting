import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

const kaitingLaunchBackground = Color(0xFFF7F7F8);
const kaitingLaunchTitleColor = Color(0xFF1C1C22);
const kaitingLaunchSubtitleColor = Color(0xFF70707A);

class KaitingLaunchApp extends StatelessWidget {
  const KaitingLaunchApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: KaitingLaunchScreen(),
    );
  }
}

class KaitingLaunchScreen extends StatelessWidget {
  const KaitingLaunchScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
        systemNavigationBarColor: kaitingLaunchBackground,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: kaitingLaunchBackground,
        body: Center(child: _KaitingLaunchLockup()),
      ),
    );
  }
}

class _KaitingLaunchLockup extends StatelessWidget {
  const _KaitingLaunchLockup();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '开听 正在启动',
      child: SizedBox(
        width: 280,
        height: 260,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Transform.translate(
              offset: const Offset(0, -50),
              child: Image.asset(
                'assets/branding/launch_mark.png',
                width: 144,
                height: 144,
                filterQuality: FilterQuality.high,
                excludeFromSemantics: true,
              ),
            ),
            Transform.translate(
              offset: const Offset(0, 28),
              child: const Text(
                '开听',
                style: TextStyle(
                  color: kaitingLaunchTitleColor,
                  fontSize: 24,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.2,
                ),
              ),
            ),
            Transform.translate(
              offset: const Offset(0, 58),
              child: const Text(
                '听自己的音乐',
                style: TextStyle(
                  color: kaitingLaunchSubtitleColor,
                  fontSize: 13,
                  fontWeight: FontWeight.w400,
                  letterSpacing: 0.1,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
