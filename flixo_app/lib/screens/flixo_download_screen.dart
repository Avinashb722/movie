import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme/app_theme.dart';

class FlixoDownloadScreen extends StatelessWidget {
  const FlixoDownloadScreen({super.key});

  static const String androidUrl = 'https://www.movienest.app/downloads/movienest.apk';
  static const String windowsUrl = 'https://www.movienest.app/downloads/movienest-setup.exe';
  static const String tvUrl = 'https://www.movienest.app/downloads/movienest-tv.apk';

  Future<void> _launchURL(BuildContext context, String urlString) async {
    if (urlString.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('iOS app is coming soon! Use our Web App for now.', style: TextStyle(color: Colors.white)),
          backgroundColor: Color(0xFF161616),
          duration: Duration(seconds: 3),
        ),
      );
      return;
    }
    try {
      final uri = Uri.parse(urlString);
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      debugPrint('Could not launch $urlString: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isDesktop = size.width > 768;

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0F),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Custom Header Banner matching popup background style
            Container(
              width: double.infinity,
              padding: EdgeInsets.symmetric(horizontal: 24, vertical: isDesktop ? 60 : 36),
              decoration: BoxDecoration(
                color: const Color(0xFF0E0E15),
                border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.08))),
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1000),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.accent.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: AppColors.accent.withOpacity(0.3)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: const [
                            Icon(Icons.workspace_premium_rounded, color: AppColors.accent, size: 14),
                            SizedBox(width: 6),
                            Text(
                              'OFFICIAL APPS',
                              style: TextStyle(color: AppColors.accent, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text(
                            'Download ',
                            style: TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w900, letterSpacing: -0.5),
                          ),
                          Text(
                            'MovieNest',
                            style: TextStyle(
                              color: AppColors.accent,
                              fontSize: 32,
                              fontWeight: FontWeight.w900,
                              shadows: [
                                Shadow(
                                  color: AppColors.accent.withOpacity(0.3),
                                  blurRadius: 15,
                                )
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Experience clean, ad-free streaming on your phone, TV, or PC. Choose your platform below to get started.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white60, fontSize: 14, height: 1.5),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            
            // Main content block
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 36),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1000),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Grid of download buttons
                      isDesktop
                          ? Row(
                              children: [
                                Expanded(child: _buildDownloadCard(context, Icons.android, 'ANDROID MOBILE', 'Download APK', Color(0xFF3DDC84), androidUrl)),
                                const SizedBox(width: 16),
                                Expanded(child: _buildDownloadCard(context, Icons.apple, 'APPLE IOS', 'Coming Soon', Colors.white, '')),
                                const SizedBox(width: 16),
                                Expanded(child: _buildDownloadCard(context, Icons.window, 'WINDOWS PC', 'Download EXE', Color(0xFF3DA9FC), windowsUrl)),
                                const SizedBox(width: 16),
                                Expanded(child: _buildDownloadCard(context, Icons.live_tv, 'ANDROID TV', 'Download APK', Color(0xFF3DDC84), tvUrl)),
                              ],
                            )
                          : Column(
                              children: [
                                _buildDownloadCard(context, Icons.android, 'ANDROID MOBILE', 'Download APK', Color(0xFF3DDC84), androidUrl),
                                const SizedBox(height: 12),
                                _buildDownloadCard(context, Icons.apple, 'APPLE IOS', 'Coming Soon', Colors.white, ''),
                                const SizedBox(height: 12),
                                _buildDownloadCard(context, Icons.window, 'WINDOWS PC', 'Download EXE', Color(0xFF3DA9FC), windowsUrl),
                                const SizedBox(height: 12),
                                _buildDownloadCard(context, Icons.live_tv, 'ANDROID TV', 'Download APK', Color(0xFF3DDC84), tvUrl),
                              ],
                            ),
                      
                      const SizedBox(height: 48),
                      
                      // Title: How to install
                      const Text(
                        'HOW TO INSTALL & SET UP',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        width: 80,
                        height: 3,
                        decoration: BoxDecoration(
                          color: AppColors.accent,
                          borderRadius: BorderRadius.circular(1.5),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Platform Step-by-Step guides
                      if (isDesktop)
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: _buildInstallGuide(
                                'Windows Installation Guide',
                                Icons.window,
                                Color(0xFF3DA9FC),
                                [
                                  'Click the "Download EXE" button under the Windows PC section.',
                                  'Open the downloaded installer "movienest-setup.exe".',
                                  'If Windows Defender displays a warning (due to new package build signature), click "More Info" and then choose "Run Anyway".',
                                  'Complete setup. The app will launch with a shortcut icon on your desktop.',
                                ],
                              ),
                            ),
                            const SizedBox(width: 24),
                            Expanded(
                              child: _buildInstallGuide(
                                'Android / TV Installation Guide',
                                Icons.android,
                                Color(0xFF3DDC84),
                                [
                                  'Click download to fetch the setup APK on your device.',
                                  'Open the downloaded file from your Notifications or File Manager app.',
                                  'If prompted, toggle "Allow Installation from Unknown Sources" inside your system settings.',
                                  'For Smart TVs: transfer the APK to a USB drive or use the "Send Files to TV" app to install it wirelessly.',
                                ],
                              ),
                            ),
                          ],
                        )
                      else
                        Column(
                          children: [
                            _buildInstallGuide(
                              'Windows Installation Guide',
                              Icons.window,
                              Color(0xFF3DA9FC),
                              [
                                'Click the "Download EXE" button under the Windows PC section.',
                                'Open the downloaded installer "movienest-setup.exe".',
                                'If Windows Defender displays a warning (due to new package build signature), click "More Info" and then choose "Run Anyway".',
                                'Complete setup. The app will launch with a shortcut icon on your desktop.',
                              ],
                            ),
                            const SizedBox(height: 20),
                            _buildInstallGuide(
                              'Android / TV Installation Guide',
                              Icons.android,
                              Color(0xFF3DDC84),
                              [
                                'Click download to fetch the setup APK on your device.',
                                'Open the downloaded file from your Notifications or File Manager app.',
                                'If prompted, toggle "Allow Installation from Unknown Sources" inside your system settings.',
                                'For Smart TVs: transfer the APK to a USB drive or use the "Send Files to TV" app to install it wirelessly.',
                              ],
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDownloadCard(BuildContext context, IconData icon, String label, String actionText, Color color, String url) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF111118),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.06), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          hoverColor: Colors.white.withOpacity(0.03),
          splashColor: color.withOpacity(0.12),
          onTap: () => _launchURL(context, url),
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: color.withOpacity(0.1),
                  ),
                  child: Icon(icon, color: color, size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        label,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 12,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        actionText,
                        style: TextStyle(
                          color: url.isEmpty ? Colors.white38 : AppColors.accent,
                          fontWeight: FontWeight.w700,
                          fontSize: 10,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  url.isEmpty ? Icons.lock_clock_outlined : Icons.arrow_forward_ios_rounded,
                  color: Colors.white24,
                  size: 14,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInstallGuide(String title, IconData icon, Color color, List<String> steps) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF111118),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.04)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          ...List.generate(steps.length, (index) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 16.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    margin: const EdgeInsets.only(top: 2),
                    width: 18,
                    height: 18,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: color.withOpacity(0.12),
                    ),
                    child: Center(
                      child: Text(
                        '${index + 1}',
                        style: TextStyle(
                          color: color,
                          fontWeight: FontWeight.w800,
                          fontSize: 10,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      steps[index],
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}
