import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class BlogScreen extends StatefulWidget {
  const BlogScreen({super.key});

  @override
  State<BlogScreen> createState() => _BlogScreenState();
}

class BlogPost {
  final String title;
  final String category;
  final String date;
  final String readTime;
  final String author;
  final String authorAvatar;
  final String summary;
  final String content;
  final String imageUrl;

  const BlogPost({
    required this.title,
    required this.category,
    required this.date,
    required this.readTime,
    required this.author,
    required this.authorAvatar,
    required this.summary,
    required this.content,
    required this.imageUrl,
  });
}

const List<BlogPost> _dummyPosts = [
  BlogPost(
    title: 'Flixo Original Releases this Summer: What to Watch',
    category: 'Originals',
    date: 'June 28, 2026',
    readTime: '5 min read',
    author: 'Elena Rostova',
    authorAvatar: 'https://images.unsplash.com/photo-1494790108377-be9c29b29330?w=80',
    summary: 'An exclusive sneak peek into the upcoming original lineup of movies and series launching on Flixo this summer.',
    imageUrl: 'https://images.unsplash.com/photo-1536440136628-849c177e76a1?w=800',
    content: 'Summer 2026 is shaping up to be the biggest season yet for Flixo Originals. Our development team has been hard at work producing a diverse slate of features, from blockbuster space adventures to intimate character dramas.\n\nFirst on the roster is "The Sheep Detectives", a whimsical detective mystery set in the rolling hills of New Zealand. Follow George Hardy as he solves crimes with his unusually smart flock. Next, look out for "Obsession", a high-concept psychological thriller that will keep you guessing until the final frame.\n\nWe are also expanding our anime library with two new exclusive series in partnership with leading Tokyo animation houses. Keep your eyes on the release calendar for drops starting this July!',
  ),
  BlogPost(
    title: 'The Rise of Anime Streaming on Flixo',
    category: 'Anime',
    date: 'June 25, 2026',
    readTime: '4 min read',
    author: 'Kenji Takahashi',
    authorAvatar: 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=80',
    summary: 'Exploring how Japanese animation has taken over the global charts and the top anime series you cannot miss.',
    imageUrl: 'https://images.unsplash.com/photo-1578632767115-351597cf2477?w=800',
    content: 'Anime has evolved from a niche subculture to a massive global force, dominating streaming charts worldwide. At Flixo, anime viewership has grown by over 140% in the last year alone.\n\nWhy this sudden surge? The combination of high-quality storytelling, unique art styles, and relatable character arcs transcends language barriers. To meet this demand, Flixo is launching a dedicated Anime Hub this month, bringing together classic series like Naruto and Attack on Titan with brand new seasonal simulcasts.\n\nOur highlights include "Sky Force" and "Supergirl: Legacy", both featuring localized subtitles and high-definition streams.',
  ),
  BlogPost(
    title: 'Top 10 Sci-Fi Masterpieces of the Decade',
    category: 'Reviews',
    date: 'June 20, 2026',
    readTime: '7 min read',
    author: 'Marcus Vance',
    authorAvatar: 'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?w=80',
    summary: 'From mind-bending space odysseys to dystopian futures, we count down the absolute best sci-fi movies of recent years.',
    imageUrl: 'https://images.unsplash.com/photo-1451187580459-43490279c0fa?w=800',
    content: 'Science fiction has always been the ultimate lens to examine humanity\'s future. In the past ten years, we have seen an incredible renaissance in sci-fi cinema, balancing high-budget visuals with deep philosophical questions.\n\nOur top pick of the decade is "Interstellar: Reborn", which captured the imagination of millions with its realistic physics and emotional father-daughter core. Other notable entries include "Dune: Part Three" and "Dystopia 2049", which pushed the boundaries of world-building and sound design.\n\nAll ten titles are now available to stream in 4K UHD with Dolby Vision on Flixo!',
  ),
  BlogPost(
    title: 'Cloudflare Proxy Setup: How to Optimize Your Stream',
    category: 'Tech & Guides',
    date: 'June 18, 2026',
    readTime: '3 min read',
    author: 'David Miller',
    authorAvatar: 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=80',
    summary: 'A step-by-step guide to setting up your Cloudflare Workers proxy for unlimited, fast, and block-free movie streaming.',
    imageUrl: 'https://images.unsplash.com/photo-1544197150-b99a580bb7a8?w=800',
    content: 'Experiencing buffering or connection blocks from your local ISP while streaming? A custom Cloudflare proxy is the perfect solution. By routing requests through Cloudflare\'s high-speed global edge servers, you can bypass local network limitations and protect your connection.\n\n1. Sign up for a free Cloudflare account.\n2. Navigate to Workers & Pages and click "Create application".\n3. Copy the "worker.js" script code provided in our Settings page.\n4. Deploy the worker and copy the custom URL.\n5. Paste the URL into Flixo Web Settings to enjoy seamless streaming!',
  ),
];

class _BlogScreenState extends State<BlogScreen> {
  String _selectedCategory = 'All';
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  final List<String> _categories = ['All', 'Originals', 'Anime', 'Reviews', 'Tech & Guides'];

  List<BlogPost> get _filteredPosts {
    return _dummyPosts.where((post) {
      final matchesCategory = _selectedCategory == 'All' || post.category == _selectedCategory;
      final matchesSearch = post.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          post.summary.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          post.content.toLowerCase().contains(_searchQuery.toLowerCase());
      return matchesCategory && matchesSearch;
    }).toList();
  }

  void _showPostDetails(BlogPost post) {
    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          backgroundColor: AppColors.background,
          insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: AppColors.border)),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Header actions
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.accent.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: AppColors.accent.withOpacity(0.4)),
                        ),
                        child: Text(post.category, style: const TextStyle(color: AppColors.accent, fontSize: 11, fontWeight: FontWeight.bold)),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(post.title, style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            CircleAvatar(
                              backgroundImage: NetworkImage(post.authorAvatar),
                              radius: 18,
                            ),
                            const SizedBox(width: 12),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(post.author, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
                                Text('${post.date} • ${post.readTime}', style: const TextStyle(color: AppColors.textSecondary, fontSize: 11)),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.network(
                            post.imageUrl,
                            width: double.infinity,
                            height: 320,
                            fit: BoxFit.cover,
                          ),
                        ),
                        const SizedBox(height: 24),
                        Text(
                          post.content,
                          style: const TextStyle(color: Colors.white, fontSize: 15, height: 1.8),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredPosts;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Title
            const Text(
              'Flixo Editorial Blog',
              style: TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            const Text(
              'Stay up to date with the latest releases, technical guides, reviews, and insights.',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
            ),
            const SizedBox(height: 24),

            // Filters & Search Row
            Row(
              children: [
                // Category Pills
                Expanded(
                  child: SizedBox(
                    height: 38,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: _categories.length,
                      itemBuilder: (context, i) {
                        final selected = _categories[i] == _selectedCategory;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8.0),
                          child: ChoiceChip(
                            label: Text(_categories[i]),
                            selected: selected,
                            onSelected: (val) {
                              if (val) setState(() => _selectedCategory = _categories[i]);
                            },
                            selectedColor: AppColors.accent,
                            backgroundColor: AppColors.card,
                            labelStyle: TextStyle(
                              color: selected ? Colors.black : Colors.white,
                              fontSize: 13,
                              fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                            ),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                // Search Input
                Container(
                  width: 260,
                  height: 38,
                  decoration: BoxDecoration(
                    color: AppColors.card,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: TextField(
                    controller: _searchController,
                    onChanged: (val) => setState(() => _searchQuery = val),
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                    decoration: const InputDecoration(
                      hintText: 'Search articles...',
                      hintStyle: TextStyle(color: AppColors.textMuted),
                      prefixIcon: Icon(Icons.search, color: AppColors.textMuted, size: 16),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(vertical: 10),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 28),

            // Grid of Blog Posts
            if (filtered.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 60),
                child: Center(
                  child: Column(
                    children: [
                      Icon(Icons.article_outlined, size: 48, color: AppColors.textMuted.withOpacity(0.5)),
                      const SizedBox(height: 16),
                      const Text('No articles found matching your criteria.', style: TextStyle(color: AppColors.textSecondary, fontSize: 14)),
                    ],
                  ),
                ),
              )
            else
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: MediaQuery.of(context).size.width > 1100 ? 3 : (MediaQuery.of(context).size.width > 700 ? 2 : 1),
                  crossAxisSpacing: 24,
                  mainAxisSpacing: 24,
                  childAspectRatio: 0.82,
                ),
                itemCount: filtered.length,
                itemBuilder: (context, i) {
                  final post = filtered[i];
                  return MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: GestureDetector(
                      onTap: () => _showPostDetails(post),
                      child: Container(
                        decoration: BoxDecoration(
                          color: AppColors.card,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.border),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            AspectRatio(
                              aspectRatio: 1.6,
                              child: Image.network(
                                post.imageUrl,
                                fit: BoxFit.cover,
                              ),
                            ),
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Text(
                                          post.category.toUpperCase(),
                                          style: const TextStyle(color: AppColors.accent, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                                        ),
                                        const Spacer(),
                                        Text(
                                          post.readTime,
                                          style: const TextStyle(color: AppColors.textSecondary, fontSize: 10),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 10),
                                    Text(
                                      post.title,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold, height: 1.3),
                                    ),
                                    const SizedBox(height: 8),
                                    Expanded(
                                      child: Text(
                                        post.summary,
                                        maxLines: 3,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(color: AppColors.textSecondary, fontSize: 12, height: 1.4),
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    Row(
                                      children: [
                                        CircleAvatar(
                                          backgroundImage: NetworkImage(post.authorAvatar),
                                          radius: 12,
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          post.author,
                                          style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
                                        ),
                                        const Spacer(),
                                        Text(
                                          post.date,
                                          style: const TextStyle(color: AppColors.textMuted, fontSize: 10),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}
