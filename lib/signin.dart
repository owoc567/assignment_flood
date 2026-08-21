import 'package:flutter/material.dart';

class SignIn extends StatelessWidget {
  const SignIn({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        alignment: Alignment.center,
        children: [

          Image.asset(
            'assets/images/Mobile Wallpaper.png',
            fit: BoxFit.cover,
          ),

          Container(
            color: Colors.black.withOpacity(0.2),
          ),

          Center(
            child: Container(
              width: 335,
              padding: const EdgeInsets.all(24.0),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(25.0),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [

                      const Text(
                        'Sign in',
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                        ),
                      ),

                      TextButton(
                        onPressed: () {},
                        child: const Text('Signup'),
                      ),

                    ],
                  ),

                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Sign in to your user account',
                    ),
                  ),

                  const SizedBox(
                    height: 20,
                  ),

                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Email',
                    ),
                  ),

                  TextField(
                    decoration: InputDecoration(
                      hintText: 'enter your email',
                    ),
                  ),

                  const SizedBox(
                    height: 15,
                  ),

                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Password',
                    ),
                  ),

                  TextField(
                    obscureText: true,
                    decoration: InputDecoration(
                      hintText: 'enter your password',
                    ),
                  ),

                  const SizedBox(
                    height: 20,
                  ),

                  ElevatedButton(
                    onPressed: () {},
                    child: const Text('Sign in'),
                  ),

                ],
              ),
            ),
          ),

        ],
      ),
    );
  }
}