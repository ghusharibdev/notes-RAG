import '../models/chat_message.dart';
import 'gemma_service.dart';

class RagService {
  final GemmaService _gemma;

  RagService(this._gemma);

  Future<RagResult> query(String question) async {
    final searchResults = await _gemma.searchSimilar(
      query: question,
      topK: 5,
    );

    final contextChunks = searchResults.map((h) => h.content).toList();

    final citations = searchResults.map((h) {
      final meta = h.metadata;
      String docName = 'Unknown document';
      int page = 0;

      if (meta != null) {
        final docIdMatch = RegExp(r'"documentId"\s*:\s*"([^"]+)"').firstMatch(meta);
        if (docIdMatch != null) {
          docName = docIdMatch.group(1) ?? docName;
        }
        final pageMatch = RegExp(r'"page"\s*:\s*(\d+)').firstMatch(meta);
        if (pageMatch != null) {
          page = int.tryParse(pageMatch.group(1) ?? '0') ?? 0;
        }
      }

      return Citation(
        documentName: docName,
        page: page,
        passage: h.content.length > 200
            ? '${h.content.substring(0, 200)}...'
            : h.content,
      );
    }).toList();

    final answer = await _gemma.generateResponse(
      question: question,
      contextChunks: contextChunks,
    );

    final parsedCitations = _parseCitations(answer, citations);

    return RagResult(
      answer: answer,
      citations: parsedCitations,
      retrievedChunks: contextChunks,
    );
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
