import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class FirebaseTest extends StatefulWidget {
  const FirebaseTest({super.key});
  @override
  State<FirebaseTest> createState() => _FirebaseTestState();
}

class _FirebaseTestState extends State<FirebaseTest> {
  String result = "Testing Firebase...";

  @override
  void initState() {
    super.initState();
    _checkFirebase();
  }

  Future<void> _checkFirebase() async {
    try {
      await FirebaseAuth.instance.signInAnonymously();
      final doc = await FirebaseFirestore.instance.collection('test').add({
        'connected': true,
        'time': DateTime.now().toIso8601String(),
      });
      setState(() {
        result = "✅ Firebase works! Doc ID: ${doc.id}";
      });
    } catch (e) {
      setState(() {
        result = "❌ Error: $e";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Firebase Test")),
      body: Center(child: Text(result, textAlign: TextAlign.center)),
    );
  }
}
