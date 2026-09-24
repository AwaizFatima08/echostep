// Both device suites in one APK, so the slow build runs once:
//   nice -n 19 flutter build apk --debug --target integration_test/all_test.dart
//   flutter drive --driver test_driver/integration_test.dart --target integration_test/all_test.dart \
//     --use-application-binary build/app/outputs/flutter-apk/app-debug.apk -d <device>
// The cloud suite needs the Firebase emulators and adb reverse (see cloud_test.dart).
import 'app_flow_test.dart' as app_flow;
import 'cloud_test.dart' as cloud;

void main() {
  app_flow.main();
  cloud.main();
}
