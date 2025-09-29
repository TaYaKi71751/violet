curl http://localhost:3000/api/v2/docs-yaml -o swaggers/api.yaml
flutter clean
dart run build_runner build