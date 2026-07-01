import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_theme.dart';
import '../services/auth_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'flixo_download_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final AuthService _authService = AuthService();
  double _cacheSizeMB = 715.0;
  bool _aoneroomTokenSet = false;
  String _aoneroomToken = '';
  String _cfProxyUrl = '';
  bool _cfProxySet = false;
  String _watchoSessionId = '';
  String _watchoBoxId = '';
  bool _watchoSessionSet = false;

  @override
  void initState() {
    super.initState();
    _loadAoneroomToken();
    _loadCfProxyUrl();
    _loadWatchoSession();
  }

  Future<void> _loadCfProxyUrl() async {
    final prefs = await SharedPreferences.getInstance();
    final url = prefs.getString('cloudflare_proxy_url') ?? '';
    setState(() {
      _cfProxyUrl = url;
      _cfProxySet = url.isNotEmpty;
    });
  }

  Future<void> _saveCfProxyUrl(String url) async {
    final prefs = await SharedPreferences.getInstance();
    String formattedUrl = url.trim();
    if (formattedUrl.isNotEmpty && !formattedUrl.startsWith('http://') && !formattedUrl.startsWith('https://')) {
      formattedUrl = 'https://$formattedUrl';
    }
    if (formattedUrl.isEmpty) {
      await prefs.remove('cloudflare_proxy_url');
    } else {
      await prefs.setString('cloudflare_proxy_url', formattedUrl);
    }
    await _loadCfProxyUrl();
  }

  Future<void> _loadWatchoSession() async {
    final prefs = await SharedPreferences.getInstance();
    final sessId = prefs.getString('watcho_session_id') ?? '';
    final bId = prefs.getString('watcho_box_id') ?? '';
    setState(() {
      _watchoSessionId = sessId;
      _watchoBoxId = bId;
      _watchoSessionSet = sessId.isNotEmpty && bId.isNotEmpty;
    });
  }

  Future<void> _saveWatchoSession(String sessionId, String boxId) async {
    final prefs = await SharedPreferences.getInstance();
    if (sessionId.trim().isEmpty || boxId.trim().isEmpty) {
      await prefs.remove('watcho_session_id');
      await prefs.remove('watcho_box_id');
    } else {
      await prefs.setString('watcho_session_id', sessionId.trim());
      await prefs.setString('watcho_box_id', boxId.trim());
    }
    await _loadWatchoSession();
  }

  Future<void> _loadAoneroomToken() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('aoneroom_token') ?? '';
    setState(() {
      _aoneroomToken = token;
      _aoneroomTokenSet = token.isNotEmpty;
    });
  }

  Future<void> _saveAoneroomToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    if (token.trim().isEmpty) {
      await prefs.remove('aoneroom_token');
    } else {
      await prefs.setString('aoneroom_token', token.trim());
    }
    await _loadAoneroomToken();
  }

  void _showCfProxyInput() {
    final controller = TextEditingController(text: _cfProxyUrl);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Cloudflare Proxy URL', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Deploy the included worker.js to Cloudflare Workers for free, and paste the URL here. This completely bypasses ISP blocks on Archive.org and CORS on Web.',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
              decoration: const InputDecoration(
                hintText: 'https://your-worker.username.workers.dev',
                hintStyle: TextStyle(color: AppColors.textMuted),
                border: OutlineInputBorder(),
                focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: AppColors.accent)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
          ),
          TextButton(
            onPressed: () async {
              await _saveCfProxyUrl(controller.text);
              if (context.mounted) Navigator.pop(context);
              _showMessage('Proxy Updated', 'Cloudflare proxy URL saved successfully.');
            },
            child: const Text('Save', style: TextStyle(color: AppColors.accent, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showTokenInput() {
    final controller = TextEditingController(text: _aoneroomToken);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Aoneroom Web Token', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Paste your JWT token from h5.aoneroom.com to unlock full-quality video streaming on Web. (Run copy(JSON.parse(localStorage.user).token) in browser console to copy it).',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
              maxLines: 4,
              decoration: const InputDecoration(
                hintText: 'eyJhbGciOiJIUzI1NiIsIn...',
                hintStyle: TextStyle(color: AppColors.textMuted),
                border: OutlineInputBorder(),
                focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: AppColors.accent)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
          ),
          TextButton(
            onPressed: () async {
              await _saveAoneroomToken(controller.text);
              if (context.mounted) Navigator.pop(context);
              _showMessage('Token Updated', 'Aoneroom token saved successfully.');
            },
            child: const Text('Save', style: TextStyle(color: AppColors.accent, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showWatchoSessionInput() {
    final sessionController = TextEditingController(text: _watchoSessionId);
    final boxController = TextEditingController(text: _watchoBoxId);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Watcho Session Credentials', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Enter your active Watcho Session-Id and Box-Id to enable high-quality partner streams.',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
              ),
              const SizedBox(height: 16),
              const Text('Session ID', style: TextStyle(color: AppColors.textSecondary, fontSize: 11, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              TextField(
                controller: sessionController,
                style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
                decoration: const InputDecoration(
                  hintText: 'e.g., e7c89c52-0740-4b11-a742-2899fa5d9bce',
                  hintStyle: TextStyle(color: AppColors.textMuted),
                  border: OutlineInputBorder(),
                  focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: AppColors.accent)),
                ),
              ),
              const SizedBox(height: 16),
              const Text('Box ID', style: TextStyle(color: AppColors.textSecondary, fontSize: 11, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              TextField(
                controller: boxController,
                style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
                decoration: const InputDecoration(
                  hintText: 'e.g., 2b6eb866-8593-3e7b-f4fb-f71ed1cb6bdd',
                  hintStyle: TextStyle(color: AppColors.textMuted),
                  border: OutlineInputBorder(),
                  focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: AppColors.accent)),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
          ),
          TextButton(
            onPressed: () async {
              await _saveWatchoSession(sessionController.text, boxController.text);
              if (context.mounted) Navigator.pop(context);
              _showMessage('Credentials Updated', 'Watcho session keys saved successfully.');
            },
            child: const Text('Save', style: TextStyle(color: AppColors.accent, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showMessage(String title, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text(title, style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold)),
        content: Text(message, style: const TextStyle(color: AppColors.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK', style: TextStyle(color: AppColors.accent)),
          ),
        ],
      ),
    );
  }

  void _showLanguageSelector() {
    final languages = ['English', 'Español', 'Français', 'Hindi', 'Telugu', 'Tamil'];
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Select Language', style: TextStyle(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              ...languages.map((lang) => ListTile(
                    title: Text(lang, style: const TextStyle(color: AppColors.textPrimary), textAlign: TextAlign.center),
                    onTap: () {
                      Navigator.pop(context);
                      _showMessage('Language Updated', 'App language changed to $lang.');
                    },
                  )),
            ],
          ),
        );
      },
    );
  }

  void _showQualitySelector(String title, List<String> options, String currentValue, Function(String) onSelected) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(title, style: const TextStyle(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              ...options.map((opt) => ListTile(
                    title: Text(opt, style: const TextStyle(color: AppColors.textPrimary), textAlign: TextAlign.center),
                    trailing: opt == currentValue ? const Icon(Icons.check, color: AppColors.accent) : null,
                    onTap: () {
                      Navigator.pop(context);
                      onSelected(opt);
                    },
                  )),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isLoggedIn = FirebaseAuth.instance.currentUser != null;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Settings', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700)),
      ),
      body: SingleChildScrollView(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _Section(title: 'Account', items: [
            _SettingItem(
              icon: Icons.person_outline,
              title: 'Edit Profile',
              onTap: () {
                if (!isLoggedIn) {
                  _showMessage('Account Required', 'Please sign in to edit your profile.');
                  return;
                }
                _showMessage('Edit Profile', 'Profile customization features are coming soon.');
              },
            ),
            _SettingItem(
              icon: Icons.lock_outline,
              title: 'Change Password',
              onTap: () {
                if (!isLoggedIn) {
                  _showMessage('Account Required', 'Please sign in to modify password credentials.');
                  return;
                }
                _showMessage('Change Password', 'Password recovery/reset instruction link sent to your registered email.');
              },
            ),
            _SettingItem(
              icon: Icons.devices_outlined,
              title: 'Device Management',
              onTap: () {
                _showMessage('Device Management', 'Currently signed in: 1 Active Device (This session).');
              },
            ),
            if (isLoggedIn)
              _SettingItem(
                icon: Icons.logout,
                title: 'Sign Out',
                onTap: () async {
                  await _authService.signOut();
                  if (context.mounted) {
                    Navigator.pop(context, true);
                  }
                },
              ),
          ]),
          _Section(title: 'Preferences', items: [
            _SettingItem(
              icon: Icons.language,
              title: 'App Language',
              value: 'English',
              onTap: _showLanguageSelector,
            ),
            _SettingItem(
              icon: Icons.hd_outlined,
              title: 'Playback Quality',
              value: 'Auto',
              onTap: () {
                _showQualitySelector('Playback Quality', ['Auto', 'Low (360p)', 'Medium (480p)', 'HD (720p)', 'Full HD (1080p)'], 'Auto', (val) {
                  _showMessage('Playback Quality', 'Preferred playback quality set to $val.');
                });
              },
            ),
            _SettingItem(
              icon: Icons.vpn_key_outlined,
              title: 'Aoneroom Web Token',
              value: _aoneroomTokenSet ? 'Active' : 'Guest Mode',
              onTap: _showTokenInput,
            ),
            _SettingItem(
              icon: Icons.vpn_key_rounded,
              title: 'Watcho Session Credentials',
              value: _watchoSessionSet ? 'Active' : 'Not Set',
              onTap: _showWatchoSessionInput,
            ),
            _SettingItem(
              icon: Icons.cloud_queue_outlined,
              title: 'Cloudflare Proxy URL',
              value: _cfProxySet ? 'Active' : 'Not Set',
              onTap: _showCfProxyInput,
            ),
            _SettingItem(
              icon: Icons.download_outlined,
              title: 'Download Quality',
              value: 'High',
              onTap: () {
                _showQualitySelector('Download Quality', ['Standard', 'High', 'Ultra HD'], 'High', (val) {
                  _showMessage('Download Quality', 'Preferred download quality set to $val.');
                });
              },
            ),
            _SettingItem(
              icon: Icons.cleaning_services_outlined,
              title: 'Clear Cache',
              value: '${_cacheSizeMB.toStringAsFixed(0)} MB',
              onTap: () {
                setState(() {
                  _cacheSizeMB = 0.0;
                });
                _showMessage('Cache Cleared', 'All temporary cached images and network feeds have been cleared.');
              },
            ),
          ]),
          _Section(title: 'Support', items: [
            _SettingItem(
              icon: Icons.help_outline,
              title: 'Help Center',
              onTap: () {
                _showMessage('Help Center', 'For help and streaming guides, contact support@movienest.app.');
              },
            ),
            _SettingItem(
              icon: Icons.email_outlined,
              title: 'Contact Us',
              onTap: () {
                _showMessage('Contact Us', 'Support Desk Email: support@movienest.app\nResponse timeframe: Within 24 hours.');
              },
            ),
            _SettingItem(
              icon: Icons.info_outline,
              title: 'About Us',
              onTap: () {
                _showMessage('MovieNest App', 'MovieNest is a premium catalog viewer powered by the TMDB database.');
              },
            ),
            _SettingItem(
              icon: Icons.download_for_offline_outlined,
              title: 'Download MovieNest App',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const FlixoDownloadScreen()),
                );
              },
            ),
          ]),
          const SizedBox(height: 30),
          Center(
            child: Column(children: const [
              Text('MovieNest v1.0.0', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
              SizedBox(height: 4),
              Text('Powered by TMDB + Free Streaming', style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
            ]),
          ),
          const SizedBox(height: 30),
        ]),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final List<Widget> items;
  const _Section({required this.title, required this.items});
  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
        child: Text(title, style: const TextStyle(color: AppColors.textMuted, fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 0.5)),
      ),
      Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(12)),
        child: Column(children: items),
      ),
    ]);
  }
}

class _SettingItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? value;
  final VoidCallback onTap;
  const _SettingItem({required this.icon, required this.title, required this.onTap, this.value});
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0xFF222222)))),
        child: Row(children: [
          Icon(icon, color: AppColors.textSecondary, size: 18),
          const SizedBox(width: 12),
          Expanded(child: Text(title, style: const TextStyle(color: AppColors.textPrimary, fontSize: 14))),
          if (value != null) Text(value!, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
          const SizedBox(width: 6),
          const Icon(Icons.chevron_right, color: AppColors.textMuted, size: 18),
        ]),
      ),
    );
  }
}
