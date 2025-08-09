import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// If you aren't using SimplyRETS here anymore, you can delete this import.
// import 'data/simplyrets_api.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Future<_ProfileData> _loadProfile() async {
    final auth = FirebaseAuth.instance;
    await auth.currentUser?.reload();
    final user = auth.currentUser;
    if (user == null) {
      return const _ProfileData(firstName: 'Friend'); // not signed in
    }

    String firstName = 'Friend';
    String? avatarUrl;

    try {
      final snap =
          await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      final data = snap.data();
      if (data != null) {
        final rawFirst = (data['firstName'] as String?)?.trim();
        if (rawFirst != null && rawFirst.isNotEmpty) {
          firstName = rawFirst;
        }
        final rawAvatar = data['avatarUrl'];
        if (rawAvatar is String && rawAvatar.trim().isNotEmpty) {
          avatarUrl = rawAvatar.trim();
        }
      }
    } catch (_) {
      // swallow read errors and fall back
    }

    return _ProfileData(firstName: firstName, avatarUrl: avatarUrl);
  }

  Future<void> _openProfile(BuildContext context) async {
    await Navigator.pushNamed(context, '/profile');
    if (mounted) setState(() {}); // refresh on return
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) {},
      child: Scaffold(
        body: FutureBuilder<_ProfileData>(
          future: _loadProfile(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return const Center(child: Text('Something went wrong.'));
            }

            final p = snapshot.data ?? const _ProfileData(firstName: 'Friend');

            return Stack(
              children: [
                // Background image
                Positioned.fill(
                  child: Image.asset(
                    'assets/images/home_screen.png', // ensure this path matches pubspec.yaml
                    fit: BoxFit.cover,
                  ),
                ),

                // Dim overlay
                Positioned.fill(
                  child: Container(color: Colors.black.withOpacity(0.40)),
                ),

                // Main content
                Positioned.fill(
                  child: SafeArea(
                    child: Center(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Clickable avatar -> ProfileScreen
                            InkWell(
                              borderRadius: BorderRadius.circular(999),
                              onTap: () => _openProfile(context),
                              child: CircleAvatar(
                                radius: 40,
                                backgroundColor: Colors.white,
                                backgroundImage: (p.avatarUrl != null && p.avatarUrl!.isNotEmpty)
                                    ? NetworkImage(p.avatarUrl!)
                                    : null,
                                child: (p.avatarUrl == null || p.avatarUrl!.isEmpty)
                                    ? const Icon(Icons.person, size: 40, color: Colors.grey)
                                    : null,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Welcome, ${p.firstName}!',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 32),

                            // Buttons
                            _buildButton(context, '/search', 'Search Listings'),
                            _buildButton(context, '/favorites', 'View Favorites'),
                            _buildButton(context, '/visited', 'Visited Properties'),
                            _buildButton(context, '/welcome', 'Log Out', isLogout: true),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildButton(
    BuildContext context,
    String route,
    String label, {
    bool isLogout = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: ElevatedButton(
        onPressed: () async {
          if (isLogout) {
            await FirebaseAuth.instance.signOut();
            if (context.mounted) {
              Navigator.pushReplacementNamed(context, route);
            }
          } else {
            Navigator.pushNamed(context, route);
          }
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: Colors.deepPurple,
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
          elevation: 6,
        ),
        child: Text(label),
      ),
    );
  }
}

class _ProfileData {
  final String firstName;
  final String? avatarUrl;
  const _ProfileData({required this.firstName, this.avatarUrl});
}
