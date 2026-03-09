import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:origna_gta/core/providers.dart';
import 'package:origna_gta/features/qa/qa_repository.dart';
import 'package:origna_gta/features/subscription/subscription_provider.dart';
import 'package:origna_gta/models/qa_model.dart';

final qaControllerProvider = StateNotifierProvider.autoDispose<QAController, AsyncValue<void>>((ref) {
  return QAController(ref.watch(qaRepositoryProvider), ref);
});

final qaListProvider = StreamProvider.autoDispose.family<List<QAModel>, String>((ref, productId) {
  final repo = ref.watch(qaRepositoryProvider);
  return repo.watchQA(productId);
});

/// Streams the count of unanswered Q&A questions for a product. Used for the seller badge.
final unansweredQaCountProvider = StreamProvider.autoDispose.family<int, String>((ref, productId) {
  final repo = ref.watch(qaRepositoryProvider);
  return repo.watchQA(productId).map((list) => list.where((q) => q.answer == null || q.answer!.isEmpty).length);
});

/// Documentation for QAController
class QAController extends StateNotifier<AsyncValue<void>> {
  final QARepository _repository;
  final Ref _ref;

  QAController(this._repository, this._ref) : super(const AsyncValue.data(null));

  Future<void> answerQuestion({required String qaId, required String answer}) async {
    state = const AsyncValue.loading();
    try {
      final userId = _ref.read(userIdProvider);
      if (userId == null) {
        throw Exception('User must be logged in to answer a question');
      }
      await _repository.submitAnswer(qaId, answer);
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> askQuestion(String productId, String question) async {
    state = const AsyncValue.loading();
    try {
      final userId = _ref.read(userIdProvider);
      if (userId == null) {
        throw Exception('User must be logged in to ask a question');
      }

      // Premium gate: use canonical subscription stream state (not user profile cache).
      final subState = _ref.read(subscriptionStreamProvider);
      final isPremium = subState.when(
        data: (sub) => sub?.isPremium ?? false,
        // Default to false — backend is authoritative; show error state rather than silently passing
        loading: () => false,
        error: (error, stackTrace) => false,
      );
      if (!isPremium) {
        throw const PremiumRequiredException(
          'Origna Premium required to ask questions. Upgrade to unlock Q&A, chat with sellers, and more.',
        );
      }

      await _repository.submitQuestion(productId, question);
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}

/// Thrown when a premium-only feature is accessed by a non-premium user.
class PremiumRequiredException implements Exception {
  final String message;
  const PremiumRequiredException(this.message);

  @override
  String toString() => message;
}
