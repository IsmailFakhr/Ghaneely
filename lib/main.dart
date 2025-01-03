import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import 'ArtistSearchScreen.dart';

const String clientId = 'ebd43e8a6ea744019a931a1218658070';
const String clientSecret = 'cefb61a6dbb443ae9e162b95dcc0b425';

void main() => runApp(MyApp());

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: ArtistSearchScreen(),
    );
  }
}