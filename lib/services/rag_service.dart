import '../models/chat_message.dart';
import 'gemma_service.dart';
import 'package:flutter_gemma/flutter_gemma.dart' show RetrievalResult;

class RagService {
  final GemmaService _gemma;

  /// Chunks below this cosine similarity are discarded. MiniLM similarities
  /// for genuinely relevant prose typically land above ~0.30; keeping weak
  /// hits was filling the context with noise and pushing the real evidence
  /// out of the model's window.
  static const double _relevanceThreshold = 0.25;

  /// Hard cap on context characters sent to the model (~700 tokens), so the
  /// prompt can never crowd out the question or the answer budget.
  static const int _maxContextChars = 2800;

  RagService(this._gemma);

  Future<RagResult> query(String question, {List<ChatMessage> history = const []}) async {
    final searchResults = await _retrieve(question);

    final contextChunks = <String>[];
    final keptResults = <RetrievalResult>[];
    var usedChars = 0;
    for (final h in searchResults) {
      if (usedChars + h.content.length > _maxContextChars) break;
      contextChunks.add(h.content);
      keptResults.add(h);
      usedChars += h.content.length;
    }

    // Citations must match the sources the model actually saw — chunks cut
    // by the character cap never made it into the prompt.
    final citations = _buildCitations(keptResults);

    final answer = await _gemma.generateResponse(
      question: question,
      contextChunks: contextChunks,
      historyTurns: _historyTurns(history),
    );

    final parsedCitations = _parseCitations(answer, citations);

    return RagResult(
      answer: answer,
      citations: parsedCitations,
      retrievedChunks: contextChunks,
    );
  }

  /// Retrieves with a dense hit plus keyword-supplemented queries.
  ///
  /// Short questions like "which skills are mentioned" embed poorly on their
  /// own, so we union results from a couple of expanded variants. Each query
  /// is embedded with the [EmbeddingTaskType.query] prefix by the service.
  Future<List<RetrievalResult>> _retrieve(String question) async {
    final queries = <String>[
      question,
      'Information about: $question',
      '$question details, examples, and lists',
    ];

    final seen = <String>{};
    final merged = <RetrievalResult>[];

    for (final q in queries) {
      final hits = await _gemma.searchSimilar(
        query: q,
        topK: 5,
        threshold: _relevanceThreshold,
      );
      for (final h in hits) {
        if (seen.add(h.id)) {
          merged.add(h);
        }
      }
      if (merged.length >= 8) break;
    }

    // Best-first ordering by similarity so the strongest evidence is always
    // inside the character budget.
    merged.sort((a, b) => b.similarity.compareTo(a.similarity));
    return merged.take(6).toList();
  }

  List<String> _historyTurns(List<ChatMessage> history) {
    final turns = <String>[];
    final recent = history
        .where((m) => !m.isStreaming && m.content.trim().isNotEmpty)
        .toList();
    final start = recent.length > 4 ? recent.length - 4 : 0;
    for (final m in recent.sublist(start)) {
      final who = m.role == MessageRole.user ? 'User' : 'Assistant';
      turns.add('$who: ${m.content.trim()}');
    }
    return turns;
  }

  List<Citation> _buildCitations(List<RetrievalResult> results) {
    final byDocPage = <String, Citation>{};

    for (final h in results) {
      final meta = h.metadata;
      String docName = 'Unknown document';
      int page = 0;

      if (meta != null) {
        final docNameMatch = RegExp(r'"docName"\s*:\s*"([^"]+)"').firstMatch(meta);
        if (docNameMatch != null) {
          docName = docNameMatch.group(1) ?? docName;
        }
        final docIdMatch = RegExp(r'"documentId"\s*:\s*"([^"]+)"').firstMatch(meta);
        if (docNameMatch == null && docIdMatch != null) {
          docName = docIdMatch.group(1) ?? docName;
        }
        final pageMatch = RegExp(r'"page"\s*:\s*(\d+)').firstMatch(meta);
        if (pageMatch != null) {
          page = int.tryParse(pageMatch.group(1) ?? '0') ?? 0;
        }
      }

      final key = '$docName#$page';
      final passage = h.content.length > 200
          ? '${h.content.substring(0, 200)}...'
          : h.content;

      // Chunks from the same page collapse into one citation chip.
      byDocPage.putIfAbsent(key, () => Citation(
            documentName: docName,
            page: page,
            passage: passage,
          ));
    }

    return byDocPage.values.toList();
  }

  List<Citation> _parseCitations(String answer, List<Citation> rawCitations) {
    final citedIndices = <int>{};
    final sourcePattern = RegExp(r'\[Source (\d+)\]');
    for (final match in sourcePattern.allMatches(answer)) {
      final idx = int.tryParse(match.group(1) ?? '');
      if (idx != null && idx >= 1 && idx <= rawCitations.length) {
        citedIndices.add(idx - 1);
      }
    }

    if (citedIndices.isEmpty) return rawCitations;
    return citedIndices.map((i) => rawCitations[i]).toList();
  }
}

class RagResult {
  final String answer;
  final List<Citation> citations;
  final List<String> retrievedChunks;

  RagResult({
    required this.answer,
    required this.citations,
    required this.retrievedChunks,
  });
}
