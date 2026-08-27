import 'dart:io';

import 'package:assignment_flood/signIn.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';


class SignUp extends StatefulWidget {
  const SignUp({super.key});

  @override
  State<SignUp> createState() => _SignUpState();


}
//username: minimum 3 characters, letters/numbers/underscore only
//email: valid email format
//password: minimum 8characters, upper, lower, number, special character, no spaces
//all fields cannot be empty

class _SignUpState extends State<SignUp> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  File? _profileImage;
  final picker = ImagePicker();

  Future getImageFromGallery() async{
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);

    if(pickedFile != null){
      setState(() {
        _profileImage = File(pickedFile.path);
      });
    }
  }

  Future<void> savePicture() async {
    if (_profileImage != null) {
      try {
        //save image to specific location
        final appDocDir = await getApplicationDocumentsDirectory();
        final newImagePath = '${appDocDir.path}/profileImage.jpg';
        await _profileImage!.copy(newImagePath);
        print('File image copied successfully to $newImagePath');
      } catch (e) {
        print('File error copying image: $e');
      }
    } else {
      showDialog(
        context: context,
        builder: (context) =>
            AlertDialog(
              title: const Text('Profile Image'),
              content: const SingleChildScrollView(
                child: ListBody(
                  children: <Widget>[
                    Text('Profile Image'),
                    Text('Profile Image file is missing.'),
                  ],
                ),
              ),
              actions: <Widget>[
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  child: const Text('Close'),
                ),
              ],
            ),
      );
    }
  }

  Future<void> loadProfileImage() async {
    // Get the application documents directory
    final appDocDir = await getApplicationDocumentsDirectory();
    final imagePath = '${appDocDir.path}/profileImage.jpg';
    // Create the destination file path
    final file = File(imagePath);
    if (await file.exists()) {
      setState(() {
        _profileImage = file;
        print('File path: $imagePath');
      });
    } else {
      print('File not found in $imagePath');
    }
  }

  Future<void> clearProfileImage() async {
    final appDocDir = await getApplicationDocumentsDirectory();
    final imagePath = '${appDocDir.path}/profileImage.jpg';

    final file = File(imagePath);

    if (await file.exists()) {
      await file.delete();
    }

    setState(() {
      _profileImage = null;
    });
  }

  Future<void> _registerAccount() async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setString(
      'username',
      _usernameController.text.trim(),
    );

    await prefs.setString(
      'email',
      _emailController.text.trim().toLowerCase(),
    );

    await prefs.setString(
      'password',
      _passwordController.text,
    );

    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Account registered successfully'),
      ),
    );

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => const SignIn(),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
  }
  //purpose:
  @override
  void dispose(){
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();//this for what
  }

  String? _validateUsername(String? value){
    final username = value?.trim() ?? '';//use for..?
    if(username.isEmpty){
      return 'Please enter your name';
    }
    if(username.length < 3){
      return 'Username must have at least 3 characters';
    }
    if(!RegExp(r'^[a-zA-Z0-9_]+$').hasMatch(username)){
      return 'Use letters,numbers, and underscore only';
    }
    return null;
  }

  String? _validateEmail(String? value){
    final email = value?.trim() ?? '';//use for..?
    if(email.isEmpty){
      return 'Please enter your email';
    }
    if (!RegExp(
      r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
    ).hasMatch(email)) {
      return 'Please enter a valid email address';
    }
    return null;
  }

  String? _validatePassword(String? value) {
    final password = value ?? '';
    if (password.isEmpty) {
      return 'Please enter your password';
    }
    if (password.length < 8) {
      return 'Password must have at least 8 characters';
    }
    if (!RegExp(r'[A-Z]').hasMatch(password)) {
      return 'Include at least one uppercase letter';
    }
    if (!RegExp(r'[a-z]').hasMatch(password)) {
      return 'Include at least one lowercase letter';
    }
    if (!RegExp(r'[0-9]').hasMatch(password)) {
      return 'Include at least one number';
    }
    if (!RegExp(r'[^a-zA-Z0-9]').hasMatch(password)) {
      return 'Include at least one special character';
    }
    if (password.contains(' ')) {
      return 'Password cannot contain spaces';
    }
    return null;
  }

  String? _validateConfirmPassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please confirm your password';
    }
    if (value != _passwordController.text) {
      return 'Passwords do not match';
    }
    return null;
  }

  //ui

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: (){
              Navigator.pop(context);
            }, 
        ),
        title: const Text('Sign Up Page'),
      ),
      body: Stack(
        fit: StackFit.expand,
        alignment: Alignment.center,
        children: [
          Positioned.fill(
            child: Image.asset(
              'assets/images/signIn.png',
              fit: BoxFit.cover,
            ),
          ),
          Container(
            color: Colors.black.withValues(alpha: 0.2),
          ),
          //sign up form
          Center(
            child: Container(
              width: 335,
              padding: const EdgeInsets.all(24.0),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(25.0),
              ),
              child: Form(
                  key: _formKey,
                  child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Sign Up',
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      TextButton(
                        onPressed: () async {
                          Navigator.pop(context);
                        },
                        child: const Text(
                          'Sign in',
                          style: TextStyle(
                            color: Colors.indigo,
                          ),
                        ),
                      ),
                    ],
                  ),
                  //ui profile
                  _profileImage == null
                      ? Image.asset(
                          'assets/images/profileImageDefault.jpg',
                           width: 150,
                           height: 150,
                  )
                  : Image.file(
                          _profileImage!,
                          width: 150,
                          height: 150,
                  ),
                  const SizedBox(height: 8.0,),
                  IconButton(
                      icon: const Icon(Icons.edit),
                      color: Colors.grey,
                      onPressed: () async{
                       await getImageFromGallery();
                       await savePicture();
                      },
                  ),



                  //username
                  const Text(
                    'Username',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 6),

                  //username field
                  TextFormField(
                    controller: _usernameController,
                    textInputAction: TextInputAction.next,
                    autovalidateMode: AutovalidateMode.onUserInteraction,
                    validator: _validateUsername,
                    decoration: InputDecoration(
                      hintText: 'enter your username',
                      filled: true,
                      fillColor: Colors.grey.shade200,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(30),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),

                  const SizedBox(height: 15),

                  // Email label
                  const Text(
                    'Email',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 6),

                  //email field
                  TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    autovalidateMode: AutovalidateMode.onUserInteraction,
                    validator: _validateEmail,
                    decoration: InputDecoration(
                      hintText: 'enter your email',
                      filled: true,
                      fillColor: Colors.grey.shade200,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(30),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),

                  const SizedBox(height: 15),


                  // Password label
                  const Text(
                    'Password',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  //password field
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    textInputAction: TextInputAction.next,//purpose
                    autovalidateMode: AutovalidateMode.onUserInteraction,
                    validator: _validatePassword,
                    decoration: InputDecoration(
                      hintText: 'enter your password',
                      filled: true,
                      fillColor: Colors.grey.shade200,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(30),
                        borderSide: BorderSide.none,
                      ),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_off
                              : Icons.visibility,
                          color: Colors.grey,
                        ),
                        onPressed: () {
                          setState(() {
                            _obscurePassword = !_obscurePassword;
                          });
                        },
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // confirm password field
                  TextFormField(
                    controller: _confirmPasswordController,
                    validator: _validateConfirmPassword,
                    autovalidateMode: AutovalidateMode.onUserInteraction,
                    obscureText: _obscureConfirmPassword,
                    decoration: InputDecoration(
                      hintText: 'confirm your password',
                      filled: true,
                      fillColor: Colors.grey.shade200,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(30),
                        borderSide: BorderSide.none,
                      ),
                      suffixIcon: IconButton(
                          icon: Icon(
                            _obscureConfirmPassword ? Icons.visibility_off : Icons.visibility,
                            color: Colors.grey,
                          ),
                          onPressed: (){
                            setState(() {
                              _obscureConfirmPassword = !_obscureConfirmPassword;
                            });
                          },
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),


                  //sign up button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () async{
                        if(!_formKey.currentState!.validate()){
                          return;
                        }
                        await _registerAccount();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.indigo.shade900,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                      ),
                      child: const Text(
                        'Sign Up',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          ),
        ],
      ),
    );
  }
}