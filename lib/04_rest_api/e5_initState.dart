// ignore_for_file: non_constant_identifier_names

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

class MovieModel {
  //Class fields for mapping to JSON properties
  final int id;
  final num popularity;
  final int vote_count;
  final bool video;
  final String poster_path;
  final String backdrop_path;
  final bool adult;
  final String original_language;
  final String original_title;
  final List<dynamic> genre_ids;
  final String title;
  final num vote_average;
  final String overview;
  final String release_date;

  //Takes JSON formatted map, and returns `MovieModel` object.
  MovieModel.fromJson(Map<String, dynamic> json)
    : id = json['id'],
      popularity = json['popularity'],
      vote_count = json['vote_count'],
      video = json['video'],
      poster_path = json['poster_path'],
      adult = json['adult'],
      original_language = json['original_language'],
      original_title = json['original_title'],
      genre_ids = json['genre_ids'],
      title = json['title'],
      vote_average = json['vote_average'],
      overview = json['overview'],
      release_date = json['release_date'],
      backdrop_path = json['backdrop_path'];
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
  List<MovieModel> movies = [];
  //Method to fetch movies from network
  // ignore: strict_top_level_inference
  fetchMovies() async {
    //Getting json
    var data = await MovieProvider.getJson();

    setState(() {
      List<dynamic> result = data['results'];
      for (var element in result) {
        movies.add(MovieModel.fromJson(element));
      }
    });
  }

  @override
  void initState() {
    super.initState();
    //Fetch movies
    fetchMovies();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      //SingleChildScrollView to provide scrolling for flexible data rendering
      body: SafeArea(
        child: ListView.builder(
          itemCount: movies.length,
          itemBuilder: (context, index) {
            return Padding(
              padding: const EdgeInsets.all(8.0),
              child: Text(movies[index].title),
            );
          },
        ),
      ),
    );
  }
}
