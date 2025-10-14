import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'home.dart';
import 'login.dart';
import 'signup.dart';
import 'chatbot.dart';
import 'nlpAssistant.dart';
import 'profile_page.dart';
import 'incomedata.dart';
import 'screens/cibil_credit_score_screen.dart';
import 'screens/loan_eligibility_screen.dart';
import 'screens/investment_portfolio_page.dart';
import 'screens/retirement_planning_page.dart';
import 'screens/emi_calculator_screen.dart';

// Gemini API key for the chatbot and NLP assistant
const String geminiApiKey = 'AIzaSyCNILt291xSTnaU9yz3iblFF8mCIjzPF6M';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
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
        '/profile': (context) => const ProfilePage(),
        '/chatbot': (context) => const ChatbotScreen(),
        '/nlpAssistant': (context) => const NLPAssistantScreen(),
        '/incomeData': (context) => const IncomeDataPage(),
        '/cibil': (context) => const CibilCreditScoreScreen(),
        '/loan': (context) => const LoanEligibilityScreen(),
        '/retirement': (context) => const RetirementPlanningPage(),
        '/investment': (context) => const InvestmentPortfolioPage(),
        '/emi': (context) => const EmiCalculatorScreen(),
      },
    );
  }
}
