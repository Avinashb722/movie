import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../theme/app_theme.dart';
import '../services/watchlist_service.dart';
import '../services/history_service.dart';
import '../models/movie.dart';
import 'movie_detail_screen.dart';
import 'settings_screen.dart';
import 'login_screen.dart';

import 'package:firebase_auth/firebase_auth.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final isLoggedIn = user != null;

    final displayName = isLoggedIn ? (user.displayName ?? 'Flixo User') : 'Guest User';
    final email = isLoggedIn ? (user.email ?? 'Not Logged In') : 'Sign in to sync your watchlist & history';
    final photoUrl = isLoggedIn ? user.photoURL : null;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // ── User header ───────────────────────────────
            Row(children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: AppColors.accent,
                backgroundImage: photoUrl != null ? CachedNetworkImageProvider(photoUrl) : null,
                child: photoUrl == null
                    ? Text(
                        displayName.isNotEmpty ? displayName[0].toUpperCase() : 'G',
                        style: const TextStyle(color: Colors.black, fontSize: 22, fontWeight: FontWeight.bold),
                      )
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(displayName, style: const TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.w700)),
                Text(email, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                const SizedBox(height: 2),
                if (isLoggedIn)
                  const Row(children: [
                    Icon(Icons.workspace_premium, color: AppColors.accent, size: 12),
                    SizedBox(width: 4),
                    Text('Premium Member', style: TextStyle(color: AppColors.accent, fontSize: 11, fontWeight: FontWeight.w600)),
                  ])
                else
                  const Row(children: [
                    Icon(Icons.lock_open_outlined, color: AppColors.textSecondary, size: 12),
                    SizedBox(width: 4),
                    Text('Guest Mode', style: TextStyle(color: AppColors.textSecondary, fontSize: 11, fontWeight: FontWeight.w600)),
                  ]),
              ])),
              IconButton(icon: const Icon(Icons.settings_outlined, color: AppColors.textSecondary), onPressed: () {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen())).then((_) {
                  setState(() {});
                });
              }),
              if (!isLoggedIn) ...[
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const LoginScreen(isModalMode: true)),
                    ).then((value) {
                      if (value == true) {
                        setState(() {});
                      }
                    });
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                  child: const Text('Login'),
                ),
              ],
            ]),
            const SizedBox(height: 16),

            // ── Premium / Guest Banner ────────────────────────
            if (isLoggedIn)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFFB800), Color(0xFFCC8800)],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(children: [
                  const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Premium Plan', style: TextStyle(color: Colors.black, fontSize: 15, fontWeight: FontWeight.w800)),
                    SizedBox(height: 3),
                    Text('Valid till 25 May 2025', style: TextStyle(color: Colors.black87, fontSize: 12)),
                  ])),
                  ElevatedButton(
                    onPressed: () {},
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black,
                      foregroundColor: AppColors.accent,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                    child: const Text('Manage Plan'),
                  ),
                ]),
              )
            else
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(children: [
                  const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Sync Your Watchlist', style: TextStyle(color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.bold)),
                    SizedBox(height: 3),
                    Text('Create an account to backup your items across all devices.', style: TextStyle(color: AppColors.textSecondary, fontSize: 11)),
                  ])),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const LoginScreen(isModalMode: true)),
                      ).then((value) {
                        if (value == true) {
                          setState(() {});
                        }
                      });
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.surface,
                      foregroundColor: AppColors.textPrimary,
                      side: const BorderSide(color: AppColors.border),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                    child: const Text('Sign Up'),
                  ),
                ]),
              ),
            const SizedBox(height: 20),

            // ── Continue Watching ─────────────────────────
            _SectionHeader(title: 'Continue Watching', onViewAll: () {}),
            const SizedBox(height: 10),
            ValueListenableBuilder<List<Movie>>(
              valueListenable: HistoryService.instance.historyNotifier,
              builder: (context, historyList, _) {
                if (historyList.isEmpty) {
                  return Container(
                    height: 100,
                    width: double.infinity,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppColors.card,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Text(
                      'No recently viewed movies',
                      style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                    ),
                  );
                }
                return SizedBox(
                  height: 125,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    separatorBuilder: (_, __) => const SizedBox(width: 10),
                    itemCount: historyList.length,
                    itemBuilder: (_, i) {
                      final movie = historyList[i];
                      return GestureDetector(
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => MovieDetailScreen(movie: movie)),
                        ),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Container(
                            width: 130, height: 72,
                            decoration: BoxDecoration(
                              color: AppColors.card,
                              borderRadius: BorderRadius.circular(8),
                              image: movie.posterUrl.isNotEmpty
                                  ? DecorationImage(image: CachedNetworkImageProvider(movie.posterUrl), fit: BoxFit.cover)
                                  : null,
                            ),
                            child: Stack(children: [
                              if (movie.posterUrl.isNotEmpty)
                                Container(
                                  decoration: BoxDecoration(
                                    color: Colors.black45,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                              const Positioned.fill(child: Center(child: CircleAvatar(backgroundColor: Colors.black54, radius: 14, child: Icon(Icons.play_arrow, color: Colors.white, size: 16)))),
                              Positioned(
                                bottom: 0, left: 0, right: 0,
                                child: ClipRRect(
                                  borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(8), bottomRight: Radius.circular(8)),
                                  child: LinearProgressIndicator(
                                    value: 0.5,
                                    backgroundColor: AppColors.surface,
                                    valueColor: const AlwaysStoppedAnimation<Color>(AppColors.accent),
                                    minHeight: 3,
                                  ),
                                ),
                              ),
                            ]),
                          ),
                          const SizedBox(height: 4),
                          SizedBox(
                            width: 130,
                            child: Text(
                              movie.title, 
                              maxLines: 1, 
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: AppColors.textPrimary, fontSize: 10, fontWeight: FontWeight.w600)
                            ),
                          ),
                          const Text('Continue watching', style: TextStyle(color: AppColors.textSecondary, fontSize: 9)),
                        ]),
                      );
                    },
                  ),
                );
              },
            ),
            const SizedBox(height: 20),

            // ── My Watchlist ──────────────────────────────
            _SectionHeader(title: 'My Watchlist', onViewAll: () {}),
            const SizedBox(height: 10),
            SizedBox(
              height: 150,
              child: ValueListenableBuilder<List<Movie>>(
                valueListenable: WatchlistService.instance.watchlistNotifier,
                builder: (context, watchlist, _) {
                  if (watchlist.isEmpty) {
                    return Container(
                      width: double.infinity,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: AppColors.card,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Text(
                        'Your watchlist is empty',
                        style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                      ),
                    );
                  }

                  return ListView.separated(
                    scrollDirection: Axis.horizontal,
                    separatorBuilder: (_, __) => const SizedBox(width: 10),
                    itemCount: watchlist.length,
                    itemBuilder: (context, i) {
                      final movie = watchlist[i];
                      return GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => MovieDetailScreen(movie: movie),
                            ),
                          );
                        },
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            width: 100,
                            height: 150,
                            color: AppColors.card,
                            child: movie.posterUrl.isNotEmpty
                                ? CachedNetworkImage(
                                    imageUrl: movie.posterUrl,
                                    fit: BoxFit.cover,
                                    placeholder: (_, __) => const Center(
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: AppColors.accent,
                                      ),
                                    ),
                                    errorWidget: (_, __, ___) => const Icon(
                                      Icons.movie,
                                      color: AppColors.textMuted,
                                      size: 32,
                                    ),
                                  )
                                : const Icon(
                                    Icons.movie,
                                    color: AppColors.textMuted,
                                    size: 32,
                                  ),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
            const SizedBox(height: 20),
          ]),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final VoidCallback onViewAll;
  const _SectionHeader({required this.title, required this.onViewAll});
  @override
  Widget build(BuildContext context) {
    return Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Text(title, style: const TextStyle(color: AppColors.textPrimary, fontSize: 15, fontWeight: FontWeight.w700)),
      GestureDetector(onTap: onViewAll,
        child: const Text('View All', style: TextStyle(color: AppColors.accent, fontSize: 12, fontWeight: FontWeight.w600))),
    ]);
  }
}
