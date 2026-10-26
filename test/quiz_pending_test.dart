import 'package:flutter_test/flutter_test.dart';
import 'package:threeduo_learning/services/exercise_api_service.dart';

import 'test_helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('unfinished quiz', () {
    test('nothing pending at first', () async {
      signIn();
      expect(await ExerciseApiService.hasPendingQuiz('animal'), isFalse);
    });

    test('the same key comes back until the quiz is finished', () async {
      signIn();
      final first = await ExerciseApiService.idempotencyKeyFor('animal');
      expect(await ExerciseApiService.hasPendingQuiz('animal'), isTrue);
      expect(await ExerciseApiService.idempotencyKeyFor('animal'), first);

      await ExerciseApiService.clearPendingQuiz('animal');
      expect(await ExerciseApiService.hasPendingQuiz('animal'), isFalse);
      expect(
        await ExerciseApiService.idempotencyKeyFor('animal'),
        isNot(first),
      );
    });

    test('each category has its own quiz', () async {
      signIn();
      final animal = await ExerciseApiService.idempotencyKeyFor('animal');
      expect(await ExerciseApiService.hasPendingQuiz('fruit'), isFalse);
      final fruit = await ExerciseApiService.idempotencyKeyFor('fruit');
      expect(fruit, isNot(animal));
      await ExerciseApiService.clearPendingQuiz('fruit');
      expect(await ExerciseApiService.hasPendingQuiz('animal'), isTrue);
    });

    test('a quiz left for too long is not offered and gets a new key', () async {
      final old = DateTime.now()
          .subtract(ExerciseApiService.pendingLifetime + const Duration(minutes: 1))
          .millisecondsSinceEpoch;
      signIn(<String, Object>{
        'quiz_pending_animal_user_1': 'old-key|$old',
      });
      expect(await ExerciseApiService.hasPendingQuiz('animal'), isFalse);
      expect(
        await ExerciseApiService.idempotencyKeyFor('animal'),
        isNot('old-key'),
      );
    });

    test('another account does not see it', () async {
      signIn();
      await ExerciseApiService.idempotencyKeyFor('animal');
      signIn(<String, Object>{
        'jwt_token': fakeJwt(<String, Object>{'userId': 2}),
      });
      expect(await ExerciseApiService.hasPendingQuiz('animal'), isFalse);
    });

    test('garbage in storage counts as nothing pending', () async {
      signIn(<String, Object>{'quiz_pending_animal_user_1': 'oops'});
      expect(await ExerciseApiService.hasPendingQuiz('animal'), isFalse);
    });
  });
}
