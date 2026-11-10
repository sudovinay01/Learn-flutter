import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

late final String apiKey;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: '.env');

  final configuredApiKey = dotenv.env['API_KEY'];
  if (configuredApiKey == null || configuredApiKey.isEmpty) {
    throw StateError('API_KEY is missing from the .env file.');
  }
  apiKey = configuredApiKey;

  runApp(const MoviesApp());
}

class MoviesApp extends StatelessWidget {
  const MoviesApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: MoviesListing(),
    );
  }
}

class MovieProvider {
  static final String imagerefix = 'https://image.tmdb.org/t/p/w500/';
  static Future<Map> getJson() async {
    final apiEndPoint =
        "http://api.themoviedb.org/3/discover/movie?api_key=$apiKey&sort_by=popularity.desc";
    final apiResponce = await http.get(Uri.parse(apiEndPoint));
    return json.decode(apiResponce.body);
  }
}

class MoviesListing extends StatefulWidget {
  const MoviesListing({super.key});

  @override
  // ignore: library_private_types_in_public_api
  _MoviesListingState createState() => _MoviesListingState();
}

class _MoviesListingState extends State<MoviesListing> {
  //Variable to hold movies information
  // ignore: strict_top_level_inference, prefer_typing_uninitialized_variables
  var movies;
  //Method to fetch movies from network
  // ignore: strict_top_level_inference
  fetchMovies() async {
    //Getting json
    var data = await MovieProvider.getJson();

    setState(() {
      movies = data['results'];
    });
  }

  @override
  Widget build(BuildContext context) {
    //Fetch movies
    fetchMovies();

    return Scaffold(
      //SingleChildScrollView to provide scrolling for flexible data rendering
      body: SafeArea(
        child: SingleChildScrollView(
          //Print API response on screen.
          //RESULT: At this point only text 'instance of Response' will be printed
          child: movies != null
              ? Text("TMDB Api response\n $movies")
              : Text("Loading api response"),
        ),
      ),
    );
  }
}
