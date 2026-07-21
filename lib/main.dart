import 'package:flutter/material.dart';

void main() {
  runApp(const ShowTimeApp());
}

class ShowTimeApp extends StatelessWidget {
  const ShowTimeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SIGNAL FLOW Show Time',
      debugShowCheckedModeBanner: false,
      home: const ShowTimeScreen(),
    );
  }
}

class ShowTimeScreen extends StatelessWidget {
  const ShowTimeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,

      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,

            children: [

              const Text(
                "SIGNAL FLOW",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 3,
                ),
              ),

              const SizedBox(height: 60),

              const Text(
                "CURRENT TIME",
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 18,
                ),
              ),

              const SizedBox(height: 16),

              const Text(
                "10:26:15",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 56,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 70),

              const Text(
                "SHOW TIME",
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 18,
                ),
              ),

              const SizedBox(height: 16),

              const Text(
                "00:00:00",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 56,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 80),

              SizedBox(
                width: 220,
                height: 60,
                child: ElevatedButton(

                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                  ),

                  onPressed: () {},

                  child: const Text(
                    "START",
                    style: TextStyle(
                      fontSize: 24,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}