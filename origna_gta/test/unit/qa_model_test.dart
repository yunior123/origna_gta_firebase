import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:origna_gta/core/schema/schema_constants.dart';
import 'package:origna_gta/models/qa_model.dart';

void main() {
  group('QAModel serialization', () {
    test('fromMap parses question correctly', () {
      final now = Timestamp.now();
      final map = {Fields.questionText: 'What is the color?', Fields.askerId: 'user1', Fields.createdAt: now};

      final model = QAModel.fromMap('doc1', map);
      expect(model.id, 'doc1');
      expect(model.question, 'What is the color?');
      expect(model.authorId, 'user1');
      expect(model.createdAt, now.toDate());
      expect(model.answer, isNull);
      expect(model.answeredAt, isNull);
      expect(model.answeredBy, isNull);
    });

    test('fromMap parses fully answered question correctly', () {
      final askTime = Timestamp.fromDate(DateTime(2023, 1, 1));
      final ansTime = Timestamp.fromDate(DateTime(2023, 1, 2));

      final map = {
        Fields.questionText: 'Is this large?',
        Fields.askerId: 'buyer1',
        Fields.createdAt: askTime,
        Fields.answerText: 'Yes, it is large.',
        Fields.answeredAt: ansTime,
        Fields.answeredBy: 'seller1',
      };

      final model = QAModel.fromMap('doc2', map);
      expect(model.answer, 'Yes, it is large.');
      expect(model.answeredAt, ansTime.toDate());
      expect(model.answeredBy, 'seller1');
    });

    test('toMap writes basic fields', () {
      final model = QAModel(id: 'doc3', question: 'How heavy?', authorId: 'user3', createdAt: DateTime(2023, 5, 5));

      final map = model.toMap();
      expect(map[Fields.questionText], 'How heavy?');
      expect(map[Fields.askerId], 'user3');
      expect(map[Fields.createdAt], isA<FieldValue>());
      expect(map.containsKey(Fields.answerText), false);
    });

    test('toMap writes answer fields when present', () {
      final model = QAModel(
        id: 'doc4',
        question: 'Q',
        authorId: 'A',
        createdAt: DateTime.now(),
        answer: 'Ans',
        answeredAt: DateTime(2023, 5, 6),
        answeredBy: 'B',
      );

      final map = model.toMap();
      expect(map[Fields.answerText], 'Ans');
      expect(map[Fields.answeredBy], 'B');
      expect(map[Fields.answeredAt], isA<Timestamp>());
      final timestamp = map[Fields.answeredAt] as Timestamp;
      expect(timestamp.toDate(), DateTime(2023, 5, 6));
    });
  });
}
