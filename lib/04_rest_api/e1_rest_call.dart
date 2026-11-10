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

  //NOTE: Method to make http requests
  static dynamic getJson() async {
    //URL to fetch movies information
    final apiEndPoint =
        "https://api.themoviedb.org/3/discover/movie?api_key=$apiKey&sort_by=popularity.desc";
    final apiResponse = await http.get(Uri.parse(apiEndPoint));
    //'Instance of Response'
    return apiResponse;
  }

  //Method to fetch movies from network
  Future<void> fetchMovies() async {
    //Getting json
    var data = await getJson();

    setState(() {
      movies = data;
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
