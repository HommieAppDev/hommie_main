import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  Future<User?> _getUser() async {
    final user = FirebaseAuth.instance.currentUser;
    await user?.reload();
    return FirebaseAuth.instance.currentUser;
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async => false,
      child: Scaffold(
        body: FutureBuilder<User?>(
          future: _getUser(),
          builder: (context, snapshot) {
            final user = snapshot.data;
            final userName = user?.displayName ?? 'Friend';
            final photoUrl = user?.photoURL;

            return Stack(
              children: [
                // 🔹 Background image
                Positioned.fill(
                  child: Image.asset(
                    'assets/images/home_screen.png',
                    fit: BoxFit.cover,
                  ),
                ),

                // 🔹 Semi-transparent overlay
                Positioned.fill(
                  child: Container(
                    color: Colors.black.withOpacity(0.4),
                  ),
                ),

                // 🔹 Main content centered
                Positioned.fill(
                  child: SafeArea(
                    child: Center(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircleAvatar(
                              radius: 40,
                              backgroundColor: Colors.white,
                              backgroundImage: photoUrl != null
                                  ? NetworkImage(photoUrl)
                                  : null,
                              child: photoUrl == null
                                  ? const Icon(Icons.person, size: 40, color: Colors.grey)
                                  : null,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Welcome, $userName!',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 32),
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

  Widget _buildButton(BuildContext context, String route, String label, {bool isLogout = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: ElevatedButton(
        onPressed: () async {
          if (isLogout) {
            await FirebaseAuth.instance.signOut();
            Navigator.pushReplacementNamed(context, route);
          } else {
            Navigator.pushNamed(context, route);
          }
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: Colors.deepPurple,
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
          ),
        ),
        child: Text(label),
      ),
    );
  }
}
