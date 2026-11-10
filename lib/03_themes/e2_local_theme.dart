import 'package:flutter/material.dart';

void main() => runApp(ContactProfileApp());

class ContactProfileApp extends StatelessWidget {
  const ContactProfileApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.light,
        appBarTheme: AppBarTheme(
          // ignore: deprecated_member_use
          color: Colors.white,
          iconTheme: IconThemeData(color: Colors.black),
        ),
        iconTheme: IconThemeData(color: Colors.indigo.shade800),
      ),
      home: Scaffold(
        appBar: AppBar(
          // leading is used to display a widget before the title in the AppBar
          leading: Icon(Icons.arrow_back),
          // actions is used to display a list of widgets after the title in the AppBar
          actions: [
            IconButton(
              icon: Icon(Icons.star_border),
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
                SizedBox(
                  height: 60,
                  child: Row(
                    // mainAxisAlignment is used to align the children of a Row or Column
                    // mainAxisAlignment: MainAxisAlignment.start, // for rows mainAxisAlignment is aligned MainAxisAlignment.start
                    children: <Widget>[
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Text(
                          "Kakashi Uchiha",
                          style: TextStyle(fontSize: 30),
                        ),
                      ),
                    ],
                  ),
                ),
                Divider(color: Colors.grey),
                Container(
                  margin: const EdgeInsets.only(top: 8, bottom: 8),
                  child: Theme(
                    data: ThemeData(
                      iconTheme: IconThemeData(color: Colors.lightBlue),
                    ),
                    child: profileActionItems(),
                  ),
                ),
                Divider(color: Colors.grey),
                mobilePhoneListTile(),
                otherPhoneListTile(),
                Divider(color: Colors.grey),
                emailListTile(),
                Divider(color: Colors.grey),
                addressListTile(),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget profileActionItems() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: <Widget>[
        buildCallButton(),
        buildTextButton(),
        buildVideoCallButton(),
        buildEmailButton(),
        buildDirectionsButton(),
        buildPayButton(),
      ],
    );
  }
}

Widget buildCallButton() {
  return Column(
    children: <Widget>[
      IconButton(icon: Icon(Icons.call), onPressed: () {}),
      Text("Call"),
    ],
  );
}

Widget buildTextButton() {
  return Column(
    children: <Widget>[
      IconButton(icon: Icon(Icons.message), onPressed: () {}),
      Text("Text"),
    ],
  );
}

Widget buildVideoCallButton() {
  return Column(
    children: <Widget>[
      IconButton(icon: Icon(Icons.video_call), onPressed: () {}),
      Text("Video"),
    ],
  );
}

Widget buildEmailButton() {
  return Column(
    children: <Widget>[
      IconButton(icon: Icon(Icons.email), onPressed: () {}),
      Text("Email"),
    ],
  );
}

Widget buildDirectionsButton() {
  return Column(
    children: <Widget>[
      IconButton(icon: Icon(Icons.directions), onPressed: () {}),
      Text("Directions"),
    ],
  );
}

Widget buildPayButton() {
  return Column(
    children: <Widget>[
      IconButton(icon: Icon(Icons.attach_money), onPressed: () {}),
      Text("Pay"),
    ],
  );
}

Widget mobilePhoneListTile() {
  return ListTile(
    leading: Icon(Icons.call),
    title: Text("330-803-3390"),
    subtitle: Text("mobile"),
    trailing: IconButton(onPressed: () {}, icon: Icon(Icons.message)),
  );
}

Widget otherPhoneListTile() {
  return ListTile(
    leading: Text(""),
    title: Text("440-440-3390"),
    subtitle: Text("other"),
    trailing: IconButton(onPressed: () {}, icon: Icon(Icons.message)),
  );
}

Widget emailListTile() {
  return ListTile(
    leading: Icon(Icons.email),
    title: Text("kakashi@uchiha.com"),
    subtitle: Text("work"),
  );
}

Widget addressListTile() {
  return ListTile(
    leading: Icon(Icons.location_on),
    title: Text("Konoha"),
    subtitle: Text("home"),
    trailing: IconButton(onPressed: () {}, icon: Icon(Icons.directions)),
  );
}
