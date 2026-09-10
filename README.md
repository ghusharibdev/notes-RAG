# Marginal — Fully On-Device RAG Notes App (Flutter)

Upload your notes or PDFs, ask questions, get answers with citations back to the source passage — with the entire pipeline (text extraction, embeddings, retrieval, and generation) running on-device. No server, no API key, no user data ever leaving the phone.

> **Read this before you start building:** this is meaningfully harder than your other apps. You're bundling a language model inside the app itself, which means a bigger download, real on-device performance constraints, and more moving parts than anything on-device-ML-Kit-based you've built so far. Budget real time for it — this is the portfolio piece that's worth the extra effort specifically *because* it's hard.

---

## Features

- **Fully offline chat with your own documents** — no cloud round-trip at any point
- **On-device embeddings + vector retrieval** — real semantic search, not keyword matching
- **Citation-grounded answers** — every answer traces back to a specific passage in a specific document
- **Visible retrieval trace** — shows which passages were retrieved before the model answers, proving (to the user and to anyone watching a demo) that retrieval genuinely happened
- **Zero data leaves the device** — the actual headline feature; say this plainly in the app itself

---

## Tech stack (verified current, September 2026)

The on-device LLM ecosystem in Flutter has consolidated around a modular package family — install only the pieces you need:

| Purpose | Package |
|---|---|
| Core LLM plugin | `flutter_gemma` |
| Inference engine (model runner) | `flutter_gemma_litertlm` — supports `.litertlm` models, works across mobile, desktop, and web, and is the engine that also exposes the embedding backend you need for RAG |
| Vector store for retrieval | `flutter_gemma_rag_sqlite` — uses `sqlite-vec`, works on all platforms (the `qdrant`-backed alternative, `flutter_gemma_rag_qdrant`, is native-only — stick with the sqlite one unless you have a specific reason not to) |
| Embeddings | via `flutter_gemma_litertlm`'s `LiteRtEmbeddingBackend`, typically paired with a small embedding model such as EmbeddingGemma |
| Text extraction from PDFs | `syncfusion_flutter_pdf` (free community license) or a lighter pure-Dart PDF text extractor — evaluate both for extraction quality on your actual test documents before committing |
| State management | `flutter_riverpod` |
| Local document storage | `hive` + `hive_flutter` for metadata; raw files in app documents directory |
| Fonts | `google_fonts` — Bricolage Grotesque + Hanken Grotesk (same pairing as PassPhoto, for a consistent portfolio identity) |

### A real architectural decision to make before you start: bundled model vs. OS-provided model

- **Bundled model (`flutter_gemma_litertlm`)** — you ship a small model (e.g. a Gemma 3 variant in the 270M–1B range for the generation step) inside your app. Works on any supported device, but adds real size to your download and requires the user's device to have enough RAM to run it smoothly.
- **OS-provided model (`flutter_gemma_builtin_ai`)** — uses the device's own built-in model (Gemini Nano via Android AICore, or Apple Foundation Models on iOS 26+/macOS). Much smaller app size since you're not bundling anything, but only works on devices/OS versions that actually have these available — meaning it silently won't work for a meaningful chunk of your potential users/testers.
- **Recommendation for a portfolio app specifically:** go with the bundled `litertlm` approach. It's more work, but it guarantees the demo works on whatever device an interviewer or recruiter actually has, rather than depending on them owning a specific flagship phone with the right OS version. Reliability of the demo matters more here than app size.

---

## Setup

### 1. Prerequisites
- Flutter SDK (stable channel)
- A device or emulator with reasonable specs for testing — on-device LLM inference is genuinely demanding; test on real hardware early, don't wait until the end

### 2. Install dependencies
```bash
flutter pub add flutter_gemma flutter_gemma_litertlm flutter_gemma_rag_sqlite
flutter pub add hive hive_flutter flutter_riverpod google_fonts
flutter pub add syncfusion_flutter_pdf
```

### 3. Choose and download your models
You'll need two model files, both free to obtain (typically from Hugging Face or Google's official model hub — check current licensing terms for whichever specific model you pick, as they vary by model):
- A small generation model in `.litertlm` format (start with the smallest available Gemma variant — you can upgrade later once the pipeline works end to end)
- A small embedding model compatible with `LiteRtEmbeddingBackend` (EmbeddingGemma is the standard current choice)

Bundle these as app assets, or — better for app size — download them on first launch with a clear progress indicator, since bundling multi-hundred-MB files directly in your APK/IPA will bloat your store listing size significantly.

### 4. Run
```bash
flutter run
```

---

## Build sequence

1. **Get text extraction working first, in isolation.** Load a real PDF, extract clean text, verify chunking quality (reasonable chunk size, no mid-sentence cuts) before touching any model code — bad chunking silently ruins retrieval quality later and is much easier to debug now than after the full pipeline exists.
2. **Wire up the embedding model** via `flutter_gemma_litertlm`'s `LiteRtEmbeddingBackend`. Confirm you can generate an embedding vector for a test string and that it runs in reasonable time on your test device.
3. **Wire up `flutter_gemma_rag_sqlite`** as the vector store — index a few test chunks, run a similarity query, confirm the right chunks come back for an obvious test question before moving on.
4. **Wire up the generation model** via `flutter_gemma_litertlm`, first with a hardcoded prompt (no retrieval yet) — confirm generation itself works and is fast enough to be usable before adding retrieval into the loop.
5. **Combine retrieval + generation** into the actual RAG flow: question → embed → retrieve top-k chunks → construct a prompt with those chunks as context → generate → parse citations back to source location.
6. **Build the UI** per `design.md` — the retrieval trace animation should be built against real retrieval data from step 5, not mocked, so you can see actual retrieval latency and design the animation timing around it honestly.
7. **Test end-to-end with real documents you actually care about** — your own class notes are a good test corpus, since you'll immediately notice if an answer is wrong or a citation is off.
8. **Only after the core loop is solid:** add the model-download-on-first-launch flow, settings screen, and polish.

---

## Honest limitations to state in your store listing and README

- Answer quality depends heavily on the small model you choose — don't oversell accuracy; frame this as "a research/study aid," not an infallible assistant.
- Performance varies significantly by device — be upfront that older or budget devices may run the generation step slowly.
- This is not the same output quality as a cloud-hosted large model — the tradeoff is 100% privacy and offline capability in exchange for a smaller, less capable model. Say that tradeoff out loud; it's honest and it's also exactly the interesting engineering story to tell in an interview.

---

## Play Store notes

- Be explicit in the store description about download size and device requirements — this is a case where under-promising avoids bad reviews from users on unsupported hardware.
- This app has more than enough genuine functionality to clear Apple's Guideline 4.2 minimum-functionality bar if you eventually pursue iOS — the on-device RAG pipeline is real, substantial functionality, not a thin wrapper.
