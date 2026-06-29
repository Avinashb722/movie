import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme/app_theme.dart';

class FlixoDownloadScreen extends StatelessWidget {
  const FlixoDownloadScreen({super.key});

  // Separate App Download URLs
  static const String androidUrl = 'https://flixo.app/downloads/android.apk';
  static const String iosUrl = 'https://apps.apple.com/app/flixo-app';
  static const String webUrl = 'https://flixo.app/';
  static const String tvUrl = 'https://flixo.app/downloads/flixo-tv.apk';
  static const String windowsUrl = 'https://flixo.app/downloads/flixo-setup.exe';
  static const String macosUrl = 'https://flixo.app/downloads/flixo.dmg';

  Future<void> _launchURL(String urlString) async {
    try {
      final uri = Uri.parse(urlString);
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      debugPrint('Could not launch $urlString: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = kIsWeb && MediaQuery.of(context).size.width > 768;

    final cards = [
      _buildPlatformCard(
        context,
        platformName: 'Android App',
        description: 'Get the best experience on your Android phone or tablet.',
        buttonLabel: 'GET IT ON Google Play',
        iconData: Icons.android_rounded,
        imagePath: 'android_download.png',
        isGooglePlayStyle: true,
        onPressed: () => _launchURL(androidUrl),
      ),
      _buildPlatformCard(
        context,
        platformName: 'iOS App',
        description: 'Download on your iPhone or iPad and enjoy on the go.',
        buttonLabel: 'Download on the App Store',
        iconData: Icons.apple_rounded,
        imagePath: 'iphone.png',
        isAppStoreStyle: true,
        onPressed: () => _launchURL(iosUrl),
      ),
      _buildPlatformCard(
        context,
        platformName: 'Web App',
        description: 'Stream instantly on your favorite web browser.',
        buttonLabel: 'Open Web App',
        iconData: Icons.language,
        imagePath: 'decatop.png',
        isYellowButton: true,
        onPressed: () => _launchURL(webUrl),
      ),
      _buildPlatformCard(
        context,
        platformName: 'Android TV',
        description: 'Install on Android TV and enjoy on the big screen.',
        buttonLabel: 'Download for TV',
        iconData: Icons.tv_rounded,
        imagePath: 'android_tv.png',
        isYellowButton: true,
        onPressed: () => _launchURL(tvUrl),
      ),
      _buildPlatformCard(
        context,
        platformName: 'Desktop App',
        description: 'Download for Windows or macOS and watch anywhere.',
        buttonLabel: 'Download for Windows',
        secondButtonLabel: 'Download for macOS',
        iconData: Icons.desktop_windows_rounded,
        imagePath: 'decatop.png',
        isDesktopRow: true,
        onPressed: () => _launchURL(windowsUrl),
        onSecondPressed: () => _launchURL(macosUrl),
      ),
    ];

    return Scaffold(
      backgroundColor: isDesktop ? AppColors.background : Colors.black,
      appBar: isDesktop
          ? null
          : AppBar(
              backgroundColor: Colors.black,
              elevation: 0,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
                onPressed: () => Navigator.pop(context),
              ),
              title: const Text('Download App', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
            ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: 10),
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  'Download ',
                  style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w900),
                ),
                Text(
                  'FLIXO',
                  style: TextStyle(
                    color: AppColors.accent,
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    shadows: [
                      Shadow(
                        color: AppColors.accent.withValues(alpha: 0.5),
                        blurRadius: 15,
                      )
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            const Text(
              'Watch unlimited movies, TV shows, and live channels\nanytime, anywhere.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
            ),
            const SizedBox(height: 24),

            // Features Row
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildFeature(Icons.download_for_offline_outlined, 'Fast & Easy', 'Quick installation'),
                  const SizedBox(width: 14),
                  _buildFeature(Icons.shield_outlined, 'Safe & Secure', '100% trusted'),
                  const SizedBox(width: 14),
                  _buildFeature(Icons.devices_other, 'All Devices', 'One account everywhere'),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // Platform Cards Responsive Layout
            if (isDesktop)
              Column(
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: cards[0]),
                      const SizedBox(width: 20),
                      Expanded(child: cards[1]),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: cards[2]),
                      const SizedBox(width: 20),
                      Expanded(child: cards[3]),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: cards[4]),
                      const SizedBox(width: 20),
                      const Expanded(child: SizedBox()),
                    ],
                  ),
                ],
              )
            else
              Column(
                children: [
                  cards[0], const SizedBox(height: 20),
                  cards[1], const SizedBox(height: 20),
                  cards[2], const SizedBox(height: 20),
                  cards[3], const SizedBox(height: 20),
                  cards[4],
                ],
              ),
            const SizedBox(height: 32),

            // How to Install Timeline
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'How to Install',
                style: TextStyle(color: AppColors.accent, fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                children: [
                  _buildInstallStep('1', 'Download the app for your device.'),
                  const SizedBox(height: 16),
                  _buildInstallStep('2', 'Install the app package file and open it.'),
                  const SizedBox(height: 16),
                  _buildInstallStep('3', 'Sign in using your FLIXO account credentials.'),
                  const SizedBox(height: 16),
                  _buildInstallStep('4', 'Start streaming unlimited movie titles!'),
                ],
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildFeature(IconData icon, String title, String subtitle) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: AppColors.accent, size: 20),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(title, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
              Text(subtitle, style: const TextStyle(color: Colors.white38, fontSize: 9)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPlatformCard(
    BuildContext context, {
    required String platformName,
    required String description,
    required String buttonLabel,
    String? secondButtonLabel,
    required IconData iconData,
    required String imagePath,
    bool isGooglePlayStyle = false,
    bool isAppStoreStyle = false,
    bool isYellowButton = false,
    bool isDesktopRow = false,
    VoidCallback? onPressed,
    VoidCallback? onSecondPressed,
  }) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.card.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          AspectRatio(
            aspectRatio: 16 / 9,
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              child: Stack(
                children: [
                  Positioned.fill(
                    child: Container(
                      color: Colors.black,
                      child: Image.network(
                        imagePath,
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) => Container(
                          color: Colors.white10,
                          child: Icon(iconData, color: Colors.white24, size: 48),
                        ),
                      ),
                    ),
                  ),
                Positioned.fill(
                  child: Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.transparent, Colors.black87],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: 14,
                  left: 16,
                  child: Row(
                    children: [
                      Icon(iconData, color: AppColors.accent, size: 18),
                      const SizedBox(width: 8),
                      Text(platformName, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          ),
          // Content
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  description,
                  style: const TextStyle(color: Colors.white70, fontSize: 12, height: 1.4),
                ),
                const SizedBox(height: 16),
                if (isDesktopRow) ...[
                  ElevatedButton.icon(
                    onPressed: onPressed,
                    icon: const Icon(Icons.window_sharp, size: 18),
                    label: Text(buttonLabel),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(height: 10),
                  ElevatedButton.icon(
                    onPressed: onSecondPressed,
                    icon: const Icon(Icons.apple_rounded, size: 18),
                    label: Text(secondButtonLabel ?? 'macOS'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white12,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ),
                ] else if (isYellowButton) ...[
                  ElevatedButton(
                    onPressed: onPressed,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.accent,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                    child: Text(buttonLabel),
                  ),
                ] else if (isGooglePlayStyle) ...[
                  ElevatedButton.icon(
                    onPressed: onPressed,
                    icon: const Icon(Icons.play_arrow, color: Colors.white),
                    label: Text(buttonLabel),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black,
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: AppColors.border),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ),
                ] else if (isAppStoreStyle) ...[
                  ElevatedButton.icon(
                    onPressed: onPressed,
                    icon: const Icon(Icons.apple_rounded, color: Colors.white),
                    label: Text(buttonLabel),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black,
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: AppColors.border),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInstallStep(String index, String instruction) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          radius: 12,
          backgroundColor: AppColors.accent,
          child: Text(index, style: const TextStyle(color: Colors.black, fontSize: 11, fontWeight: FontWeight.bold)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            instruction,
            style: const TextStyle(color: Colors.white70, fontSize: 12, height: 1.4),
          ),
        ),
      ],
    );
  }
}
