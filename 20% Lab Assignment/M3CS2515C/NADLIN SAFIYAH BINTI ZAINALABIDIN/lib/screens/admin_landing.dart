import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/auth_service.dart';

class AdminLanding extends StatelessWidget {
  const AdminLanding({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthService>(context);
    final email = auth.currentProfile?.email ?? 'unknown';
    // The real app should read the management URL from config or Firestore.
    const managementUrl = 'https://example.com/admin';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin'),
        actions: [
          IconButton(onPressed: () => auth.signOut(), icon: const Icon(Icons.logout)),
        ],
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Welcome, $email', style: const TextStyle(fontSize: 18)),
              const SizedBox(height: 12),
              const Text('Open the web-based management portal:'),
              const SizedBox(height: 8),
              SelectableText(managementUrl, style: const TextStyle(color: Colors.blue)),
            ],
          ),
        ),
      ),
    );
  }
}
