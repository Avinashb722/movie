import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class Brand {
  static const ink = Color(0xFF0A0A0F);
  static const red = Color(0xFFE0201B);
  static const orange = Color(0xFFF5951F);
  static const surface = Color(0x14FFFFFF); // white @ ~8%
  static const stroke = Color(0x1FFFFFFF); // white @ ~12%
  static const muted = Color(0xFFB4B4BE);
}

class WebDownloadPopup extends StatelessWidget {
  const WebDownloadPopup({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 600),
      decoration: BoxDecoration(
        color: Brand.ink,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Brand.stroke, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.6),
            blurRadius: 40,
            spreadRadius: 5,
          ),
        ],
        image: const DecorationImage(
          image: AssetImage('assets/cinematic_bg.png'),
          fit: BoxFit.cover,
          alignment: Alignment.centerRight,
          opacity: 0.75,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Container(
          // First gradient overlay (left to right)
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [
                Brand.ink,
                Color(0xFA0A0A0F),
                Color(0x900A0A0F),
                Colors.transparent,
              ],
              stops: [0.0, 0.45, 0.70, 1.0],
            ),
          ),
          child: Container(
            // Second gradient overlay (bottom to top)
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [
                  Brand.ink,
                  Colors.transparent,
                ],
                stops: [0.0, 0.8],
              ),
            ),
            child: Stack(
              children: [
                // Content
                Padding(
                  padding: const EdgeInsets.all(32.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      _Logo(),
                      SizedBox(height: 16),
                      _Wordmark(),
                      SizedBox(height: 12),
                      _Tagline(),
                      SizedBox(height: 24),
                      _CategoryBar(),
                      SizedBox(height: 16),
                      _SubTagline(),
                      SizedBox(height: 28),
                      _DownloadHeading(),
                      SizedBox(height: 16),
                      _DownloadGrid(),
                    ],
                  ),
                ),
                // Close button positioned top-right
                Positioned(
                  top: 16,
                  right: 16,
                  child: IconButton(
                    icon: const Icon(Icons.close_rounded, color: Colors.white70, size: 28),
                    onPressed: () => Navigator.pop(context),
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

class _Logo extends StatelessWidget {
  const _Logo();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 76,
      height: 76,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Brand.red.withOpacity(0.35),
            blurRadius: 40,
            spreadRadius: -8,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Image.asset(
          'assets/logo.png',
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => Container(
            color: Brand.red,
            child: const Icon(Icons.play_circle_fill, color: Colors.white, size: 40),
          ),
        ),
      ),
    );
  }
}

class _Wordmark extends StatelessWidget {
  const _Wordmark();

  @override
  Widget build(BuildContext context) {
    return RichText(
      text: const TextSpan(
        style: TextStyle(
          fontSize: 38,
          fontWeight: FontWeight.w900,
          letterSpacing: -0.5,
          height: 1.0,
        ),
        children: [
          TextSpan(text: 'MOVIE', style: TextStyle(color: Colors.white)),
          TextSpan(text: 'NEST', style: TextStyle(color: Brand.red)),
        ],
      ),
    );
  }
}

class _Tagline extends StatelessWidget {
  const _Tagline();

  @override
  Widget build(BuildContext context) {
    return RichText(
      text: const TextSpan(
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w800,
          letterSpacing: 3,
        ),
        children: [
          TextSpan(text: 'STREAM. ', style: TextStyle(color: Colors.white)),
          TextSpan(text: 'DISCOVER. ', style: TextStyle(color: Brand.red)),
          TextSpan(text: 'ENJOY.', style: TextStyle(color: Brand.orange)),
        ],
      ),
    );
  }
}

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
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Brand.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Brand.stroke),
      ),
      child: Wrap(
        spacing: 16,
        runSpacing: 10,
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
          width: 26,
          height: 26,
          decoration: BoxDecoration(
            color: Brand.red,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(icon, size: 15, color: Colors.white),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}

class _SubTagline extends StatelessWidget {
  const _SubTagline();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: Brand.red, width: 2),
          ),
          child: const Icon(Icons.play_arrow, size: 14, color: Brand.red),
        ),
        const SizedBox(width: 8),
        const Flexible(
          child: Text(
            'UNLIMITED ENTERTAINMENT, ANYTIME, ANYWHERE.',
            style: TextStyle(
              color: Colors.white70,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
              fontSize: 11,
            ),
          ),
        ),
      ],
    );
  }
}

class _DownloadHeading extends StatelessWidget {
  const _DownloadHeading();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 32,
          height: 2,
          color: Brand.orange,
        ),
        const SizedBox(width: 10),
        const Text(
          'DOWNLOAD NOW',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w800,
            letterSpacing: 2,
            fontSize: 13,
          ),
        ),
        const SizedBox(width: 10),
        const Expanded(
          child: Divider(color: Brand.stroke, thickness: 1),
        ),
      ],
    );
  }
}

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
        final spacing = 8.0;
        final itemW = (constraints.maxWidth - spacing) / 2;
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

class _DownloadButton extends StatelessWidget {
  const _DownloadButton({required this.platform});

  final _Platform platform;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          hoverColor: Colors.white.withOpacity(0.06),
          splashColor: platform.color.withOpacity(0.12),
          onTap: () async {
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
            final uri = Uri.parse(platform.url);
            if (await canLaunchUrl(uri)) {
              await launchUrl(uri, mode: LaunchMode.externalApplication);
            }
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white.withOpacity(0.08),
                  Colors.white.withOpacity(0.03),
                ],
              ),
              border: Border.all(color: Colors.white.withOpacity(0.10)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: platform.color.withOpacity(0.12),
                  ),
                  child: Icon(platform.icon, color: platform.color, size: 18),
                ),
                const SizedBox(width: 8),
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
                          fontSize: 11,
                          letterSpacing: 0.5,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 1),
                      const Text(
                        'DOWNLOAD',
                        style: TextStyle(
                          color: Brand.muted,
                          fontWeight: FontWeight.w600,
                          fontSize: 8,
                          letterSpacing: 1.0,
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
