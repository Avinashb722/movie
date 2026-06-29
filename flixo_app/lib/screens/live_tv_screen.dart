import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class LiveTvScreen extends StatefulWidget {
  const LiveTvScreen({super.key});
  @override State<LiveTvScreen> createState() => _LiveTvScreenState();
}

class _LiveTvScreenState extends State<LiveTvScreen> {
  String _filter = 'All';
  final _filters = ['All', 'Sports', 'News', 'Movies', 'Kids', 'Music'];

  final _channels = [
    {'name': 'Star Sports 1 HD', 'show': 'IND vs AUS • 2nd ODI', 'color': 0xFF003399},
    {'name': 'Sony Ten 1 HD',    'show': 'UEFA Champions League', 'color': 0xFF000080},
    {'name': 'Aaj Tak',          'show': 'Top Headlines',          'color': 0xFFCC0000},
    {'name': 'Zee News',         'show': 'Live: Breaking News',    'color': 0xFF006633},
    {'name': 'National Geographic HD', 'show': 'Into The Wild',   'color': 0xFF996600},
    {'name': 'MTV',              'show': 'Top 10 Music Videos',    'color': 0xFF660099},
    {'name': 'Star Movies',      'show': 'The Dark Knight',        'color': 0xFF990000},
    {'name': 'HBO HD',           'show': 'Game of Thrones',        'color': 0xFF330066},
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: CustomScrollView(slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  const Text('Live TV', style: TextStyle(color: AppColors.textPrimary, fontSize: 22, fontWeight: FontWeight.w800)),
                  const Spacer(),
                  const Icon(Icons.cast, color: AppColors.textSecondary, size: 22),
                ]),
                const SizedBox(height: 12),
                // Sports hero card
                Container(
                  height: 160,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    gradient: const LinearGradient(
                      colors: [Color(0xFF003399), Color(0xFF001166)],
                    ),
                  ),
                  child: Stack(children: [
                    Positioned(
                      top: 10, left: 12,
                      child: Row(children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(color: AppColors.live, borderRadius: BorderRadius.circular(4)),
                          child: const Text('LIVE', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                        ),
                        const SizedBox(width: 8),
                        const Text('🔴 12.5K', style: TextStyle(color: Colors.white70, fontSize: 11)),
                      ]),
                    ),
                    const Center(child: Icon(Icons.sports_cricket, color: Colors.white30, size: 80)),
                    Positioned(
                      bottom: 12, left: 12,
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: const [
                        Text('IND vs AUS', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                        Text('2nd ODI • Star Sports 1 HD', style: TextStyle(color: Colors.white70, fontSize: 11)),
                      ]),
                    ),
                    Positioned(
                      bottom: 8, right: 12,
                      child: Row(children: [
                        IconButton(onPressed: (){}, icon: const Icon(Icons.pause_circle, color: Colors.white, size: 32)),
                        IconButton(onPressed: (){}, icon: const Icon(Icons.fullscreen, color: Colors.white70, size: 22)),
                      ]),
                    ),
                  ]),
                ),
                const SizedBox(height: 14),
                // Search
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(24)),
                  child: const TextField(
                    decoration: InputDecoration(
                      hintText: 'Search channels...',
                      hintStyle: TextStyle(color: AppColors.textMuted, fontSize: 12),
                      border: InputBorder.none,
                      icon: Icon(Icons.search, color: AppColors.textMuted, size: 18),
                      contentPadding: EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                // Filter tabs
                SizedBox(
                  height: 34,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemCount: _filters.length,
                    itemBuilder: (_, i) {
                      final sel = _filters[i] == _filter;
                      return GestureDetector(
                        onTap: () => setState(() => _filter = _filters[i]),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                          decoration: BoxDecoration(
                            color: sel ? AppColors.accent : AppColors.card,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Text(_filters[i],
                            style: TextStyle(color: sel ? Colors.black : AppColors.textSecondary,
                              fontSize: 12, fontWeight: sel ? FontWeight.w700 : FontWeight.normal)),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: const [
                    Text('Live Channels', style: TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.w700)),
                    Text('View All', style: TextStyle(color: AppColors.accent, fontSize: 13)),
                  ],
                ),
                const SizedBox(height: 10),
              ]),
            ),
          ),
          // Channel list
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (_, i) => _ChannelTile(channel: _channels[i]),
              childCount: _channels.length,
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 20)),
        ]),
      ),
    );
  }
}

class _ChannelTile extends StatelessWidget {
  final Map<String, dynamic> channel;
  const _ChannelTile({required this.channel});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(10)),
      child: Row(children: [
        CircleAvatar(
          backgroundColor: Color(channel['color'] as int),
          radius: 22,
          child: Text(
            (channel['name'] as String).substring(0, 1),
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(channel['name'] as String,
            style: const TextStyle(color: AppColors.textPrimary, fontSize: 13, fontWeight: FontWeight.w600)),
          Text(channel['show'] as String,
            style: const TextStyle(color: AppColors.textSecondary, fontSize: 11)),
        ])),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
          decoration: BoxDecoration(color: AppColors.live, borderRadius: BorderRadius.circular(4)),
          child: const Text('LIVE', style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
        ),
      ]),
    );
  }
}
