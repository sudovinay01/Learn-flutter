import 'package:flutter/material.dart';

void main() => runApp(ContactProfileApp());

class ContactProfileApp extends StatelessWidget {
  const ContactProfileApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.blue,
          // leading is used to display a widget before the title in the AppBar
          leading: Icon(Icons.arrow_back, color: Colors.white),
          // actions is used to display a list of widgets after the title in the AppBar
          actions: [
            IconButton(
              icon: Icon(Icons.star_border),
              color: Colors.white,
              onPressed: () {
                // ignore: avoid_print
                print("Contact is starred");
              },
            ),
          ],
        ),
        body: ListView(
          children: <Widget>[
            Column(
              children: <Widget>[
                // ignore: sized_box_for_whitespace
                Container(
                  width: double.infinity,
                  child: Image.network(
                    "https://sudovinay01.github.io/images/profile.jpg",
                    height: 250,
                    fit: BoxFit.cover,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
