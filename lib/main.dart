import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'database.dart';
import 'home_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(); // 讀取 android/app/google-services.json 裡的設定
  await AppDatabase.instance.init();
  runApp(const BudgetApp());
}

class BudgetApp extends StatelessWidget {
  const BudgetApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '記帳工具',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF2E7D9F), brightness: Brightness.light),
        useMaterial3: true,
      ),
      home: const HomePage(),
    );
  }
}