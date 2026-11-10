# flutter_application_1

A new Flutter project.

## REST API example

The REST API example reads its TMDB API key from `.env`. Copy `.env.example` to
`.env` in the project root and set `API_KEY` to your key before running:

```sh
flutter run -t lib/04_rest_api/e1_rest_call.dart
```

The `.env` file is included as a Flutter asset at build time, so it avoids
committing the key to source control but does not keep the key secret in a
distributed app.
