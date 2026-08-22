import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  runApp(const CrimeSearchApp());
}

// ================================================================
// APP
// ================================================================

class CrimeSearchApp extends StatelessWidget {
  const CrimeSearchApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'CrimeSearch',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF0F172A)),
        scaffoldBackgroundColor: const Color(0xFFF5F7FA),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
          ),
        ),
      ),
      home: const AuthGate(),
    );
  }
}

// ================================================================
// AUTH GATE
// ================================================================

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        // Still checking Firebase
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        // No logged-in user
        if (!snapshot.hasData) {
          return const LoginPage();
        }

        // Logged-in user
        return const RoleGate();
      },
    );
  }
}

// ================================================================
// ROLE GATE
// ================================================================

class RoleGate extends StatelessWidget {
  const RoleGate({super.key});

  Future<String?> _getUserRole(String uid) async {
    final document = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .get();

    if (!document.exists) {
      return null;
    }

    final data = document.data();

    if (data == null) {
      return null;
    }

    return data['role'] as String?;
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return const LoginPage();
    }

    return FutureBuilder<String?>(
      future: _getUserRole(user.uid),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasError) {
          return const AccessDeniedPage(
            message: 'Unable to verify your account.',
          );
        }

        final role = snapshot.data;

        if (role == 'admin') {
          return const CrimeSearchHome(role: 'admin');
        }

        if (role == 'member') {
          return const CrimeSearchHome(role: 'member');
        }

        return const AccessDeniedPage(
          message: 'Your account does not have a valid CrimeSearch role.',
        );
      },
    );
  }
}

// ================================================================
// LOGIN PAGE
// ================================================================

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();

  bool loading = false;
  bool obscurePassword = true;
  String? errorMessage;

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    final email = emailController.text.trim();
    final password = passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      setState(() {
        errorMessage = 'Please enter your email and password.';
      });
      return;
    }

    setState(() {
      loading = true;
      errorMessage = null;
    });

    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
    } on FirebaseAuthException catch (e) {
      String message;

      switch (e.code) {
        case 'invalid-credential':
          message = 'Incorrect email or password.';
          break;

        case 'user-disabled':
          message = 'This account has been disabled.';
          break;

        case 'too-many-requests':
          message = 'Too many attempts. Please try again later.';
          break;

        case 'network-request-failed':
          message = 'Network error. Check your internet connection.';
          break;

        default:
          message = 'Unable to sign in. Please try again.';
      }

      if (mounted) {
        setState(() {
          errorMessage = message;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          errorMessage = 'An unexpected error occurred.';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          loading = false;
        });
      }
    }
  }

  Future<void> _forgotPassword() async {
    final email = emailController.text.trim();

    if (email.isEmpty) {
      setState(() {
        errorMessage = 'Enter your email address first.';
      });
      return;
    }

    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Password reset email sent. Check your inbox.'),
        ),
      );
    } on FirebaseAuthException catch (_) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to send password reset email.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 430),
            child: Card(
              elevation: 12,
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Icon(
                      Icons.security,
                      size: 55,
                      color: Color(0xFF0F172A),
                    ),

                    const SizedBox(height: 18),

                    const Text(
                      'CRIMESEARCH',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 27,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1,
                      ),
                    ),

                    const SizedBox(height: 5),

                    const Text(
                      'INTELLIGENCE',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.grey,
                        fontSize: 11,
                        letterSpacing: 3,
                      ),
                    ),

                    const SizedBox(height: 35),

                    TextField(
                      controller: emailController,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: 'Email',
                        prefixIcon: Icon(Icons.email_outlined),
                      ),
                    ),

                    const SizedBox(height: 15),

                    TextField(
                      controller: passwordController,
                      obscureText: obscurePassword,
                      onSubmitted: (_) => _login(),
                      decoration: InputDecoration(
                        labelText: 'Password',
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          icon: Icon(
                            obscurePassword
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                          ),
                          onPressed: () {
                            setState(() {
                              obscurePassword = !obscurePassword;
                            });
                          },
                        ),
                      ),
                    ),

                    const SizedBox(height: 12),

                    if (errorMessage != null)
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.red.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          errorMessage!,
                          style: const TextStyle(color: Colors.red),
                          textAlign: TextAlign.center,
                        ),
                      ),

                    const SizedBox(height: 18),

                    SizedBox(
                      height: 50,
                      child: FilledButton(
                        onPressed: loading ? null : _login,
                        child: loading
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text(
                                'SIGN IN',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                      ),
                    ),

                    const SizedBox(height: 8),

                    TextButton(
                      onPressed: loading ? null : _forgotPassword,
                      child: const Text('Forgot Password?'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ================================================================
// ACCESS DENIED
// ================================================================

class AccessDeniedPage extends StatelessWidget {
  final String message;

  const AccessDeniedPage({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(30),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.block, size: 60, color: Colors.red),

                  const SizedBox(height: 20),

                  const Text(
                    'ACCESS DENIED',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),

                  const SizedBox(height: 12),

                  Text(message, textAlign: TextAlign.center),

                  const SizedBox(height: 25),

                  FilledButton(
                    onPressed: () async {
                      await FirebaseAuth.instance.signOut();
                    },
                    child: const Text('SIGN OUT'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ================================================================
// MODELS
// ================================================================

class Suspect {
  String id;
  String name;
  String alias;
  String dob;
  String idNumber;
  String gender;
  String phone;
  String address;
  String description;
  Uint8List? facePhoto;
  List<Uint8List> tattooPhotos;
  List<Uint8List> scarPhotos;
  List<Uint8List> additionalPhotos;

  Suspect({
    required this.id,
    required this.name,
    this.alias = '',
    this.dob = '',
    this.idNumber = '',
    this.gender = 'Not specified',
    this.phone = '',
    this.address = '',
    this.description = '',
    this.facePhoto,
    List<Uint8List>? tattooPhotos,
    List<Uint8List>? scarPhotos,
    List<Uint8List>? additionalPhotos,
  }) : tattooPhotos = tattooPhotos ?? [],
       scarPhotos = scarPhotos ?? [],
       additionalPhotos = additionalPhotos ?? [];
}

class Vehicle {
  String id;
  String registration;
  String make;
  String model;
  String colour;
  String year;
  String description;
  List<Uint8List> photos;

  Vehicle({
    required this.id,
    required this.registration,
    this.make = '',
    this.model = '',
    this.colour = '',
    this.year = '',
    this.description = '',
    List<Uint8List>? photos,
  }) : photos = photos ?? [];
}

class Incident {
  String id;
  String title;
  String type;
  String date;
  String time;
  String location;
  String description;
  String status;
  List<Uint8List> photos;

  List<String> suspectIds;
  List<String> vehicleIds;

  Incident({
    required this.id,
    required this.title,
    required this.type,
    required this.date,
    required this.time,
    required this.location,
    required this.description,
    required this.status,
    List<Uint8List>? photos,
    List<String>? suspectIds,
    List<String>? vehicleIds,
  }) : photos = photos ?? [],
       suspectIds = suspectIds ?? [],
       vehicleIds = vehicleIds ?? [];
}

// ================================================================
// INVESTIGATION WORKSPACE MODELS
// ================================================================

class InvestigationEvent {
  String id;
  String incidentId;
  String title;
  String date;
  String time;
  String description;
  InvestigationEvent({
    required this.id,
    required this.incidentId,
    required this.title,
    required this.date,
    this.time = '',
    this.description = '',
  });
}

class EvidenceItem {
  String id;
  String incidentId;
  String title;
  String type;
  String description;
  Uint8List? photo;
  EvidenceItem({
    required this.id,
    required this.incidentId,
    required this.title,
    required this.type,
    this.description = '',
    this.photo,
  });
}

class CaseNote {
  String id;
  String incidentId;
  String title;
  String author;
  String date;
  String text;
  CaseNote({
    required this.id,
    required this.incidentId,
    required this.title,
    required this.author,
    required this.date,
    required this.text,
  });
}

// ================================================================
// HOME
// ================================================================

class CrimeSearchHome extends StatefulWidget {
  final String role;

  const CrimeSearchHome({super.key, required this.role});

  @override
  State<CrimeSearchHome> createState() => _CrimeSearchHomeState();
}

class _CrimeSearchHomeState extends State<CrimeSearchHome> {
  int selectedPage = 0;

  bool get isAdmin => widget.role == 'admin';
  bool get isMember => widget.role == 'member';

  final List<Suspect> suspects = [];
  final List<Vehicle> vehicles = [];
  final List<Incident> incidents = [];
  final List<InvestigationEvent> timelineEvents = [];
  final List<EvidenceItem> evidenceItems = [];
  final List<CaseNote> caseNotes = [];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Row(
          children: [
            if (MediaQuery.of(context).size.width >= 750)
              _buildDesktopSidebar(),

            Expanded(
              child: Column(
                children: [
                  _buildTopBar(),

                  Expanded(child: _buildCurrentPage()),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==============================================================
  // TOP BAR
  // ==============================================================

  Widget _buildTopBar() {
    final isMobile = MediaQuery.of(context).size.width < 750;

    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: Row(
        children: [
          if (isMobile)
            IconButton(
              onPressed: _showMobileDrawer,
              icon: const Icon(Icons.menu),
            ),

          Expanded(
            child: Text(
              _pageTitle(),
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
            ),
          ),

          IconButton(
            tooltip: 'Global Search',
            icon: const Icon(Icons.search),
            onPressed: () => setState(() => selectedPage = 6),
          ),

          PopupMenuButton<String>(
            tooltip: 'Account',
            icon: const Icon(Icons.account_circle_outlined),
            onSelected: (value) async {
              if (value == 'signout') {
                await FirebaseAuth.instance.signOut();
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem<String>(
                value: 'role',
                enabled: false,
                child: Row(
                  children: [
                    Icon(
                      isAdmin
                          ? Icons.admin_panel_settings_outlined
                          : Icons.person_outline,
                    ),
                    const SizedBox(width: 10),
                    Text(isAdmin ? 'Administrator' : 'Member'),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem<String>(
                value: 'signout',
                child: Row(
                  children: [
                    Icon(Icons.logout),
                    SizedBox(width: 10),
                    Text('Sign Out'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _pageTitle() {
    switch (selectedPage) {
      case 0:
        return 'Dashboard';
      case 1:
        return 'Incidents';
      case 2:
        return 'Suspects';
      case 3:
        return 'Vehicles';
      case 4:
        return 'Map';
      case 5:
        return 'Settings';
      case 6:
        return 'Global Search';
      case 7:
        return 'Investigation Timeline';
      case 8:
        return 'Evidence';
      case 9:
        return 'Notes';
      case 10:
        return 'Relationship Graph';
      default:
        return 'CrimeSearch';
    }
  }

  // ==============================================================
  // DESKTOP SIDEBAR
  // ==============================================================
  Widget _buildDesktopSidebar() {
    return Container(
      width: 230,
      color: const Color(0xFF111827),
      child: Column(
        children: [
          const SizedBox(height: 32),

          const Text(
            'CRIMESEARCH',
            style: TextStyle(
              color: Colors.white,
              fontSize: 21,
              fontWeight: FontWeight.bold,
              letterSpacing: 1,
            ),
          ),

          const SizedBox(height: 4),

          const Text(
            'INTELLIGENCE',
            style: TextStyle(
              color: Colors.white54,
              fontSize: 10,
              letterSpacing: 3,
            ),
          ),

          const SizedBox(height: 30),

          // Scrollable navigation area
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              physics: const BouncingScrollPhysics(),
              children: [
                _navigationItem(Icons.dashboard_outlined, 'Dashboard', 0),

                _navigationItem(Icons.warning_amber_rounded, 'Incidents', 1),

                _navigationItem(Icons.person_outline, 'Suspects', 2),

                _navigationItem(Icons.directions_car_outlined, 'Vehicles', 3),

                _navigationItem(Icons.map_outlined, 'Map', 4),

                _navigationItem(Icons.search, 'Global Search', 6),

                _navigationItem(Icons.timeline, 'Timeline', 7),

                _navigationItem(Icons.inventory_2_outlined, 'Evidence', 8),

                _navigationItem(Icons.notes_outlined, 'Notes', 9),

                _navigationItem(Icons.hub_outlined, 'Graph', 10),
              ],
            ),
          ),

          // Settings stays at the bottom
          _navigationItem(Icons.settings_outlined, 'Settings', 5),

          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _navigationItem(IconData icon, String title, int page) {
    final selected = selectedPage == page;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: selected ? Colors.white.withOpacity(0.12) : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
      ),
      child: ListTile(
        leading: Icon(icon, color: selected ? Colors.white : Colors.white60),
        title: Text(
          title,
          style: TextStyle(
            color: selected ? Colors.white : Colors.white60,
            fontWeight: selected ? FontWeight.bold : null,
          ),
        ),
        onTap: () {
          setState(() {
            selectedPage = page;
          });
        },
      ),
    );
  }
  // ==============================================================
  // MOBILE DRAWER
  // ==============================================================

  void _showMobileDrawer() {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Navigation',
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 250),
      pageBuilder: (context, animation, secondaryAnimation) {
        return Align(
          alignment: Alignment.centerLeft,
          child: Material(
            color: Colors.transparent,
            child: SafeArea(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: 310,
                  maxHeight: MediaQuery.of(context).size.height,
                ),
                child: Container(
                  width: MediaQuery.of(context).size.width * 0.80,
                  decoration: const BoxDecoration(
                    color: Color(0xFF111827),
                    borderRadius: BorderRadius.only(
                      topRight: Radius.circular(18),
                      bottomRight: Radius.circular(18),
                    ),
                  ),
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const SizedBox(height: 35),

                        const Text(
                          'CRIMESEARCH',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1,
                          ),
                        ),

                        const SizedBox(height: 5),

                        const Text(
                          'INTELLIGENCE',
                          style: TextStyle(
                            color: Colors.white54,
                            fontSize: 10,
                            letterSpacing: 3,
                          ),
                        ),

                        const SizedBox(height: 35),

                        _drawerItem(
                          context,
                          Icons.dashboard_outlined,
                          'Dashboard',
                          0,
                        ),

                        _drawerItem(
                          context,
                          Icons.warning_amber_rounded,
                          'Incidents',
                          1,
                        ),

                        _drawerItem(
                          context,
                          Icons.person_outline,
                          'Suspects',
                          2,
                        ),

                        _drawerItem(
                          context,
                          Icons.directions_car_outlined,
                          'Vehicles',
                          3,
                        ),

                        _drawerItem(context, Icons.map_outlined, 'Map', 4),

                        _drawerItem(context, Icons.search, 'Global Search', 6),

                        _drawerItem(context, Icons.timeline, 'Timeline', 7),

                        _drawerItem(
                          context,
                          Icons.inventory_2_outlined,
                          'Evidence',
                          8,
                        ),

                        _drawerItem(context, Icons.notes_outlined, 'Notes', 9),

                        _drawerItem(context, Icons.hub_outlined, 'Graph', 10),

                        _drawerItem(
                          context,
                          Icons.settings_outlined,
                          'Settings',
                          5,
                        ),

                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        return SlideTransition(
          position: Tween<Offset>(begin: const Offset(-1, 0), end: Offset.zero)
              .animate(
                CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
              ),
          child: child,
        );
      },
    );
  }

  Widget _drawerItem(
    BuildContext menuContext,
    IconData icon,
    String title,
    int page,
  ) {
    final selected = selectedPage == page;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
      decoration: BoxDecoration(
        color: selected ? Colors.white.withOpacity(0.12) : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
      ),
      child: ListTile(
        leading: Icon(icon, color: selected ? Colors.white : Colors.white60),
        title: Text(
          title,
          style: TextStyle(
            color: selected ? Colors.white : Colors.white60,
            fontWeight: selected ? FontWeight.bold : null,
          ),
        ),
        trailing: selected
            ? const Icon(Icons.check, color: Colors.white)
            : null,
        onTap: () {
          Navigator.of(menuContext).pop();

          setState(() {
            selectedPage = page;
          });
        },
      ),
    );
  }

  // ==============================================================
  // PAGE ROUTER
  // ==============================================================

  Widget _buildCurrentPage() {
    switch (selectedPage) {
      case 0:
        return _buildDashboard();

      case 1:
        return _buildIncidents();

      case 2:
        return _buildSuspects();

      case 3:
        return _buildVehicles();

      case 4:
        return _buildMap();

      case 5:
        return _buildSettings();
      case 6:
        return _buildGlobalSearch();
      case 7:
        return _buildTimeline();
      case 8:
        return _buildEvidence();
      case 9:
        return _buildNotes();
      case 10:
        return _buildGraph();

      default:
        return _buildDashboard();
    }
  }

  // ==============================================================
  // DASHBOARD
  // ==============================================================

  Widget _buildDashboard() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Dashboard',
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
          ),

          const SizedBox(height: 5),

          const Text(
            'Crime intelligence overview',
            style: TextStyle(color: Colors.grey),
          ),

          const SizedBox(height: 25),

          LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth < 600) {
                return Column(
                  children: [
                    _statCard(
                      'Incidents',
                      incidents.length.toString(),
                      Icons.warning_amber_rounded,
                    ),

                    const SizedBox(height: 12),

                    _statCard(
                      'Suspects',
                      suspects.length.toString(),
                      Icons.person_outline,
                    ),

                    const SizedBox(height: 12),

                    _statCard(
                      'Vehicles',
                      vehicles.length.toString(),
                      Icons.directions_car_outlined,
                    ),
                  ],
                );
              }

              return Row(
                children: [
                  Expanded(
                    child: _statCard(
                      'Incidents',
                      incidents.length.toString(),
                      Icons.warning_amber_rounded,
                    ),
                  ),

                  const SizedBox(width: 15),

                  Expanded(
                    child: _statCard(
                      'Suspects',
                      suspects.length.toString(),
                      Icons.person_outline,
                    ),
                  ),

                  const SizedBox(width: 15),

                  Expanded(
                    child: _statCard(
                      'Vehicles',
                      vehicles.length.toString(),
                      Icons.directions_car_outlined,
                    ),
                  ),
                ],
              );
            },
          ),

          const SizedBox(height: 25),

          _dashboardWorkspace(),

          const SizedBox(height: 25),

          if (incidents.isNotEmpty) _dashboardRecentIncidents(),
        ],
      ),
    );
  }

  Widget _statCard(String title, String value, IconData icon) {
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            Icon(icon, size: 34),

            const SizedBox(width: 15),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(color: Colors.grey)),

                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 27,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _dashboardWorkspace() {
    final open = incidents.where((i) => i.status != 'Closed').length;
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Investigation Workspace',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            const Text(
              'Search, trace, document and connect your investigations from one place.',
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 15),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _workspaceAction('Global Search', Icons.search, 6),
                _workspaceAction('Timeline', Icons.timeline, 7),
                _workspaceAction('Evidence', Icons.inventory_2_outlined, 8),
                _workspaceAction('Notes', Icons.notes_outlined, 9),
                _workspaceAction('Graph', Icons.hub_outlined, 10),
              ],
            ),
            const SizedBox(height: 15),
            Row(
              children: [
                const Icon(Icons.folder_open_outlined, size: 18),
                const SizedBox(width: 8),
                Text('$open active investigation${open == 1 ? '' : 's'}'),
                const Spacer(),
                Text('${timelineEvents.length} timeline events'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _workspaceAction(String title, IconData icon, int page) {
    return OutlinedButton.icon(
      onPressed: () => setState(() => selectedPage = page),
      icon: Icon(icon, size: 18),
      label: Text(title),
    );
  }

  Widget _dashboardRecentIncidents() {
    final recent = incidents.reversed.take(3).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Recent Incidents',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),

        const SizedBox(height: 12),

        ...recent.map(
          (incident) => Card(
            elevation: 0,
            child: ListTile(
              leading: const CircleAvatar(
                child: Icon(Icons.warning_amber_rounded),
              ),
              title: Text(incident.title),
              subtitle: Text('${incident.type} • ${incident.date}'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                _viewIncident(incident);
              },
            ),
          ),
        ),
      ],
    );
  }

  // ==============================================================
  // INCIDENTS
  // ==============================================================

  Widget _buildIncidents() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _pageHeader(
            'Incidents',
            'Manage reported incidents and cases',
            Icons.warning_amber_rounded,
            isAdmin ? 'Add Incident' : '',
            isAdmin ? _openAddIncident : () {},
          ),

          const SizedBox(height: 20),

          if (incidents.isEmpty)
            _emptyState(
              Icons.warning_amber_rounded,
              'No incidents yet',
              'Create your first incident report.',
              isAdmin ? 'Add Incident' : '',
              isAdmin ? _openAddIncident : () {},
            )
          else
            ...incidents.reversed.map((incident) => _incidentCard(incident)),
        ],
      ),
    );
  }

  Widget _incidentCard(Incident incident) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          _viewIncident(incident);
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.warning_amber_rounded,
                  color: Colors.orange.shade800,
                ),
              ),

              const SizedBox(width: 14),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      incident.title,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),

                    const SizedBox(height: 4),

                    Text(
                      incident.type,
                      style: const TextStyle(color: Colors.grey),
                    ),

                    const SizedBox(height: 4),

                    Text(
                      '${incident.date} • ${incident.location}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
              ),

              _statusChip(incident.status),

              const SizedBox(width: 5),

              PopupMenuButton<String>(
                onSelected: (value) {
                  if (value == 'view') _viewIncident(incident);
                  if (value == 'edit') _editIncident(incident);
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'view',
                    child: Text('View Incident'),
                  ),
                  if (isAdmin)
                    const PopupMenuItem(
                      value: 'edit',
                      child: Text('Edit Incident'),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _statusChip(String status) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: status == 'Closed'
            ? Colors.green.shade50
            : Colors.orange.shade50,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: status == 'Closed'
              ? Colors.green.shade800
              : Colors.orange.shade800,
        ),
      ),
    );
  }

  // ==============================================================
  // ADD INCIDENT
  // ==============================================================

  void _openAddIncident() {
    if (!isAdmin) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddIncidentPage(
          onSave: (incident) {
            setState(() {
              incidents.add(incident);
            });
          },
        ),
      ),
    );
  }

  // ==============================================================
  // EDIT INCIDENT
  // ==============================================================

  void _editIncident(Incident incident) {
    if (!isAdmin) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddIncidentPage(
          existing: incident,
          onSave: (updated) {
            setState(() {
              final index = incidents.indexWhere(
                (item) => item.id == updated.id,
              );
              if (index != -1) incidents[index] = updated;
            });
          },
        ),
      ),
    );
  }

  // ==============================================================
  // VIEW INCIDENT
  // ==============================================================

  void _viewIncident(Incident incident) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => IncidentDetailsPage(
          incident: incident,
          suspects: suspects,
          vehicles: vehicles,
          onChanged: () {
            setState(() {});
          },
          canEdit: isAdmin,
          onEdit: () => _editIncident(incident),
          onDelete: () {
            setState(() {
              incidents.removeWhere((item) => item.id == incident.id);
            });

            Navigator.pop(context);
          },
        ),
      ),
    );
  }

  // ==============================================================
  // SUSPECTS
  // ==============================================================

  Widget _buildSuspects() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _pageHeader(
            'Suspects',
            'Manage suspect profiles and intelligence',
            Icons.person_outline,
            isAdmin ? 'Add Suspect' : '',
            isAdmin ? _openAddSuspect : () {},
          ),

          const SizedBox(height: 20),

          if (suspects.isEmpty)
            _emptyState(
              Icons.person_search,
              'No suspects yet',
              'Create your first suspect profile.',
              isAdmin ? 'Add Suspect' : '',
              isAdmin ? _openAddSuspect : () {},
            )
          else
            ...suspects.map((suspect) => _suspectCard(suspect)),
        ],
      ),
    );
  }

  Widget _suspectCard(Suspect suspect) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        leading: suspect.facePhoto != null
            ? CircleAvatar(
                radius: 25,
                backgroundImage: MemoryImage(suspect.facePhoto!),
              )
            : const CircleAvatar(radius: 25, child: Icon(Icons.person)),
        title: Text(
          suspect.name,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          suspect.alias.isNotEmpty ? 'Alias: ${suspect.alias}' : 'No alias',
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (value) {
            if (value == 'view') _viewSuspect(suspect);
            if (value == 'edit') _editSuspect(suspect);
            if (value == 'delete') _confirmDeleteSuspect(suspect);
          },
          itemBuilder: (context) => [
            const PopupMenuItem(value: 'view', child: Text('View Suspect')),
            if (isAdmin)
              const PopupMenuItem(value: 'edit', child: Text('Edit Suspect')),
            if (isAdmin)
              const PopupMenuItem(
                value: 'delete',
                child: Text('Delete Suspect'),
              ),
          ],
        ),
        onTap: () => _viewSuspect(suspect),
      ),
    );
  }

  void _confirmDeleteSuspect(Suspect suspect) {
    if (!isAdmin) return;
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete Suspect?'),
        content: Text(
          'Are you sure you want to delete ${suspect.name}? This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              setState(() {
                suspects.removeWhere((item) => item.id == suspect.id);
                for (final incident in incidents) {
                  incident.suspectIds.remove(suspect.id);
                }
              });
              Navigator.pop(dialogContext);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('${suspect.name} deleted.')),
              );
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _openAddSuspect() {
    if (!isAdmin) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddSuspectPage(
          onSave: (suspect) {
            setState(() {
              suspects.add(suspect);
            });
          },
        ),
      ),
    );
  }

  void _editSuspect(Suspect suspect) {
    if (!isAdmin) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddSuspectPage(
          existing: suspect,
          onSave: (updated) {
            setState(() {
              final index = suspects.indexWhere(
                (item) => item.id == updated.id,
              );
              if (index != -1) suspects[index] = updated;
            });
          },
        ),
      ),
    );
  }

  void _viewSuspect(Suspect suspect) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SuspectDetailsPage(
          suspect: suspect,
          canEdit: isAdmin,
          onEdit: () => _editSuspect(suspect),
          onDelete: () {
            setState(() {
              suspects.removeWhere((item) => item.id == suspect.id);

              for (final incident in incidents) {
                incident.suspectIds.remove(suspect.id);
              }
            });

            Navigator.pop(context);
          },
        ),
      ),
    );
  }

  // ==============================================================
  // VEHICLES
  // ==============================================================

  Widget _buildVehicles() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _pageHeader(
            'Vehicles',
            'Manage vehicles linked to investigations',
            Icons.directions_car_outlined,
            isAdmin ? 'Add Vehicle' : '',
            isAdmin ? _openAddVehicle : () {},
          ),

          const SizedBox(height: 20),

          if (vehicles.isEmpty)
            _emptyState(
              Icons.directions_car_outlined,
              'No vehicles yet',
              'Create your first vehicle record.',
              isAdmin ? 'Add Vehicle' : '',
              isAdmin ? _openAddVehicle : () {},
            )
          else
            ...vehicles.map((vehicle) => _vehicleCard(vehicle)),
        ],
      ),
    );
  }

  Widget _vehicleCard(Vehicle vehicle) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: const CircleAvatar(child: Icon(Icons.directions_car_outlined)),
        title: Text(
          vehicle.registration,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text('${vehicle.make} ${vehicle.model}'),
        trailing: PopupMenuButton<String>(
          onSelected: (value) {
            if (value == 'view') _viewVehicle(vehicle);
            if (value == 'edit') _editVehicle(vehicle);
          },
          itemBuilder: (context) => [
            const PopupMenuItem(value: 'view', child: Text('View Vehicle')),
            if (isAdmin)
              const PopupMenuItem(value: 'edit', child: Text('Edit Vehicle')),
          ],
        ),
        onTap: () {
          _viewVehicle(vehicle);
        },
      ),
    );
  }

  void _openAddVehicle() {
    if (!isAdmin) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddVehiclePage(
          onSave: (vehicle) {
            setState(() {
              vehicles.add(vehicle);
            });
          },
        ),
      ),
    );
  }

  void _editVehicle(Vehicle vehicle) {
    if (!isAdmin) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddVehiclePage(
          existing: vehicle,
          onSave: (updated) {
            setState(() {
              final index = vehicles.indexWhere(
                (item) => item.id == updated.id,
              );
              if (index != -1) vehicles[index] = updated;
            });
          },
        ),
      ),
    );
  }

  void _viewVehicle(Vehicle vehicle) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => VehicleDetailsPage(
          vehicle: vehicle,
          canEdit: isAdmin,
          onEdit: () => _editVehicle(vehicle),
          onDelete: () {
            setState(() {
              vehicles.removeWhere((item) => item.id == vehicle.id);

              for (final incident in incidents) {
                incident.vehicleIds.remove(vehicle.id);
              }
            });

            Navigator.pop(context);
          },
        ),
      ),
    );
  }

  // ==============================================================
  // MAP
  // ==============================================================

  Widget _buildMap() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(25),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.map_outlined, size: 80, color: Colors.grey.shade400),

            const SizedBox(height: 15),

            const Text(
              'Crime Map',
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 8),

            const Text(
              'The interactive incident map will be added here.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),

            const SizedBox(height: 20),

            Text(
              '${incidents.length} incidents available',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }

  // ==============================================================
  // GLOBAL SEARCH
  // ==============================================================

  Widget _buildGlobalSearch() {
    return _GlobalSearchPanel(
      incidents: incidents,
      suspects: suspects,
      vehicles: vehicles,
      onIncident: _viewIncident,
      onSuspect: _viewSuspect,
      onVehicle: _viewVehicle,
    );
  }

  // ==============================================================
  // INVESTIGATION TIMELINE
  // ==============================================================

  Widget _buildTimeline() {
    final allEvents = <Map<String, dynamic>>[];
    for (final incident in incidents) {
      allEvents.add({
        'date': incident.date,
        'time': incident.time,
        'title': incident.title,
        'description': incident.description,
        'incident': incident,
        'kind': 'Incident',
      });
    }
    for (final event in timelineEvents) {
      final incident = incidents
          .where((i) => i.id == event.incidentId)
          .firstOrNull;
      allEvents.add({
        'date': event.date,
        'time': event.time,
        'title': event.title,
        'description': event.description,
        'incident': incident,
        'kind': 'Event',
      });
    }
    allEvents.sort(
      (a, b) =>
          '${b['date']} ${b['time']}'.compareTo('${a['date']} ${a['time']}'),
    );

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _pageHeader(
            'Investigation Timeline',
            'Chronological activity across incidents and investigations',
            Icons.timeline,
            isAdmin ? 'Add Event' : '',
            isAdmin ? _addTimelineEvent : () {},
          ),
          const SizedBox(height: 20),
          if (allEvents.isEmpty)
            _emptyState(
              Icons.timeline,
              'No timeline events',
              'Create an incident or add an investigation event.',
              isAdmin ? 'Add Event' : '',
              isAdmin ? _addTimelineEvent : () {},
            )
          else
            ...allEvents.map(_timelineCard),
        ],
      ),
    );
  }

  Widget _timelineCard(Map<String, dynamic> item) {
    final incident = item['incident'] as Incident?;
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          child: Icon(
            item['kind'] == 'Incident'
                ? Icons.warning_amber_rounded
                : Icons.event_note_outlined,
          ),
        ),
        title: Text(
          item['title'],
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          '${item['date']}${(item['time'] as String).isEmpty ? '' : ' • ${item['time']}'}\n${item['description']}',
        ),
        isThreeLine: true,
        trailing: incident == null ? null : const Icon(Icons.chevron_right),
        onTap: incident == null ? null : () => _viewIncident(incident),
      ),
    );
  }

  void _addTimelineEvent() {
    if (!isAdmin) return;
    if (incidents.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Create an incident before adding a timeline event.'),
        ),
      );
      return;
    }
    final title = TextEditingController();
    final date = TextEditingController();
    final time = TextEditingController();
    final description = TextEditingController();
    String incidentId = incidents.first.id;
    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Add Investigation Event'),
          content: SingleChildScrollView(
            child: SizedBox(
              width: 500,
              child: Column(
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: incidentId,
                    decoration: const InputDecoration(labelText: 'Incident'),
                    items: incidents
                        .map(
                          (i) => DropdownMenuItem(
                            value: i.id,
                            child: Text(i.title),
                          ),
                        )
                        .toList(),
                    onChanged: (v) =>
                        setDialogState(() => incidentId = v ?? incidentId),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: title,
                    decoration: const InputDecoration(labelText: 'Event title'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: date,
                    decoration: const InputDecoration(labelText: 'Date'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: time,
                    decoration: const InputDecoration(labelText: 'Time'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: description,
                    maxLines: 4,
                    decoration: const InputDecoration(labelText: 'Description'),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                if (title.text.trim().isEmpty || date.text.trim().isEmpty)
                  return;
                setState(() {
                  timelineEvents.add(
                    InvestigationEvent(
                      id: DateTime.now().microsecondsSinceEpoch.toString(),
                      incidentId: incidentId,
                      title: title.text.trim(),
                      date: date.text.trim(),
                      time: time.text.trim(),
                      description: description.text.trim(),
                    ),
                  );
                });
                Navigator.pop(dialogContext);
              },
              child: const Text('Add Event'),
            ),
          ],
        ),
      ),
    );
  }

  // ==============================================================
  // EVIDENCE
  // ==============================================================

  Widget _buildEvidence() {
    final rows = <Widget>[];
    for (final incident in incidents) {
      for (var i = 0; i < incident.photos.length; i++) {
        rows.add(
          _evidenceCard(
            EvidenceItem(
              id: '${incident.id}-photo-$i',
              incidentId: incident.id,
              title: 'Incident photo ${i + 1}',
              type: 'Incident Photo',
              description: incident.title,
              photo: incident.photos[i],
            ),
            canDelete: false,
          ),
        );
      }
    }
    for (final item in evidenceItems) {
      rows.add(_evidenceCard(item, canDelete: true));
    }
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _pageHeader(
            'Evidence',
            'Central evidence register for your investigations',
            Icons.inventory_2_outlined,
            isAdmin ? 'Add Evidence' : '',
            isAdmin ? _addEvidence : () {},
          ),
          const SizedBox(height: 20),
          if (rows.isEmpty)
            _emptyState(
              Icons.inventory_2_outlined,
              'No evidence yet',
              'Incident photos and evidence items will appear here.',
              isAdmin ? 'Add Evidence' : '',
              isAdmin ? _addEvidence : () {},
            )
          else
            ...rows,
        ],
      ),
    );
  }

  Widget _evidenceCard(EvidenceItem item, {bool canDelete = false}) {
    final incident = incidents
        .where((i) => i.id == item.incidentId)
        .firstOrNull;
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ListTile(
            leading: item.photo == null
                ? const CircleAvatar(child: Icon(Icons.inventory_2_outlined))
                : ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.memory(
                      item.photo!,
                      width: 55,
                      height: 55,
                      fit: BoxFit.cover,
                    ),
                  ),
            title: Text(
              item.title,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text(
              '${item.type}${incident == null ? '' : ' • ${incident.title}'}\n${item.description}',
            ),
            isThreeLine: true,
            onTap: () => _showEvidenceDetails(item, canDelete: canDelete),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  onPressed: () =>
                      _showEvidenceDetails(item, canDelete: canDelete),
                  icon: Icon(
                    item.photo == null
                        ? Icons.visibility_outlined
                        : Icons.image_outlined,
                    size: 18,
                  ),
                  label: const Text('View'),
                ),
                if (isAdmin && canDelete) ...[
                  const SizedBox(width: 6),
                  TextButton.icon(
                    onPressed: () => _deleteEvidence(item),
                    icon: const Icon(
                      Icons.delete_outline,
                      color: Colors.red,
                      size: 18,
                    ),
                    label: const Text(
                      'Delete',
                      style: TextStyle(color: Colors.red),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showEvidenceDetails(EvidenceItem item, {bool canDelete = false}) {
    final incident = incidents
        .where((i) => i.id == item.incidentId)
        .firstOrNull;

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(item.title),
        content: SizedBox(
          width: 600,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${item.type}${incident == null ? '' : ' • ${incident.title}'}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                if (item.description.trim().isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(item.description),
                ],
                if (item.photo != null) ...[
                  const SizedBox(height: 16),
                  GestureDetector(
                    onTap: () => _showFullPhoto(item.photo!),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxHeight: 420),
                        child: Image.memory(
                          item.photo!,
                          width: double.infinity,
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Click the image to enlarge and zoom.',
                    style: TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                ],
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Close'),
          ),
          if (isAdmin && canDelete)
            FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () {
                Navigator.pop(dialogContext);
                _deleteEvidence(item);
              },
              icon: const Icon(Icons.delete_outline),
              label: const Text('Delete'),
            ),
        ],
      ),
    );
  }

  void _showFullPhoto(Uint8List photo) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        child: InteractiveViewer(
          minScale: 0.5,
          maxScale: 6,
          child: Image.memory(photo, fit: BoxFit.contain),
        ),
      ),
    );
  }

  void _deleteEvidence(EvidenceItem item) {
    if (!isAdmin) return;
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete Evidence?'),
        content: Text('Delete "${item.title}"? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              setState(() {
                evidenceItems.removeWhere((e) => e.id == item.id);
              });
              Navigator.pop(dialogContext);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Evidence deleted.')),
              );
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _addEvidence() {
    if (!isAdmin) return;
    if (incidents.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Create an incident before adding evidence.'),
        ),
      );
      return;
    }
    final title = TextEditingController();
    final type = TextEditingController(text: 'Document');
    final description = TextEditingController();
    String incidentId = incidents.first.id;
    Uint8List? photo;
    final picker = ImagePicker();
    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Add Evidence'),
          content: SingleChildScrollView(
            child: SizedBox(
              width: 500,
              child: Column(
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: incidentId,
                    decoration: const InputDecoration(labelText: 'Incident'),
                    items: incidents
                        .map(
                          (i) => DropdownMenuItem(
                            value: i.id,
                            child: Text(i.title),
                          ),
                        )
                        .toList(),
                    onChanged: (v) =>
                        setDialogState(() => incidentId = v ?? incidentId),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: title,
                    decoration: const InputDecoration(
                      labelText: 'Evidence title',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: type,
                    decoration: const InputDecoration(
                      labelText: 'Evidence type',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: description,
                    maxLines: 4,
                    decoration: const InputDecoration(labelText: 'Description'),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: () async {
                      final picked = await picker.pickImage(
                        source: ImageSource.gallery,
                        imageQuality: 85,
                      );
                      if (picked != null) {
                        final bytes = await picked.readAsBytes();
                        setDialogState(() => photo = bytes);
                      }
                    },
                    icon: const Icon(Icons.add_a_photo_outlined),
                    label: Text(
                      photo == null ? 'Attach Photo' : 'Photo Attached',
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                if (title.text.trim().isEmpty) return;
                setState(() {
                  evidenceItems.add(
                    EvidenceItem(
                      id: DateTime.now().microsecondsSinceEpoch.toString(),
                      incidentId: incidentId,
                      title: title.text.trim(),
                      type: type.text.trim().isEmpty
                          ? 'Evidence'
                          : type.text.trim(),
                      description: description.text.trim(),
                      photo: photo,
                    ),
                  );
                });
                Navigator.pop(dialogContext);
              },
              child: const Text('Save Evidence'),
            ),
          ],
        ),
      ),
    );
  }

  // ==============================================================
  // NOTES
  // ==============================================================

  Widget _buildNotes() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _pageHeader(
            'Investigation Notes',
            'Keep case notes, observations and investigator updates together',
            Icons.notes_outlined,
            isAdmin ? 'Add Note' : '',
            isAdmin ? _addCaseNote : () {},
          ),
          const SizedBox(height: 20),
          if (caseNotes.isEmpty)
            _emptyState(
              Icons.notes_outlined,
              'No notes yet',
              'Add notes to an incident to build its investigation history.',
              isAdmin ? 'Add Note' : '',
              isAdmin ? _addCaseNote : () {},
            )
          else
            ...caseNotes.reversed.map(_noteCard),
        ],
      ),
    );
  }

  Widget _noteCard(CaseNote note) {
    final incident = incidents
        .where((i) => i.id == note.incidentId)
        .firstOrNull;
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ExpansionTile(
            leading: const CircleAvatar(child: Icon(Icons.notes_outlined)),
            title: Text(
              note.title,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text(
              '${note.author} • ${note.date}${incident == null ? '' : ' • ${incident.title}'}',
            ),
            childrenPadding: const EdgeInsets.fromLTRB(20, 0, 20, 18),
            children: [
              Align(alignment: Alignment.centerLeft, child: Text(note.text)),
            ],
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  onPressed: () => _showNoteDetails(note),
                  icon: const Icon(Icons.visibility_outlined, size: 18),
                  label: const Text('View'),
                ),
                if (isAdmin) const SizedBox(width: 6),
                if (isAdmin)
                  TextButton.icon(
                    onPressed: () => _deleteCaseNote(note),
                    icon: const Icon(
                      Icons.delete_outline,
                      color: Colors.red,
                      size: 18,
                    ),
                    label: const Text(
                      'Delete',
                      style: TextStyle(color: Colors.red),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showNoteDetails(CaseNote note) {
    final incident = incidents
        .where((i) => i.id == note.incidentId)
        .firstOrNull;

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(note.title),
        content: SizedBox(
          width: 600,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${note.author} • ${note.date}${incident == null ? '' : ' • ${incident.title}'}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                Text(note.text),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Close'),
          ),
          if (isAdmin)
            FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () {
                Navigator.pop(dialogContext);
                _deleteCaseNote(note);
              },
              icon: const Icon(Icons.delete_outline),
              label: const Text('Delete'),
            ),
        ],
      ),
    );
  }

  void _deleteCaseNote(CaseNote note) {
    if (!isAdmin) return;
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete Note?'),
        content: Text('Delete "${note.title}"? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              setState(() {
                caseNotes.removeWhere((n) => n.id == note.id);
              });
              Navigator.pop(dialogContext);
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(const SnackBar(content: Text('Note deleted.')));
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _addCaseNote() {
    if (!isAdmin) return;
    if (incidents.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Create an incident before adding a note.'),
        ),
      );
      return;
    }
    final title = TextEditingController();
    final author = TextEditingController(text: 'Investigator');
    final date = TextEditingController();
    final text = TextEditingController();
    String incidentId = incidents.first.id;
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Add Investigation Note'),
        content: SingleChildScrollView(
          child: SizedBox(
            width: 500,
            child: Column(
              children: [
                DropdownButtonFormField<String>(
                  initialValue: incidentId,
                  decoration: const InputDecoration(labelText: 'Incident'),
                  items: incidents
                      .map(
                        (i) =>
                            DropdownMenuItem(value: i.id, child: Text(i.title)),
                      )
                      .toList(),
                  onChanged: (v) => incidentId = v ?? incidentId,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: title,
                  decoration: const InputDecoration(labelText: 'Note title'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: author,
                  decoration: const InputDecoration(labelText: 'Author'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: date,
                  decoration: const InputDecoration(labelText: 'Date'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: text,
                  maxLines: 7,
                  decoration: const InputDecoration(labelText: 'Note'),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (title.text.trim().isEmpty || text.text.trim().isEmpty) return;
              setState(() {
                caseNotes.add(
                  CaseNote(
                    id: DateTime.now().microsecondsSinceEpoch.toString(),
                    incidentId: incidentId,
                    title: title.text.trim(),
                    author: author.text.trim().isEmpty
                        ? 'Investigator'
                        : author.text.trim(),
                    date: date.text.trim().isEmpty
                        ? DateTime.now().toString().split(' ').first
                        : date.text.trim(),
                    text: text.text.trim(),
                  ),
                );
              });
              Navigator.pop(dialogContext);
            },
            child: const Text('Save Note'),
          ),
        ],
      ),
    );
  }

  // ==============================================================
  // RELATIONSHIP GRAPH
  // ==============================================================

  Widget _buildGraph() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Relationship Graph',
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 5),
          const Text(
            'Visual relationship map between incidents, suspects and vehicles',
            style: TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 20),
          if (incidents.isEmpty)
            _emptyState(
              Icons.hub_outlined,
              'Nothing to graph yet',
              'Create incidents and link suspects or vehicles to build the network.',
              'Go to Incidents',
              () => setState(() => selectedPage = 1),
            )
          else
            ...incidents.map(_graphIncident),
        ],
      ),
    );
  }

  Widget _graphIncident(Incident incident) {
    final linkedSuspects = suspects
        .where((s) => incident.suspectIds.contains(s.id))
        .toList();
    final linkedVehicles = vehicles
        .where((v) => incident.vehicleIds.contains(v.id))
        .toList();
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 18),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          children: [
            InkWell(
              onTap: () => _viewIncident(incident),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(15),
                decoration: BoxDecoration(
                  color: Colors.blueGrey.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const CircleAvatar(
                      child: Icon(Icons.warning_amber_rounded),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        incident.title,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 17,
                        ),
                      ),
                    ),
                    _statusChip(incident.status),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            if (linkedSuspects.isEmpty && linkedVehicles.isEmpty)
              const Text(
                'No linked people or vehicles.',
                style: TextStyle(color: Colors.grey),
              )
            else ...[
              if (linkedSuspects.isNotEmpty) ...[
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Suspects',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: linkedSuspects
                      .map(
                        (s) => ActionChip(
                          avatar: const Icon(Icons.person, size: 18),
                          label: Text(s.name),
                          onPressed: () => _viewSuspect(s),
                        ),
                      )
                      .toList(),
                ),
              ],
              if (linkedVehicles.isNotEmpty) ...[
                const SizedBox(height: 14),
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Vehicles',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: linkedVehicles
                      .map(
                        (v) => ActionChip(
                          avatar: const Icon(Icons.directions_car, size: 18),
                          label: Text(v.registration),
                          onPressed: () => _viewVehicle(v),
                        ),
                      )
                      .toList(),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  // ==============================================================
  // SETTINGS
  // ==============================================================

  Widget _buildSettings() {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Text(
          'Settings',
          style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
        ),

        const SizedBox(height: 20),

        Card(
          elevation: 0,
          child: Column(
            children: const [
              ListTile(
                leading: Icon(Icons.person_outline),
                title: Text('Account'),
                subtitle: Text('Account settings will be added later.'),
              ),
              Divider(height: 1),
              ListTile(
                leading: Icon(Icons.security_outlined),
                title: Text('Security'),
                subtitle: Text('Security settings will be added later.'),
              ),
              Divider(height: 1),
              ListTile(
                leading: Icon(Icons.notifications_outlined),
                title: Text('Notifications'),
                subtitle: Text('Notification settings will be added later.'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ==============================================================
  // COMMON UI
  // ==============================================================

  Widget _pageHeader(
    String title,
    String subtitle,
    IconData icon,
    String buttonText,
    VoidCallback onPressed,
  ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 550) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, size: 28),

                  const SizedBox(width: 10),

                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 5),

              Text(subtitle, style: const TextStyle(color: Colors.grey)),

              const SizedBox(height: 15),

              if (buttonText.isNotEmpty)
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: onPressed,
                    icon: const Icon(Icons.add),
                    label: Text(buttonText),
                  ),
                ),
            ],
          );
        }

        return Row(
          children: [
            Icon(icon, size: 30),

            const SizedBox(width: 10),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 4),

                  Text(subtitle, style: const TextStyle(color: Colors.grey)),
                ],
              ),
            ),

            if (buttonText.isNotEmpty)
              ElevatedButton.icon(
                onPressed: onPressed,
                icon: const Icon(Icons.add),
                label: Text(buttonText),
              ),
          ],
        );
      },
    );
  }

  Widget _emptyState(
    IconData icon,
    String title,
    String subtitle,
    String buttonText,
    VoidCallback onPressed,
  ) {
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 60, horizontal: 20),
        child: Center(
          child: Column(
            children: [
              Icon(icon, size: 65, color: Colors.grey.shade400),

              const SizedBox(height: 15),

              Text(
                title,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 6),

              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.grey),
              ),

              const SizedBox(height: 20),

              if (buttonText.isNotEmpty)
                ElevatedButton.icon(
                  onPressed: onPressed,
                  icon: const Icon(Icons.add),
                  label: Text(buttonText),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ================================================================
// GLOBAL SEARCH PANEL
// ================================================================

class _GlobalSearchPanel extends StatefulWidget {
  final List<Incident> incidents;
  final List<Suspect> suspects;
  final List<Vehicle> vehicles;
  final ValueChanged<Incident> onIncident;
  final ValueChanged<Suspect> onSuspect;
  final ValueChanged<Vehicle> onVehicle;
  const _GlobalSearchPanel({
    required this.incidents,
    required this.suspects,
    required this.vehicles,
    required this.onIncident,
    required this.onSuspect,
    required this.onVehicle,
  });
  @override
  State<_GlobalSearchPanel> createState() => _GlobalSearchPanelState();
}

class _GlobalSearchPanelState extends State<_GlobalSearchPanel> {
  final controller = TextEditingController();
  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = controller.text.trim().toLowerCase();
    final ir = widget.incidents
        .where(
          (i) => _matches([
            i.id,
            i.title,
            i.type,
            i.date,
            i.time,
            i.location,
            i.description,
            i.status,
          ], query),
        )
        .toList();
    final sr = widget.suspects
        .where(
          (s) => _matches([
            s.id,
            s.name,
            s.alias,
            s.dob,
            s.idNumber,
            s.gender,
            s.phone,
            s.address,
            s.description,
          ], query),
        )
        .toList();
    final vr = widget.vehicles
        .where(
          (v) => _matches([
            v.id,
            v.registration,
            v.make,
            v.model,
            v.colour,
            v.year,
            v.description,
          ], query),
        )
        .toList();
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Global Search',
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 5),
          const Text(
            'Search incidents, suspects and vehicles from one field.',
            style: TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: controller,
            autofocus: true,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText:
                  'Search name, alias, ID, registration, incident, location...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: controller.text.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        controller.clear();
                        setState(() {});
                      },
                    ),
            ),
          ),
          const SizedBox(height: 20),
          if (query.isEmpty)
            Card(
              elevation: 0,
              child: const Padding(
                padding: EdgeInsets.all(24),
                child: Column(
                  children: [
                    Icon(Icons.search, size: 50),
                    SizedBox(height: 10),
                    Text(
                      'Start typing to search the entire intelligence database.',
                    ),
                  ],
                ),
              ),
            )
          else ...[
            _resultSection(
              'Incidents (${ir.length})',
              Icons.warning_amber_rounded,
              ir
                  .map(
                    (i) => ListTile(
                      leading: const CircleAvatar(
                        child: Icon(Icons.warning_amber_rounded),
                      ),
                      title: Text(i.title),
                      subtitle: Text('${i.type} • ${i.location} • ${i.date}'),
                      onTap: () => widget.onIncident(i),
                    ),
                  )
                  .toList(),
            ),
            _resultSection(
              'Suspects (${sr.length})',
              Icons.person_outline,
              sr
                  .map(
                    (s) => ListTile(
                      leading: s.facePhoto == null
                          ? const CircleAvatar(child: Icon(Icons.person))
                          : CircleAvatar(
                              backgroundImage: MemoryImage(s.facePhoto!),
                            ),
                      title: Text(s.name),
                      subtitle: Text(
                        s.alias.isEmpty ? 'No alias' : 'Alias: ${s.alias}',
                      ),
                      onTap: () => widget.onSuspect(s),
                    ),
                  )
                  .toList(),
            ),
            _resultSection(
              'Vehicles (${vr.length})',
              Icons.directions_car_outlined,
              vr
                  .map(
                    (v) => ListTile(
                      leading: const CircleAvatar(
                        child: Icon(Icons.directions_car),
                      ),
                      title: Text(v.registration),
                      subtitle: Text('${v.make} ${v.model} • ${v.colour}'),
                      onTap: () => widget.onVehicle(v),
                    ),
                  )
                  .toList(),
            ),
          ],
        ],
      ),
    );
  }

  bool _matches(List<String> values, String query) =>
      query.isNotEmpty && values.any((v) => v.toLowerCase().contains(query));
  Widget _resultSection(String title, IconData icon, List<Widget> children) =>
      Card(
        elevation: 0,
        margin: const EdgeInsets.only(bottom: 15),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            children: [
              ListTile(
                leading: Icon(icon),
                title: Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              if (children.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(15),
                  child: Text(
                    'No matches found.',
                    style: TextStyle(color: Colors.grey),
                  ),
                )
              else
                ...children,
            ],
          ),
        ),
      );
}

// ================================================================
// ADD INCIDENT PAGE
// ================================================================

class AddIncidentPage extends StatefulWidget {
  final Incident? existing;
  final Function(Incident) onSave;

  const AddIncidentPage({super.key, this.existing, required this.onSave});

  @override
  State<AddIncidentPage> createState() => _AddIncidentPageState();
}

class _AddIncidentPageState extends State<AddIncidentPage> {
  final formKey = GlobalKey<FormState>();

  final titleController = TextEditingController();
  final dateController = TextEditingController();
  final timeController = TextEditingController();
  final locationController = TextEditingController();
  final descriptionController = TextEditingController();

  String type = 'Theft';
  String status = 'Open';

  final ImagePicker _picker = ImagePicker();
  final List<Uint8List> photos = [];

  final incidentTypes = [
    'Theft',
    'Robbery',
    'Burglary',
    'Assault',
    'Fraud',
    'Vandalism',
    'Murder',
    'Missing Person',
    'Other',
  ];

  final statuses = ['Open', 'Under Investigation', 'Closed'];

  @override
  void initState() {
    super.initState();
    final incident = widget.existing;
    if (incident != null) {
      titleController.text = incident.title;
      dateController.text = incident.date;
      timeController.text = incident.time;
      locationController.text = incident.location;
      descriptionController.text = incident.description;
      type = incident.type;
      status = incident.status;
      photos.addAll(incident.photos);
    }
  }

  @override
  void dispose() {
    titleController.dispose();
    dateController.dispose();
    timeController.dispose();
    locationController.dispose();
    descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.existing == null ? 'Add Incident' : 'Edit Incident'),
      ),
      body: Form(
        key: formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _sectionTitle(
                'Incident Information',
                Icons.warning_amber_rounded,
              ),

              const SizedBox(height: 15),

              _field(
                titleController,
                'Incident Title',
                'Example: Armed robbery',
                Icons.title,
                required: true,
              ),

              DropdownButtonFormField<String>(
                initialValue: type,
                decoration: const InputDecoration(
                  labelText: 'Incident Type',
                  prefixIcon: Icon(Icons.category_outlined),
                ),
                items: incidentTypes
                    .map(
                      (item) =>
                          DropdownMenuItem(value: item, child: Text(item)),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() {
                      type = value;
                    });
                  }
                },
              ),

              const SizedBox(height: 14),

              _field(
                dateController,
                'Date',
                'DD/MM/YYYY',
                Icons.calendar_today_outlined,
                required: true,
              ),

              _field(
                timeController,
                'Time',
                'HH:MM',
                Icons.access_time_outlined,
              ),

              _field(
                locationController,
                'Location',
                'Where did this happen?',
                Icons.location_on_outlined,
                required: true,
                maxLines: 2,
              ),

              DropdownButtonFormField<String>(
                initialValue: status,
                decoration: const InputDecoration(
                  labelText: 'Status',
                  prefixIcon: Icon(Icons.flag_outlined),
                ),
                items: statuses
                    .map(
                      (item) =>
                          DropdownMenuItem(value: item, child: Text(item)),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() {
                      status = value;
                    });
                  }
                },
              ),

              const SizedBox(height: 20),

              _sectionTitle('Description', Icons.description_outlined),

              const SizedBox(height: 14),

              TextFormField(
                controller: descriptionController,
                maxLines: 7,
                decoration: const InputDecoration(
                  hintText: 'Describe what happened...',
                  alignLabelWithHint: true,
                ),
              ),

              const SizedBox(height: 20),

              _sectionTitle('Incident Photos', Icons.photo_library_outlined),

              const SizedBox(height: 12),

              _photoPicker(),

              const SizedBox(height: 30),

              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: _save,
                  icon: const Icon(Icons.save_outlined),
                  label: Text(
                    widget.existing == null ? 'SAVE INCIDENT' : 'SAVE CHANGES',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionTitle(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon),

        const SizedBox(width: 8),

        Text(
          title,
          style: const TextStyle(fontSize: 19, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  Widget _field(
    TextEditingController controller,
    String label,
    String hint,
    IconData icon, {
    bool required = false,
    int maxLines = 1,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextFormField(
        controller: controller,
        maxLines: maxLines,
        validator: required
            ? (value) {
                if (value == null || value.trim().isEmpty) {
                  return '$label is required';
                }
                return null;
              }
            : null,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          prefixIcon: Icon(icon),
        ),
      ),
    );
  }

  Widget _photoPicker() {
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Evidence / Incident Photos',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                IconButton(
                  onPressed: _pickPhotos,
                  icon: const Icon(Icons.add_a_photo_outlined),
                  tooltip: 'Add photos',
                ),
              ],
            ),
            if (photos.isEmpty)
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'No photos added yet.',
                  style: TextStyle(color: Colors.grey),
                ),
              )
            else
              SizedBox(
                height: 100,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: photos.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 10),
                  itemBuilder: (_, index) => Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Image.memory(
                          photos[index],
                          width: 100,
                          height: 100,
                          fit: BoxFit.cover,
                        ),
                      ),
                      Positioned(
                        right: 3,
                        top: 3,
                        child: InkWell(
                          onTap: () => setState(() => photos.removeAt(index)),
                          child: const CircleAvatar(
                            radius: 13,
                            child: Icon(Icons.close, size: 16),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickPhotos() async {
    final picked = await _picker.pickMultiImage(imageQuality: 85);
    if (picked.isEmpty) return;
    final bytes = <Uint8List>[];
    for (final image in picked) {
      bytes.add(await image.readAsBytes());
    }
    if (!mounted) return;
    setState(() => photos.addAll(bytes));
  }

  void _save() {
    if (!formKey.currentState!.validate()) {
      return;
    }

    final existing = widget.existing;
    final incident = Incident(
      id: existing?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
      title: titleController.text.trim(),
      type: type,
      date: dateController.text.trim(),
      time: timeController.text.trim(),
      location: locationController.text.trim(),
      description: descriptionController.text.trim(),
      status: status,
      photos: List<Uint8List>.from(photos),
      suspectIds: List<String>.from(existing?.suspectIds ?? const []),
      vehicleIds: List<String>.from(existing?.vehicleIds ?? const []),
    );

    widget.onSave(incident);

    Navigator.pop(context);
  }
}

// ================================================================
// INCIDENT DETAILS
// ================================================================

class IncidentDetailsPage extends StatefulWidget {
  final Incident incident;
  final List<Suspect> suspects;
  final List<Vehicle> vehicles;
  final VoidCallback onChanged;
  final bool canEdit;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const IncidentDetailsPage({
    super.key,
    required this.incident,
    required this.suspects,
    required this.vehicles,
    required this.onChanged,
    this.canEdit = true,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  State<IncidentDetailsPage> createState() => _IncidentDetailsPageState();
}

class _IncidentDetailsPageState extends State<IncidentDetailsPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Incident Details'),
        actions: [
          if (widget.canEdit) ...[
            IconButton(
              tooltip: 'Edit Incident',
              icon: const Icon(Icons.edit_outlined),
              onPressed: widget.onEdit,
            ),
            IconButton(
              tooltip: 'Delete',
              icon: const Icon(Icons.delete_outline),
              onPressed: _confirmDelete,
            ),
          ],
        ],
      ),

      body: SingleChildScrollView(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _header(),

            const SizedBox(height: 20),

            _informationCard(),

            const SizedBox(height: 20),

            _incidentPhotos(),

            const SizedBox(height: 20),

            _linkedSuspects(),

            const SizedBox(height: 20),

            _linkedVehicles(),
          ],
        ),
      ),
    );
  }

  Widget _header() {
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.incident.title,
              style: const TextStyle(fontSize: 25, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 8),

            Row(
              children: [
                Text(widget.incident.type),

                const SizedBox(width: 10),

                _statusChip(widget.incident.status),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _statusChip(String status) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status,
        style: TextStyle(
          color: Colors.orange.shade800,
          fontWeight: FontWeight.bold,
          fontSize: 11,
        ),
      ),
    );
  }

  Widget _informationCard() {
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          children: [
            _infoRow(
              Icons.calendar_today_outlined,
              'Date',
              widget.incident.date,
            ),

            _infoRow(
              Icons.access_time_outlined,
              'Time',
              widget.incident.time.isEmpty
                  ? 'Not specified'
                  : widget.incident.time,
            ),

            _infoRow(
              Icons.location_on_outlined,
              'Location',
              widget.incident.location,
            ),

            const Divider(),

            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Description',
                style: TextStyle(
                  color: Colors.grey.shade700,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),

            const SizedBox(height: 8),

            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                widget.incident.description.isEmpty
                    ? 'No description provided.'
                    : widget.incident.description,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(IconData icon, String title, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 15),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 21),

          const SizedBox(width: 12),

          SizedBox(
            width: 75,
            child: Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),

          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  Widget _incidentPhotos() {
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Incident Photos',
              style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            if (widget.incident.photos.isEmpty)
              const Text(
                'No photos attached to this incident.',
                style: TextStyle(color: Colors.grey),
              )
            else
              SizedBox(
                height: 120,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: widget.incident.photos.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 10),
                  itemBuilder: (_, index) => GestureDetector(
                    onTap: () => _showFullPhoto(widget.incident.photos[index]),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.memory(
                        widget.incident.photos[index],
                        width: 120,
                        height: 120,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _showFullPhoto(Uint8List photo) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        child: InteractiveViewer(
          child: Image.memory(photo, fit: BoxFit.contain),
        ),
      ),
    );
  }

  // ==============================================================
  // LINKED SUSPECTS
  // ==============================================================

  Widget _linkedSuspects() {
    final linked = widget.suspects
        .where((suspect) => widget.incident.suspectIds.contains(suspect.id))
        .toList();

    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Suspects',
                    style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold),
                  ),
                ),

                if (widget.canEdit)
                  OutlinedButton.icon(
                    onPressed: _addSuspect,
                    icon: const Icon(Icons.add),
                    label: const Text('Add'),
                  ),
              ],
            ),

            const SizedBox(height: 12),

            if (linked.isEmpty)
              const Text(
                'No suspects linked to this incident.',
                style: TextStyle(color: Colors.grey),
              )
            else
              ...linked.map(
                (suspect) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const CircleAvatar(child: Icon(Icons.person)),
                  title: Text(suspect.name),
                  subtitle: Text(
                    suspect.alias.isEmpty ? 'No alias' : suspect.alias,
                  ),
                  trailing: widget.canEdit
                      ? IconButton(
                          icon: const Icon(Icons.remove_circle_outline),
                          onPressed: () {
                            setState(() {
                              widget.incident.suspectIds.remove(suspect.id);
                            });
                            widget.onChanged();
                          },
                        )
                      : null,
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _addSuspect() {
    if (!widget.canEdit) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) {
        return _SuspectSelector(
          suspects: widget.suspects,
          alreadyLinked: widget.incident.suspectIds,
          onSelect: (suspect) {
            setState(() {
              widget.incident.suspectIds.add(suspect.id);
            });

            widget.onChanged();

            Navigator.pop(context);
          },
        );
      },
    );
  }

  // ==============================================================
  // LINKED VEHICLES
  // ==============================================================

  Widget _linkedVehicles() {
    final linked = widget.vehicles
        .where((vehicle) => widget.incident.vehicleIds.contains(vehicle.id))
        .toList();

    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Vehicles',
                    style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold),
                  ),
                ),

                OutlinedButton.icon(
                  onPressed: () {
                    if (widget.vehicles.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Create a vehicle first.'),
                        ),
                      );
                      return;
                    }

                    _selectVehicle();
                  },
                  icon: const Icon(Icons.add),
                  label: const Text('Add'),
                ),
              ],
            ),

            const SizedBox(height: 12),

            if (linked.isEmpty)
              const Text(
                'No vehicles linked to this incident.',
                style: TextStyle(color: Colors.grey),
              )
            else
              ...linked.map(
                (vehicle) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const CircleAvatar(
                    child: Icon(Icons.directions_car),
                  ),
                  title: Text(vehicle.registration),
                  subtitle: Text('${vehicle.make} ${vehicle.model}'),
                  trailing: widget.canEdit
                      ? IconButton(
                          icon: const Icon(Icons.remove_circle_outline),
                          onPressed: () {
                            setState(() {
                              widget.incident.vehicleIds.remove(vehicle.id);
                            });
                            widget.onChanged();
                          },
                        )
                      : null,
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _selectVehicle() {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (_) {
        return ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.all(15),
          children: widget.vehicles
              .map(
                (vehicle) => ListTile(
                  leading: const CircleAvatar(
                    child: Icon(Icons.directions_car),
                  ),
                  title: Text(vehicle.registration),
                  subtitle: Text('${vehicle.make} ${vehicle.model}'),
                  onTap: () {
                    if (!widget.incident.vehicleIds.contains(vehicle.id)) {
                      setState(() {
                        widget.incident.vehicleIds.add(vehicle.id);
                      });
                    }

                    widget.onChanged();

                    Navigator.pop(context);
                  },
                ),
              )
              .toList(),
        );
      },
    );
  }

  // ==============================================================
  // DELETE
  // ==============================================================

  void _confirmDelete() {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Delete Incident?'),
          content: const Text(
            'This incident will be removed from the current application data.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
              },
              child: const Text('Cancel'),
            ),

            FilledButton(
              onPressed: () {
                Navigator.pop(dialogContext);
                widget.onDelete();
              },
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
  }
}

// ================================================================
// SUSPECT SELECTOR
// ================================================================

class _SuspectSelector extends StatefulWidget {
  final List<Suspect> suspects;
  final List<String> alreadyLinked;
  final Function(Suspect) onSelect;

  const _SuspectSelector({
    required this.suspects,
    required this.alreadyLinked,
    required this.onSelect,
  });

  @override
  State<_SuspectSelector> createState() => _SuspectSelectorState();
}

class _SuspectSelectorState extends State<_SuspectSelector> {
  String search = '';

  @override
  Widget build(BuildContext context) {
    final results = widget.suspects.where((suspect) {
      final name = suspect.name.toLowerCase();

      final alias = suspect.alias.toLowerCase();

      return (name.contains(search.toLowerCase()) ||
              alias.contains(search.toLowerCase())) &&
          !widget.alreadyLinked.contains(suspect.id);
    }).toList();

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: SizedBox(
          height: MediaQuery.of(context).size.height * 0.65,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Add Suspect',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),

              const SizedBox(height: 15),

              TextField(
                onChanged: (value) {
                  setState(() {
                    search = value;
                  });
                },
                decoration: const InputDecoration(
                  hintText: 'Search suspects...',
                  prefixIcon: Icon(Icons.search),
                ),
              ),

              const SizedBox(height: 15),

              Expanded(
                child: results.isEmpty
                    ? const Center(
                        child: Text(
                          'No matching suspects.',
                          style: TextStyle(color: Colors.grey),
                        ),
                      )
                    : ListView.builder(
                        itemCount: results.length,
                        itemBuilder: (context, index) {
                          final suspect = results[index];

                          return ListTile(
                            leading: const CircleAvatar(
                              child: Icon(Icons.person),
                            ),
                            title: Text(suspect.name),
                            subtitle: Text(
                              suspect.alias.isEmpty
                                  ? 'No alias'
                                  : 'Alias: ${suspect.alias}',
                            ),
                            trailing: const Icon(Icons.add),
                            onTap: () {
                              widget.onSelect(suspect);
                            },
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ================================================================
// ADD SUSPECT PAGE
// ================================================================

class AddSuspectPage extends StatefulWidget {
  final Suspect? existing;
  final Function(Suspect) onSave;

  const AddSuspectPage({super.key, this.existing, required this.onSave});

  @override
  State<AddSuspectPage> createState() => _AddSuspectPageState();
}

class _AddSuspectPageState extends State<AddSuspectPage> {
  final formKey = GlobalKey<FormState>();

  final nameController = TextEditingController();

  final aliasController = TextEditingController();

  final dobController = TextEditingController();

  final idController = TextEditingController();

  final phoneController = TextEditingController();

  final addressController = TextEditingController();

  final descriptionController = TextEditingController();

  String gender = 'Not specified';

  final ImagePicker _picker = ImagePicker();
  Uint8List? facePhoto;
  final List<Uint8List> tattooPhotos = [];
  final List<Uint8List> scarPhotos = [];
  final List<Uint8List> additionalPhotos = [];

  @override
  void initState() {
    super.initState();
    final suspect = widget.existing;
    if (suspect != null) {
      nameController.text = suspect.name;
      aliasController.text = suspect.alias;
      dobController.text = suspect.dob;
      idController.text = suspect.idNumber;
      phoneController.text = suspect.phone;
      addressController.text = suspect.address;
      descriptionController.text = suspect.description;
      gender = suspect.gender;
      facePhoto = suspect.facePhoto;
      tattooPhotos.addAll(suspect.tattooPhotos);
      scarPhotos.addAll(suspect.scarPhotos);
      additionalPhotos.addAll(suspect.additionalPhotos);
    }
  }

  @override
  void dispose() {
    nameController.dispose();
    aliasController.dispose();
    dobController.dispose();
    idController.dispose();
    phoneController.dispose();
    addressController.dispose();
    descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.existing == null ? 'Add Suspect' : 'Edit Suspect'),
      ),

      body: Form(
        key: formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _section('Personal Information', Icons.person_outline),

              const SizedBox(height: 15),

              _field(
                nameController,
                'Full Name',
                'Enter suspect name',
                Icons.person_outline,
                required: true,
              ),

              _field(
                aliasController,
                'Alias / Known As',
                'Optional',
                Icons.badge_outlined,
              ),

              _field(
                dobController,
                'Date of Birth',
                'DD/MM/YYYY',
                Icons.calendar_today_outlined,
              ),

              _field(
                idController,
                'ID / Passport Number',
                'Optional',
                Icons.credit_card_outlined,
              ),

              DropdownButtonFormField<String>(
                initialValue: gender,
                decoration: const InputDecoration(
                  labelText: 'Gender',
                  prefixIcon: Icon(Icons.wc_outlined),
                ),
                items: const [
                  DropdownMenuItem(
                    value: 'Not specified',
                    child: Text('Not specified'),
                  ),
                  DropdownMenuItem(value: 'Male', child: Text('Male')),
                  DropdownMenuItem(value: 'Female', child: Text('Female')),
                  DropdownMenuItem(value: 'Other', child: Text('Other')),
                ],
                onChanged: (value) {
                  if (value != null) {
                    setState(() {
                      gender = value;
                    });
                  }
                },
              ),

              const SizedBox(height: 14),

              _field(
                phoneController,
                'Phone Number',
                'Optional',
                Icons.phone_outlined,
              ),

              _field(
                addressController,
                'Address',
                'Known address',
                Icons.location_on_outlined,
                maxLines: 2,
              ),

              const SizedBox(height: 18),

              _section('Identification Photos', Icons.photo_camera_outlined),

              const SizedBox(height: 8),

              const Text(
                'Photo uploads will be connected to the camera/gallery and backend later.',
                style: TextStyle(color: Colors.grey),
              ),

              const SizedBox(height: 15),

              _photoBox(
                'Face / Front',
                Icons.face,
                photo: facePhoto,
                onPick: _pickFacePhoto,
                onRemove: facePhoto == null
                    ? null
                    : () => setState(() => facePhoto = null),
              ),
              _photoBox(
                'Tattoos',
                Icons.brush_outlined,
                photos: tattooPhotos,
                onPick: () => _pickPhotos(tattooPhotos),
              ),
              _photoBox(
                'Scars / Marks',
                Icons.healing_outlined,
                photos: scarPhotos,
                onPick: () => _pickPhotos(scarPhotos),
              ),
              _photoBox(
                'Additional Photos',
                Icons.photo_library_outlined,
                photos: additionalPhotos,
                onPick: () => _pickPhotos(additionalPhotos),
              ),

              const SizedBox(height: 18),

              _section('Physical Description', Icons.description_outlined),

              const SizedBox(height: 14),

              TextFormField(
                controller: descriptionController,
                maxLines: 6,
                decoration: const InputDecoration(
                  hintText:
                      'Height, build, hair, eyes, tattoos, scars, clothing, etc.',
                  alignLabelWithHint: true,
                ),
              ),

              const SizedBox(height: 30),

              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: _save,
                  icon: const Icon(Icons.save),
                  label: Text(
                    widget.existing == null ? 'SAVE SUSPECT' : 'SAVE CHANGES',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),

              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }

  Widget _section(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon),

        const SizedBox(width: 8),

        Expanded(
          child: Text(
            title,
            style: const TextStyle(fontSize: 19, fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }

  Widget _field(
    TextEditingController controller,
    String label,
    String hint,
    IconData icon, {
    bool required = false,
    int maxLines = 1,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextFormField(
        controller: controller,
        maxLines: maxLines,
        validator: required
            ? (value) {
                if (value == null || value.trim().isEmpty) {
                  return '$label is required';
                }

                return null;
              }
            : null,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          prefixIcon: Icon(icon),
        ),
      ),
    );
  }

  Widget _photoBox(
    String title,
    IconData icon, {
    Uint8List? photo,
    List<Uint8List>? photos,
    required VoidCallback onPick,
    VoidCallback? onRemove,
  }) {
    final items = <Uint8List>[if (photo != null) photo, ...?photos];
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            Row(
              children: [
                Icon(icon),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                IconButton(
                  onPressed: onPick,
                  icon: const Icon(Icons.add_a_photo_outlined),
                ),
              ],
            ),
            if (items.isEmpty)
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'No photos added yet.',
                  style: TextStyle(color: Colors.grey),
                ),
              )
            else
              SizedBox(
                height: 95,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 10),
                  itemBuilder: (_, i) => Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Image.memory(
                          items[i],
                          width: 95,
                          height: 95,
                          fit: BoxFit.cover,
                        ),
                      ),
                      if (photo != null && onRemove != null)
                        Positioned(
                          right: 2,
                          top: 2,
                          child: InkWell(
                            onTap: onRemove,
                            child: const CircleAvatar(
                              radius: 13,
                              child: Icon(Icons.close, size: 16),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickFacePhoto() async {
    final picked = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
    if (picked == null) return;
    final bytes = await picked.readAsBytes();
    if (!mounted) return;
    setState(() => facePhoto = bytes);
  }

  Future<void> _pickPhotos(List<Uint8List> target) async {
    final picked = await _picker.pickMultiImage(imageQuality: 85);
    if (picked.isEmpty) return;
    final bytes = <Uint8List>[];
    for (final image in picked) {
      bytes.add(await image.readAsBytes());
    }
    if (!mounted) return;
    setState(() => target.addAll(bytes));
  }

  void _save() {
    if (!formKey.currentState!.validate()) {
      return;
    }

    final existing = widget.existing;
    final suspect = Suspect(
      id: existing?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
      name: nameController.text.trim(),
      alias: aliasController.text.trim(),
      dob: dobController.text.trim(),
      idNumber: idController.text.trim(),
      gender: gender,
      phone: phoneController.text.trim(),
      address: addressController.text.trim(),
      description: descriptionController.text.trim(),
      facePhoto: facePhoto,
      tattooPhotos: List<Uint8List>.from(tattooPhotos),
      scarPhotos: List<Uint8List>.from(scarPhotos),
      additionalPhotos: List<Uint8List>.from(additionalPhotos),
    );

    widget.onSave(suspect);

    Navigator.pop(context);
  }
}
// ================================================================
// SUSPECT DETAILS
// ================================================================

class SuspectDetailsPage extends StatelessWidget {
  final Suspect suspect;
  final bool canEdit;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const SuspectDetailsPage({
    super.key,
    required this.suspect,
    this.canEdit = true,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Suspect Details'),
        actions: [
          if (canEdit) ...[
            IconButton(
              tooltip: 'Edit Suspect',
              icon: const Icon(Icons.edit_outlined),
              onPressed: onEdit,
            ),
            IconButton(
              tooltip: 'Delete Suspect',
              icon: const Icon(Icons.delete_outline),
              onPressed: () => _confirmDelete(context),
            ),
          ],
        ],
      ),

      body: SingleChildScrollView(
        padding: const EdgeInsets.all(18),
        child: Column(
          children: [
            // ======================================================
            // PROFILE PHOTO
            // ======================================================
            suspect.facePhoto != null
                ? GestureDetector(
                    onTap: () {
                      _showFullPhoto(context, suspect.facePhoto!);
                    },
                    child: CircleAvatar(
                      radius: 65,
                      backgroundImage: MemoryImage(suspect.facePhoto!),
                    ),
                  )
                : const CircleAvatar(
                    radius: 65,
                    child: Icon(Icons.person, size: 65),
                  ),

            const SizedBox(height: 15),

            // ======================================================
            // NAME
            // ======================================================
            Text(
              suspect.name,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
            ),

            if (suspect.alias.isNotEmpty)
              Text(
                'Alias: ${suspect.alias}',
                style: const TextStyle(color: Colors.grey),
              ),

            const SizedBox(height: 25),

            // ======================================================
            // PERSONAL INFORMATION
            // ======================================================
            _infoCard('Personal Information', [
              _row('Date of Birth', suspect.dob),
              _row('ID / Passport', suspect.idNumber),
              _row('Gender', suspect.gender),
              _row('Phone', suspect.phone),
              _row('Address', suspect.address),
            ]),

            const SizedBox(height: 15),

            // ======================================================
            // PHYSICAL DESCRIPTION
            // ======================================================
            _infoCard('Physical Description', [
              Text(
                suspect.description.isEmpty
                    ? 'No description provided.'
                    : suspect.description,
              ),
            ]),

            const SizedBox(height: 15),

            // ======================================================
            // PHOTO GALLERY
            // ======================================================
            _photoGallery(context),

            const SizedBox(height: 25),

            // ======================================================
            // DELETE BUTTON
            // ======================================================
            SizedBox(
              width: double.infinity,
              height: 50,
              child: OutlinedButton.icon(
                onPressed: () => _confirmDelete(context),
                icon: const Icon(Icons.delete_outline),
                label: const Text('DELETE SUSPECT'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ================================================================
  // INFORMATION CARD
  // ================================================================

  Widget _infoCard(String title, List<Widget> children) {
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 15),

            ...children,
          ],
        ),
      ),
    );
  }

  // ================================================================
  // INFORMATION ROW
  // ================================================================

  Widget _row(String title, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),

          Expanded(child: Text(value.isEmpty ? 'Not provided' : value)),
        ],
      ),
    );
  }

  // ================================================================
  // PHOTO GALLERY
  // ================================================================

  Widget _photoGallery(BuildContext context) {
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Identification Photos',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 15),

            // FACE / FRONT
            _gallerySection(context, 'Face / Front', [
              if (suspect.facePhoto != null) suspect.facePhoto!,
            ]),

            // TATTOOS
            _gallerySection(context, 'Tattoos', suspect.tattooPhotos),

            // SCARS / MARKS
            _gallerySection(context, 'Scars / Marks', suspect.scarPhotos),

            // ADDITIONAL PHOTOS
            _gallerySection(
              context,
              'Additional Photos',
              suspect.additionalPhotos,
            ),
          ],
        ),
      ),
    );
  }

  // ================================================================
  // PHOTO SECTION
  // ================================================================

  Widget _gallerySection(
    BuildContext context,
    String title,
    List<Uint8List> photos,
  ) {
    if (photos.isEmpty) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: Text(
          '$title: No photos',
          style: const TextStyle(color: Colors.grey),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),

          const SizedBox(height: 8),

          SizedBox(
            height: 105,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: photos.length,

              separatorBuilder: (_, __) => const SizedBox(width: 10),

              itemBuilder: (_, i) {
                return GestureDetector(
                  onTap: () {
                    _showFullPhoto(context, photos[i]);
                  },

                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),

                    child: Image.memory(
                      photos[i],
                      width: 105,
                      height: 105,
                      fit: BoxFit.cover,
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // ================================================================
  // FULL SCREEN PHOTO VIEWER
  // ================================================================

  void _showFullPhoto(BuildContext context, Uint8List photo) {
    showDialog(
      context: context,
      barrierColor: Colors.black87,

      builder: (dialogContext) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.all(15),

          child: Stack(
            alignment: Alignment.center,
            children: [
              // ====================================================
              // ZOOMABLE IMAGE
              // ====================================================
              InteractiveViewer(
                minScale: 0.5,
                maxScale: 6.0,
                boundaryMargin: const EdgeInsets.all(40),

                child: Image.memory(photo, fit: BoxFit.contain),
              ),

              // ====================================================
              // CLOSE BUTTON
              // ====================================================
              Positioned(
                top: 5,
                right: 5,
                child: Material(
                  color: Colors.black54,
                  shape: const CircleBorder(),

                  child: IconButton(
                    tooltip: 'Close',

                    onPressed: () {
                      Navigator.pop(dialogContext);
                    },

                    icon: const Icon(
                      Icons.close,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ================================================================
  // DELETE CONFIRMATION
  // ================================================================

  void _confirmDelete(BuildContext context) {
    if (!canEdit) return;

    showDialog(
      context: context,

      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Delete Suspect?'),

          content: Text(
            '${suspect.name} will be removed from the application and unlinked from incidents.',
          ),

          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
              },

              child: const Text('Cancel'),
            ),

            FilledButton(
              onPressed: () {
                Navigator.pop(dialogContext);

                onDelete();
              },

              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
  }
}

// ================================================================
// ADD VEHICLE
// ================================================================

class AddVehiclePage extends StatefulWidget {
  final Vehicle? existing;
  final Function(Vehicle) onSave;

  const AddVehiclePage({super.key, this.existing, required this.onSave});

  @override
  State<AddVehiclePage> createState() => _AddVehiclePageState();
}

class _AddVehiclePageState extends State<AddVehiclePage> {
  final formKey = GlobalKey<FormState>();

  final registrationController = TextEditingController();

  final makeController = TextEditingController();

  final modelController = TextEditingController();

  final colourController = TextEditingController();

  final yearController = TextEditingController();

  final descriptionController = TextEditingController();

  final ImagePicker _picker = ImagePicker();
  final List<Uint8List> photos = [];

  @override
  void initState() {
    super.initState();
    final vehicle = widget.existing;
    if (vehicle != null) {
      registrationController.text = vehicle.registration;
      makeController.text = vehicle.make;
      modelController.text = vehicle.model;
      colourController.text = vehicle.colour;
      yearController.text = vehicle.year;
      descriptionController.text = vehicle.description;
      photos.addAll(vehicle.photos);
    }
  }

  @override
  void dispose() {
    registrationController.dispose();
    makeController.dispose();
    modelController.dispose();
    colourController.dispose();
    yearController.dispose();
    descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.existing == null ? 'Add Vehicle' : 'Edit Vehicle'),
      ),

      body: Form(
        key: formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Vehicle Information',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),

              const SizedBox(height: 15),

              _field(
                registrationController,
                'Registration',
                'Example: ABC123GP',
                Icons.pin_outlined,
                true,
              ),

              _field(
                makeController,
                'Make',
                'Toyota',
                Icons.directions_car_outlined,
                false,
              ),

              _field(
                modelController,
                'Model',
                'Hilux',
                Icons.directions_car_outlined,
                false,
              ),

              _field(
                colourController,
                'Colour',
                'White',
                Icons.palette_outlined,
                false,
              ),

              _field(
                yearController,
                'Year',
                '2024',
                Icons.calendar_today_outlined,
                false,
              ),

              const SizedBox(height: 5),

              TextFormField(
                controller: descriptionController,
                maxLines: 5,
                decoration: const InputDecoration(
                  hintText: 'Additional vehicle information...',
                ),
              ),

              const SizedBox(height: 20),

              const Text(
                'Vehicle Photos',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              _vehiclePhotoPicker(),

              const SizedBox(height: 30),

              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: _save,
                  icon: const Icon(Icons.save),
                  label: Text(
                    widget.existing == null ? 'SAVE VEHICLE' : 'SAVE CHANGES',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _field(
    TextEditingController controller,
    String label,
    String hint,
    IconData icon,
    bool required,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextFormField(
        controller: controller,
        validator: required
            ? (value) {
                if (value == null || value.trim().isEmpty) {
                  return '$label is required';
                }

                return null;
              }
            : null,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          prefixIcon: Icon(icon),
        ),
      ),
    );
  }

  Widget _vehiclePhotoPicker() {
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Add photos of the vehicle, plates, damage, or other details.',
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
                IconButton(
                  onPressed: _pickPhotos,
                  icon: const Icon(Icons.add_a_photo_outlined),
                ),
              ],
            ),
            if (photos.isEmpty)
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'No photos added yet.',
                  style: TextStyle(color: Colors.grey),
                ),
              )
            else
              SizedBox(
                height: 100,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: photos.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 10),
                  itemBuilder: (_, index) => Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Image.memory(
                          photos[index],
                          width: 100,
                          height: 100,
                          fit: BoxFit.cover,
                        ),
                      ),
                      Positioned(
                        right: 3,
                        top: 3,
                        child: InkWell(
                          onTap: () => setState(() => photos.removeAt(index)),
                          child: const CircleAvatar(
                            radius: 13,
                            child: Icon(Icons.close, size: 16),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickPhotos() async {
    final picked = await _picker.pickMultiImage(imageQuality: 85);
    if (picked.isEmpty) return;
    final bytes = <Uint8List>[];
    for (final image in picked) {
      bytes.add(await image.readAsBytes());
    }
    if (!mounted) return;
    setState(() => photos.addAll(bytes));
  }

  void _save() {
    if (!formKey.currentState!.validate()) {
      return;
    }

    final existing = widget.existing;
    final vehicle = Vehicle(
      id: existing?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
      registration: registrationController.text.trim().toUpperCase(),
      make: makeController.text.trim(),
      model: modelController.text.trim(),
      colour: colourController.text.trim(),
      year: yearController.text.trim(),
      description: descriptionController.text.trim(),
      photos: List<Uint8List>.from(photos),
    );

    widget.onSave(vehicle);

    Navigator.pop(context);
  }
}

// ================================================================
// VEHICLE DETAILS
// ================================================================

class VehicleDetailsPage extends StatelessWidget {
  final Vehicle vehicle;
  final bool canEdit;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const VehicleDetailsPage({
    super.key,
    required this.vehicle,
    this.canEdit = true,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Vehicle Details'),
        actions: [
          if (canEdit) ...[
            IconButton(
              tooltip: 'Edit Vehicle',
              icon: const Icon(Icons.edit_outlined),
              onPressed: onEdit,
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (dialogContext) {
                    return AlertDialog(
                      title: const Text('Delete Vehicle?'),
                      content: const Text(
                        'This vehicle will be removed from the application.',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () {
                            Navigator.pop(dialogContext);
                          },
                          child: const Text('Cancel'),
                        ),
                        FilledButton(
                          onPressed: () {
                            Navigator.pop(dialogContext);
                            onDelete();
                          },
                          child: const Text('Delete'),
                        ),
                      ],
                    );
                  },
                );
              },
            ),
          ],
        ],
      ),

      body: SingleChildScrollView(
        padding: const EdgeInsets.all(18),
        child: Column(
          children: [
            const CircleAvatar(
              radius: 50,
              child: Icon(Icons.directions_car, size: 50),
            ),

            const SizedBox(height: 15),

            Text(
              vehicle.registration,
              style: const TextStyle(fontSize: 27, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 5),

            Text(
              '${vehicle.make} ${vehicle.model}',
              style: const TextStyle(color: Colors.grey),
            ),

            const SizedBox(height: 25),

            Card(
              elevation: 0,
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  children: [
                    _row('Registration', vehicle.registration),

                    _row('Make', vehicle.make),

                    _row('Model', vehicle.model),

                    _row('Colour', vehicle.colour),

                    _row('Year', vehicle.year),

                    const Divider(),

                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        vehicle.description.isEmpty
                            ? 'No additional information.'
                            : vehicle.description,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            _vehiclePhotos(context),
          ],
        ),
      ),
    );
  }

  Widget _vehiclePhotos(BuildContext context) {
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Vehicle Photos',
              style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            if (vehicle.photos.isEmpty)
              const Text(
                'No photos attached to this vehicle.',
                style: TextStyle(color: Colors.grey),
              )
            else
              SizedBox(
                height: 120,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: vehicle.photos.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 10),
                  itemBuilder: (_, index) => GestureDetector(
                    onTap: () => showDialog(
                      context: context,
                      builder: (_) => Dialog(
                        child: InteractiveViewer(
                          child: Image.memory(
                            vehicle.photos[index],
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.memory(
                        vehicle.photos[index],
                        width: 120,
                        height: 120,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _row(String title, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 13),
      child: Row(
        children: [
          SizedBox(
            width: 110,
            child: Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),

          Expanded(child: Text(value.isEmpty ? 'Not provided' : value)),
        ],
      ),
    );
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
