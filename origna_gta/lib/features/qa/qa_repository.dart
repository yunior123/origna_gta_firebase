import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:origna_gta/core/providers.dart';
import 'package:origna_gta/core/schema/schema_constants.dart';
import 'package:origna_gta/models/qa_model.dart';

final qaRepositoryProvider = Provider<QARepository>((ref) {
  return FirebaseQARepository(ref.watch(firestoreProvider), ref.watch(firebaseFunctionsProvider));
});

/// Documentation for FirebaseQARepository
class FirebaseQARepository implements QARepository {
  final FirebaseFirestore _firestore;
  final FirebaseFunctions _functions;

  FirebaseQARepository(this._firestore, this._functions);

  @override
  Future<void> submitAnswer(String qaId, String answer) async {
    await _functions.httpsCallable(CloudFunctionEndpoints.answerProductQuestion).call({
      Fields.questionId: qaId,
      Fields.answerText: answer.trim(),
    });
  }

  @override
  Future<void> submitQuestion(String productId, String question) async {
    await _functions.httpsCallable(CloudFunctionEndpoints.askProductQuestion).call({
      Fields.productId: productId,
      Fields.questionText: question.trim(),
    });
  }

  @override
  Stream<List<QAModel>> watchQA(String productId) {
    return _firestore
        .collection(Collections.productQuestions)
        .where(Fields.productId, isEqualTo: productId)
        .orderBy(Fields.createdAt, descending: true)
        .limit(10)
        .snapshots()
        .map((snapshot) {
          if (snapshot.docs.isEmpty) return [];
          return snapshot.docs
              .map((doc) => QAModel.fromMap(doc.id, doc.data()))
              .toList();
        });
  }
}

abstract class QARepository {
  Future<void> submitAnswer(String qaId, String answer);
  Future<void> submitQuestion(String productId, String question);
  Stream<List<QAModel>> watchQA(String productId);
}
