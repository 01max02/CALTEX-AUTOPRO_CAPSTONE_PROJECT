// Run once: flutter run -t lib/seed_domains.dart
// This seeds the Firestore domains collection with default values.

import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await seedDomains();
  runApp(const _Done());
}

Future<void> seedDomains() async {
  final db = FirebaseFirestore.instance;

  final seeds = {
    'commodity_groups': ['Lubricants', 'Filters', 'Brakes', 'Tires', 'Electrical', 'Body Parts', 'Fluids', 'Labor'],
    'uom': ['pcs', 'L', 'set', 'job', 'kg', 'box', 'pair', 'm'],
    'vehicle_types': ['Truck', 'SUV', 'Sedan', 'Van', 'Motorcycle', 'Bus', 'Pickup'],
  };

  for (final entry in seeds.entries) {
    final col = db.collection('domains').doc(entry.key).collection('items');
    final existing = await col.limit(1).get();
    if (existing.docs.isNotEmpty) {
      debugPrint('${entry.key}: already seeded, skipping.');
      continue;
    }
    final batch = db.batch();
    for (final name in entry.value) {
      batch.set(col.doc(), {'name': name, 'createdAt': FieldValue.serverTimestamp()});
    }
    await batch.commit();
    debugPrint('${entry.key}: seeded ${entry.value.length} items.');
  }
  debugPrint('Seeding complete.');
}

class _Done extends StatelessWidget {
  const _Done();
  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      home: Scaffold(
        body: Center(
          child: Text('✅ Seeding complete!\nYou can close this.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18)),
        ),
      ),
    );
  }
}
