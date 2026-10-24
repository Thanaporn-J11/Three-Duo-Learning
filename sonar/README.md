# SonarQube for the Flutter app

SonarQube has no built-in Dart support. The community plugin
[sonar-flutter](https://github.com/insideapp-fr/sonar-flutter) (latest release 0.5.2) adds it.
Its page says "compatible with SonarQube 7.9+" but does not list newer versions, so it may or may
not load on the newest server. Try the main server first; if it does not work use the legacy one.

1. Download `sonar-flutter-plugin-0.5.2.jar` from the plugin's GitHub releases page.
2. Put it in the server's plugin folder and restart, for example (main server):
   ```
   docker cp sonar-flutter-plugin-0.5.2.jar <container>:/opt/sonarqube/extensions/plugins/
   docker restart <container>
   ```
   (`docker ps` shows the container name.) Check http://localhost:9000 > Administration >
   Marketplace > Installed: the Flutter plugin should be listed.
   If the server fails to start, see `docker logs <container>`, remove the jar, and use the legacy server
   (`--profile legacy`, port 9001) with the same steps.
3. In SonarQube create the project with key `threeduo-app` and a token.
4. `sonar-scanner` and the Dart SDK must be on PATH (Flutter bundles Dart in `flutter\bin\cache\dart-sdk\bin`).
5. Run `.\sonar\run-app-scan.ps1` (see the header of the script).
6. Report: `python sonar_report.py --host http://localhost:9000 --project threeduo-app --token <user token>`
