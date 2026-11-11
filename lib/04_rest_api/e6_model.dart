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
  static final String imagePathPrefix = 'https://image.tmdb.org/t/p/w500/';
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
              child: MovieTile(movies, index),
            );
          },
        ),
      ),
    );
  }
}

class MovieTile extends StatelessWidget {
  final List<MovieModel> movies;
  // ignore: strict_top_level_inference, prefer_typing_uninitialized_variables
  final index;

  const MovieTile(this.movies, this.index, {super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Column(
        children: <Widget>[
          // ignore: unnecessary_null_comparison, dead_code
          movies[index].poster_path != null
              ?
                // ignore: sized_box_for_whitespace
                Container(
                  width: MediaQuery.of(context).size.width / 2,
                  height: MediaQuery.of(context).size.width / 4,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10.0),
                    color: Colors.grey,
                    image: DecorationImage(
                      image: NetworkImage(
                        MovieProvider.imagePathPrefix +
                            movies[index].poster_path,
                      ),
                      fit: BoxFit.cover,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey,
                        blurRadius: 3.0,
                        offset: Offset(1.0, 3.0),
                      ),
                    ],
                  ),
                )
              // ignore: dead_code
              : Container(),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Text(
              movies[index].title,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w600,
                color: Colors.black,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Text(movies[index].overview),
          ),
          Divider(color: Colors.grey.shade500),
        ],
      ),
    );
  }
}
