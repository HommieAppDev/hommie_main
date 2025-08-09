import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'signup_screen.dart';
// import 'login_screen.dart'; // merged into Welcome
import 'search_screen.dart';
import 'advanced_search_screen.dart';
import 'welcome_screen.dart';
import 'search_results_screen.dart';
import 'profile_screen.dart';
import 'edit_profile_screen.dart';
import 'favorites_screen.dart';
import 'visited_properties_screen.dart';
import 'upload_listings.dart';
import 'home_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1) Load environment variables (SimplyRETS creds live here)
  await dotenv.load(fileName: ".env");

  // 2) Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // 3) Run the app
  runApp(const HommieApp());

  // 4) (Optional) Seed sample listings once after first frame
  //    TODO: remove when SimplyRETS is fully wired (to avoid duplicates)
  WidgetsBinding.instance.addPostFrameCallback((_) async {
    try {
      await uploadSampleListings();
    } catch (_) {
      // ignore failures here
    }
  });
}

class HommieApp extends StatelessWidget {
  const HommieApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Hommie',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      initialRoute: '/welcome',
      onGenerateRoute: (settings) {
        switch (settings.name) {
          case '/welcome':
            return MaterialPageRoute(builder: (_) => WelcomeScreen());

          case '/signup':
            return MaterialPageRoute(builder: (_) => SignUpScreen());

          case '/search':
            return MaterialPageRoute(builder: (_) => SearchScreen());

          case '/advanced-search':
            return MaterialPageRoute(builder: (_) => AdvancedSearchScreen());

          case '/profile':
            return MaterialPageRoute(builder: (_) => ProfileScreen());

          case '/edit-profile':
            return MaterialPageRoute(builder: (_) => EditProfileScreen());

          case '/visited':
            return MaterialPageRoute(builder: (_) => VisitedPropertiesScreen());

          case '/favorites':
            return MaterialPageRoute(builder: (_) => FavoritesScreen());

          case '/home':
            return MaterialPageRoute(builder: (_) => HomeScreen());

          case '/search-results':
            final args = settings.arguments;
            final map = (args is Map) ? Map<String, dynamic>.from(args) : const {};
            return MaterialPageRoute(
              builder: (_) => SearchResultsScreen(
                cityOrZip: map['query'],
                radiusMiles: map['radius'],
                price: map['price'],
                beds: map['beds'],
                baths: map['baths'],
              ),
            );

          default:
            return MaterialPageRoute(
              builder: (_) => const Scaffold(
                body: Center(child: Text('Route not found')),
              ),
            );
        }
      },
    );
  }
}
