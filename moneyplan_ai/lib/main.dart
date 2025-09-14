import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'firebase_options.dart';
import 'home.dart';
import 'login.dart';
import 'signup.dart';
import 'chatbot.dart';
import 'nlpAssistant.dart';

// Gemini API key for the chatbot and NLP assistant
const String geminiApiKey = 'AIzaSyCNILt291xSTnaU9yz3iblFF8mCIjzPF6M';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
  // No need for explicit initialization of GenerativeModel
  
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'MoneyPlanAI',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      initialRoute: '/login',
      routes: {
        '/signup': (context) => const SignupScreen(),
        '/login': (context) => const LoginScreen(),
        '/home': (context) => const HomeScreen(),
        '/chatbot': (context) => const ChatbotScreen(),
        '/nlpAssistant': (context) => const NLPAssistantScreen(),
      },
    );
  }
}
