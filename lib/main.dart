import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'circle_of_fifths.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'The Circle of Fifths',
      theme: ThemeData(
        primarySwatch: Colors.deepPurple,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: AppWidget(title: 'Circle of Fifths'),
    );
  }
}

class AppWidget extends StatefulWidget {
  AppWidget({Key key, this.title}) : super(key: key);

  final String title;

  @override
  _AppWidgetState createState() => _AppWidgetState();
}

class _AppWidgetState extends State<AppWidget> {

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.blueGrey[900],
      appBar: AppBar(
        // Here we take the value from the MyHomePage object that was created by
        // the App.build method, and use it to set our appbar title.
        title: Text(widget.title),
      ),
      body: SafeArea(minimum: EdgeInsets.all(64.0),
        child: Center(
          child: CircleOfFifths(),
        ),
      ),
    );
  }
}

