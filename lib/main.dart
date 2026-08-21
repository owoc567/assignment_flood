import 'package:flutter/material.dart';
import 'signin.dart';
void main() {
  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: Center(
          child: Stack(
            alignment: Alignment.center,
            children: [

              Image.asset(
                'assets/images/Mobile Wallpaper.png',
                fit: BoxFit.cover,
              ),

              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [

                  const SizedBox(
                    height: 20,
                  ),

                  const SizedBox(
                    height: 10,
                  ),


                  // Take up empty screen space
                  const Expanded(
                    child: SizedBox(),
                  ),

                  // Get Started button
                  ElevatedButton(
                    onPressed: () {
                      Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (context)=> const SignIn(),
                          ),
                      );
                    },
                    child: const Text('Get Started'),
                  ),

                  const SizedBox(
                    height: 30,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}