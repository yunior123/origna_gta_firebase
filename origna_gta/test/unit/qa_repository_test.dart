import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:origna_gta/core/schema/schema_constants.dart';
import 'package:origna_gta/features/qa/qa_repository.dart';

@GenerateNiceMocks([MockSpec<FirebaseFunctions>(), MockSpec<HttpsCallable>(), MockSpec<HttpsCallableResult>()])
import 'qa_repository_test.mocks.dart';

void main() {
  late FirebaseQARepository repository;
  late FakeFirebaseFirestore fakeFirestore;
  late MockFirebaseFunctions mockFunctions;
  late MockHttpsCallable mockCallable;
  late MockHttpsCallableResult mockResult;

  setUp(() {
    fakeFirestore = FakeFirebaseFirestore();
    mockFunctions = MockFirebaseFunctions();
    mockCallable = MockHttpsCallable();
    mockResult = MockHttpsCallableResult();

    repository = FirebaseQARepository(fakeFirestore, mockFunctions);

    when(mockFunctions.httpsCallable(any)).thenReturn(mockCallable);
    when(mockCallable.call(any)).thenAnswer((_) async => mockResult);
  });

  group('FirebaseQARepository', () {
    test('submitQuestion calls correct cloud function', () async {
      await repository.submitQuestion('p1', 'Is this available?');

      verify(mockFunctions.httpsCallable(CloudFunctionEndpoints.askProductQuestion)).called(1);
      verify(mockCallable.call({Fields.productId: 'p1', Fields.questionText: 'Is this available?'})).called(1);
    });

    test('submitAnswer calls correct cloud function', () async {
      await repository.submitAnswer('qa1', 'Yes');

      verify(mockFunctions.httpsCallable(CloudFunctionEndpoints.answerProductQuestion)).called(1);
      verify(mockCallable.call({Fields.questionId: 'qa1', Fields.answerText: 'Yes'})).called(1);
    });

    test('watchQA returns stream of QAModel', () async {
      await fakeFirestore.collection(Collections.productQuestions).add({
        Fields.productId: 'p1',
        Fields.questionText: 'Q1',
        Fields.createdAt: Timestamp.now(),
        Fields.askerId: 'u1',
        Fields.isAnswered: false,
      });

      final stream = repository.watchQA('p1');
      final questions = await stream.first;
      expect(questions.length, 1);
      expect(questions.first.question, 'Q1');
    });
  });
}
