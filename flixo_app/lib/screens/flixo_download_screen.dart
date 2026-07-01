import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme/app_theme.dart';

// ---------------------------------------------------------------------------
// Brand palette — EXACT copy from reference
// ---------------------------------------------------------------------------
class Brand {
  static const ink = Color(0xFF0A0A0F);
  static const red = Color(0xFFE0201B);
  static const orange = Color(0xFFF5951F);
  static const surface = Color(0x14FFFFFF); // white @ ~8%
  static const stroke = Color(0x1FFFFFFF); // white @ ~12%
  static const muted = Color(0xFFB4B4BE);
}

// ---------------------------------------------------------------------------
// FlixoDownloadScreen (Exact copy of HeroScreen)
// ---------------------------------------------------------------------------
class FlixoDownloadScreen extends StatelessWidget {
  const FlixoDownloadScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Brand.ink,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Cinematic backdrop
          const _CinematicBackground(),
          // Readability gradient — adapts to viewport width
          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth >= 900;
              return Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: const [
                      Brand.ink,
                      Color(0xE60A0A0F),
                      Color(0x990A0A0F),
                      Colors.transparent,
                    ],
                    stops: isWide
                        ? const [0.0, 0.35, 0.6, 1.0]
                        : const [0.0, 0.55, 0.85, 1.0],
                  ),
                ),
              );
            },
          ),
          // Extra bottom scrim so download buttons stay legible
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.center,
                colors: [Color(0xCC0A0A0F), Colors.transparent],
              ),
            ),
            child: SizedBox.expand(),
          ),
          // Content
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth >= 900;
                return SingleChildScrollView(
                  padding: EdgeInsets.symmetric(
                    horizontal: isWide ? 64 : 24,
                    vertical: 40,
                  ),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: isWide ? 600 : double.infinity,
                    ),
                    child: const _HeroContent(),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Background — EXACT copy from reference
// ---------------------------------------------------------------------------
class _CinematicBackground extends StatelessWidget {
  const _CinematicBackground();

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Brand.ink,
      child: Align(
        alignment: Alignment.centerRight,
        child: Image.asset(
          'assets/cinematic_bg.png',
          fit: BoxFit.cover,
          height: double.infinity,
          alignment: Alignment.centerRight,
          errorBuilder: (_, __, ___) => const SizedBox.shrink(),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Hero content column — EXACT copy + Installation guides appended
// ---------------------------------------------------------------------------
class _HeroContent extends StatelessWidget {
  const _HeroContent();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: const [
        _Logo(),
        SizedBox(height: 24),
        _Wordmark(),
        SizedBox(height: 16),
        _Tagline(),
        SizedBox(height: 28),
        _CategoryBar(),
        SizedBox(height: 20),
        _SubTagline(),
        SizedBox(height: 32),
        _DownloadHeading(),
        SizedBox(height: 16),
        _DownloadGrid(),
        SizedBox(height: 48),
        _InstallHeading(),
        SizedBox(height: 20),
        _InstallGuidesSection(),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Logo mark — EXACT copy from reference
// ---------------------------------------------------------------------------
class _Logo extends StatelessWidget {
  const _Logo();

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size.width >= 900 ? 96.0 : 76.0;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size * 0.24),
        boxShadow: [
          BoxShadow(
            color: Brand.red.withOpacity(0.35),
            blurRadius: 40,
            spreadRadius: -8,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(size * 0.24),
          child: Image.asset(
          'assets/logo.png',
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => Container(
            color: Brand.red,
            child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 40),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Wordmark — EXACT copy from reference
// ---------------------------------------------------------------------------
class _Wordmark extends StatelessWidget {
  const _Wordmark();

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size.width >= 900 ? 68.0 : 44.0;
    return RichText(
      text: TextSpan(
        style: TextStyle(
          fontSize: size,
          fontWeight: FontWeight.w900,
          letterSpacing: -1,
          height: 1.0,
        ),
        children: const [
          TextSpan(text: 'MOVIE', style: TextStyle(color: Colors.white, fontFamily: 'Roboto')),
          TextSpan(text: 'NEST', style: TextStyle(color: Brand.red, fontFamily: 'Roboto')),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Tagline — EXACT copy from reference
// ---------------------------------------------------------------------------
class _Tagline extends StatelessWidget {
  const _Tagline();

  @override
  Widget build(BuildContext context) {
    const style = TextStyle(
      fontSize: 20,
      fontWeight: FontWeight.w800,
      letterSpacing: 4,
    );
    return RichText(
      text: const TextSpan(
        style: style,
        children: [
          TextSpan(text: 'STREAM. ', style: TextStyle(color: Colors.white, fontFamily: 'Roboto')),
          TextSpan(text: 'DISCOVER. ', style: TextStyle(color: Brand.red, fontFamily: 'Roboto')),
          TextSpan(text: 'ENJOY.', style: TextStyle(color: Brand.orange, fontFamily: 'Roboto')),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Category bar — EXACT copy from reference
// ---------------------------------------------------------------------------
class _CategoryBar extends StatelessWidget {
  const _CategoryBar();

  static const _items = <(IconData, String)>[
    (Icons.play_circle_fill, 'MOVIES'),
    (Icons.tv, 'SHOWS'),
    (Icons.face, 'ANIME'),
    (Icons.movie_creation, 'SHORTS'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Brand.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Brand.stroke),
      ),
      child: Wrap(
        spacing: 20,
        runSpacing: 12,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          for (final (icon, label) in _items)
            _CategoryChip(icon: icon, label: label),
        ],
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: Brand.red,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 18, color: Colors.white),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            letterSpacing: 1,
            fontSize: 15,
            fontFamily: 'Roboto',
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Sub-tagline — EXACT copy from reference
// ---------------------------------------------------------------------------
class _SubTagline extends StatelessWidget {
  const _SubTagline();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: Brand.red, width: 2),
          ),
          child: const Icon(Icons.play_arrow, size: 16, color: Brand.red),
        ),
        const SizedBox(width: 10),
        const Flexible(
          child: Text(
            'UNLIMITED ENTERTAINMENT, ANYTIME, ANYWHERE.',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              letterSpacing: 1,
              fontSize: 14,
              fontFamily: 'Roboto',
            ),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Download heading — EXACT copy from reference
// ---------------------------------------------------------------------------
class _DownloadHeading extends StatelessWidget {
  const _DownloadHeading();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 40,
          height: 2,
          color: Brand.orange,
        ),
        const SizedBox(width: 12),
        const Text(
          'DOWNLOAD NOW',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w800,
            letterSpacing: 3,
            fontSize: 16,
            fontFamily: 'Roboto',
          ),
        ),
        const SizedBox(width: 12),
        const Expanded(
          child: Divider(color: Brand.stroke, thickness: 1),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Download grid — EXACT copy from reference + Correct live URLs
// ---------------------------------------------------------------------------
class _DownloadGrid extends StatelessWidget {
  const _DownloadGrid();

  static const _platforms = <_Platform>[
    _Platform(Icons.android, 'ANDROID', Color(0xFF3DDC84), 'https://www.movienest.app/downloads/movienest.apk'),
    _Platform(Icons.apple, 'IOS', Colors.white, ''),
    _Platform(Icons.window, 'WINDOWS', Color(0xFF3DA9FC), 'https://www.movienest.app/downloads/movienest-setup.exe'),
    _Platform(Icons.live_tv, 'ANDROID TV', Color(0xFF3DDC84), 'https://www.movienest.app/downloads/movienest-tv.apk'),
  ];

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 560;
        final cols = isWide ? 4 : 2;
        final spacing = 12.0;
        final itemW = (constraints.maxWidth - spacing * (cols - 1)) / cols;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            for (final p in _platforms)
              SizedBox(width: itemW, child: _DownloadButton(platform: p)),
          ],
        );
      },
    );
  }
}

class _Platform {
  const _Platform(this.icon, this.label, this.color, this.url);
  final IconData icon;
  final String label;
  final Color color;
  final String url;
}

// ---------------------------------------------------------------------------
// Download button — EXACT copy from reference + URL Launching action
// ---------------------------------------------------------------------------
class _DownloadButton extends StatelessWidget {
  const _DownloadButton({required this.platform});

  final _Platform platform;

  Future<void> _launchURL(BuildContext context) async {
    if (platform.url.isEmpty) {
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
      final uri = Uri.parse(platform.url);
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      debugPrint('Could not launch ${platform.url}: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.45),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          hoverColor: Colors.white.withOpacity(0.06),
          splashColor: platform.color.withOpacity(0.12),
          onTap: () => _launchURL(context),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white.withOpacity(0.10),
                  Colors.white.withOpacity(0.04),
                ],
              ),
              border: Border.all(color: Colors.white.withOpacity(0.14)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: platform.color.withOpacity(0.14),
                  ),
                  child: Icon(platform.icon, color: platform.color, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        platform.label,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                          letterSpacing: 0.5,
                          fontFamily: 'Roboto',
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        'DOWNLOAD',
                        style: TextStyle(
                          color: Brand.muted,
                          fontWeight: FontWeight.w600,
                          fontSize: 10,
                          letterSpacing: 1.5,
                          fontFamily: 'Roboto',
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
    );
  }
}

// ---------------------------------------------------------------------------
// Installation instructions section
// ---------------------------------------------------------------------------
class _InstallHeading extends StatelessWidget {
  const _InstallHeading();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 40,
          height: 2,
          color: Brand.orange,
        ),
        const SizedBox(width: 12),
        const Text(
          'INSTALLATION GUIDE',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w800,
            letterSpacing: 2,
            fontSize: 14,
            fontFamily: 'Roboto',
          ),
        ),
        const SizedBox(width: 12),
        const Expanded(
          child: Divider(color: Brand.stroke, thickness: 1),
        ),
      ],
    );
  }
}

class _InstallGuidesSection extends StatelessWidget {
  const _InstallGuidesSection();

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isWide = width >= 900;

    if (isWide) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          Expanded(
            child: _InstallGuide(
              title: 'Windows Setup Guide',
              icon: Icons.window,
              color: Color(0xFF3DA9FC),
              steps: [
                'Click the WINDOWS button above to download "movienest-setup.exe".',
                'Double-click the installer to launch setup.',
                'If Windows Defender displays a prompt, click "More Info" and then choose "Run Anyway".',
                'The setup completes in seconds and places a launcher icon on your desktop.',
              ],
            ),
          ),
          SizedBox(width: 24),
          Expanded(
            child: _InstallGuide(
              title: 'Android & TV Setup Guide',
              icon: Icons.android,
              color: Color(0xFF3DDC84),
              steps: [
                'Click the ANDROID button to download the "movienest.apk" file.',
                'Open the downloaded file from your browser or File Manager app.',
                'Enable "Install from Unknown Sources" inside your system settings if prompted.',
                'For TVs: copy "movienest-tv.apk" to a USB flash drive and open it using a TV file explorer app.',
              ],
            ),
          ),
        ],
      );
    }

    return Column(
      children: const [
        _InstallGuide(
          title: 'Windows Setup Guide',
          icon: Icons.window,
          color: Color(0xFF3DA9FC),
          steps: [
            'Click the WINDOWS button above to download "movienest-setup.exe".',
            'Double-click the installer to launch setup.',
            'If Windows Defender displays a warning, click "More Info" and then choose "Run Anyway".',
            'The setup completes in seconds and places a launcher icon on your desktop.',
          ],
        ),
        SizedBox(height: 16),
        _InstallGuide(
          title: 'Android & TV Setup Guide',
          icon: Icons.android,
          color: Color(0xFF3DDC84),
          steps: [
            'Click the ANDROID button to download the "movienest.apk" file.',
            'Open the downloaded file from your browser or File Manager app.',
            'Enable "Install from Unknown Sources" inside your system settings if prompted.',
            'For TVs: copy "movienest-tv.apk" to a USB flash drive and open it using a TV file explorer app.',
          ],
        ),
      ],
    );
  }
}

class _InstallGuide extends StatelessWidget {
  const _InstallGuide({
    required this.title,
    required this.icon,
    required this.color,
    required this.steps,
  });

  final String title;
  final IconData icon;
  final Color color;
  final List<String> steps;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Brand.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Brand.stroke),
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
                    fontFamily: 'Roboto',
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
                          fontFamily: 'Roboto',
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      steps[index],
                      style: const TextStyle(
                        color: Brand.muted,
                        fontSize: 12,
                        height: 1.4,
                        fontFamily: 'Roboto',
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
