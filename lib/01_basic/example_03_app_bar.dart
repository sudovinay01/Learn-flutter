import 'package:flutter/material.dart';

void main() {
  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return appBarExample();
  }

  MaterialApp appBarExample() {
    return MaterialApp(
      // will make the debug banner disappear
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Hello flutter apps!'),
          leading: const Icon(Icons.home),
          actions: <Widget>[
            IconButton(icon: const Icon(Icons.refresh), onPressed: () {}),
          ],
        ),
        body: Center(
          child: Text('Hello Futter!', style: TextStyle(fontSize: 24)),
        ),
      ),
    );
  }
}
