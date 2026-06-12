import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../providers/app_data_provider.dart';
import '../services/api_service.dart';
import 'main_screen.dart';
import 'login_screen.dart';
import 'package:google_fonts/google_fonts.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    // Initialize Location
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<AppDataProvider>(context, listen: false).initLocation();
    });

    _checkAuth();
  }

  Future<void> _checkAuth() async {
    // Delay untuk splash screen
    await Future.delayed(const Duration(seconds: 2));

    final token = await ApiService.getToken();
    final prefs = await SharedPreferences.getInstance();
    final lastActiveStr = prefs.getString('last_active_time');

    bool sessionExpired = false;

    if (token != null) {
      if (lastActiveStr != null) {
        final lastActive = DateTime.parse(lastActiveStr);
        if (DateTime.now().difference(lastActive).inHours >= 24) {
          sessionExpired = true;
          await ApiService.logout();
        }
      }

      if (!sessionExpired) {
        // Refresh token since the user is active within 24 hours
        final refreshResult = await ApiService.refreshToken();
        if (refreshResult['success'] == true) {
          await prefs.setString(
            'last_active_time',
            DateTime.now().toIso8601String(),
          );
        } else {
          // If refresh fails (e.g. token actually invalid in backend), force login
          sessionExpired = true;
          await ApiService.logout();
        }
      }
    }

    if (mounted) {
      if (token != null && !sessionExpired) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const MainScreen()),
        );
      } else {
        if (sessionExpired) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Sesi anda telah berakhir silahkan login kembali.'),
              backgroundColor: Colors.red,
            ),
          );
        }
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const LoginScreen()),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).primaryColor,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.storefront, size: 100, color: Colors.white),
            const SizedBox(height: 24),
            Text(
              'Pangkalan Sate',
              style: GoogleFonts.nunito(
                fontSize: 32,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 24),
            const CircularProgressIndicator(color: Colors.white),
          ],
        ),
      ),
    );
  }
}
