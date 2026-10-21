import 'package:flutter/material.dart';

void main() {
  // runApp(const MainApp());
  runApp(HelloFlutterApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    // return centerExample();
    // return safeAreaExample();
    return appBarExample();
    // return Container();
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

  MaterialApp safeAreaExample() {
    return MaterialApp(
      home: Scaffold(body: SafeArea(child: Text('Hello World!'))),
    );
  }

  MaterialApp centerExample() {
    return MaterialApp(
      home: Scaffold(body: Center(child: Text('Hello World!'))),
    );
  }
}

class HelloFlutterApp extends StatefulWidget {
  const HelloFlutterApp({super.key});

  @override
  _HelloFlutterAppState createState() => _HelloFlutterAppState();
}

String englishGreeting = "Hello Flutter !";
String spanishGreeting = "Hola Flutter !";

class _HelloFlutterAppState extends State<HelloFlutterApp> {
  //Default greeting is in English language
  String displayText = englishGreeting;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        appBar: AppBar(
          title: Text("Hello Flutter App"),
          leading: Icon(Icons.home),
          actions: <Widget>[
            IconButton(
              icon: Icon(Icons.refresh),
              onPressed: () {
                //Updating greeting language in setState method
                setState(() {
                  displayText = displayText == englishGreeting
                      ? spanishGreeting
                      : englishGreeting;
                });
              },
            ),
          ],
        ),
        body: Center(
          child: Text(
            displayText,
            style: TextStyle(fontSize: 48, fontWeight: FontWeight.bold),
          ),
        ),
      ),
    );
  }
}
