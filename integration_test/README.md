# End-to-end tests (integration_test)

These tests drive the real app on an emulator or phone against a **running
backend** and use throw-away accounts (`e2e_<time>@example.com`), which they
delete again when they finish.

## Before you run
1. Start the backend (`cd C:\Projects\threeduo_backend; npm start`) with the
   latest code (it needs the `/api/profile/delete-account` route).
2. Start the Android emulator (it reaches the backend at `10.0.2.2:3000`, the
   app's default; for a real phone add
   `--dart-define=API_BASE_URL=http://<pc-ip>:3000`).
3. `flutter pub get` (the first time, to fetch `integration_test`).

## Run
```powershell
cd C:\Projects\three_duo_learning
flutter test integration_test                          # all flows
flutter test integration_test\auth_flow_test.dart      # one flow
flutter devices                                        # if more than one device: add -d <id>
```

## What is covered
| File | Flows |
|---|---|
| `auth_flow_test.dart` | register, wrong password, login, logout, login again, delete account (wrong then right password), deleted account cannot log in |
| `games_and_pin_test.dart` | home areas open, all 10 games open and close, parent PIN creation (mismatch rejected, match saved) |

Not automated (do these by hand, see the manual test sheet): sound/microphone,
OTP by email, gameplay answers (questions are random), layout on many screens.
