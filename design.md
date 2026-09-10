# Design Document — Marginal (On-Device RAG Notes App)

## 1. Concept

A fully offline "chat with your own documents" app. The user uploads notes or PDFs, the app extracts and chunks the text, generates embeddings and runs retrieval entirely on-device, and a small local LLM answers questions with citations back to the source passage — no server, no API key, no upload of the user's data anywhere.

**Why this is worth building despite the complexity:** almost no portfolio apps attempt genuine on-device RAG. It's the one project on your list that makes an interviewer stop and ask "wait, how did you do the retrieval on-device?" — that question is the entire point of building it.

**Be upfront in the store listing about the real tradeoff:** the app bundles a small language model, so it's a larger download (several hundred MB, depending on model choice) and performs best on a phone from the last ~3 years. This isn't a flaw to hide — stating it plainly is more credible than pretending it away.

---

## 2. Design plan

### Typography — two families, distinct roles

- **Display / headlines:** Bricolage Grotesque — the same distinctive variable grotesk used in PassPhoto, carried over here for a consistent family identity across your app portfolio. Used for screen titles, the app name lockup, and the "answer" moment in chat.
- **Body / UI:** Hanken Grotesk — clean, geometric, highly legible at small sizes, used for everything else: body copy, input field, citations, settings.
- Type scale (mobile-first, base 16px): Display (Bricolage) 28/34, H1 (Bricolage) 22/28, H2 (Hanken) 18/24, Body (Hanken) 16/24, Caption (Hanken) 13/18.
- Citations and source-passage excerpts render in Body (Hanken), italicized, with a thin left border rather than a quote-block background — keeps the "sourced from your own text" feeling literal and quiet, not decorated.
- Note on shared identity across your apps: reusing this pairing is intentional, not an oversight — a consistent font system across your portfolio reads as a deliberate design language when reviewed together, rather than three unrelated apps. The color palette and layout below still differ enough per app that they don't feel like reskins of each other.

### Color — grounded in "thought" and "citation," not generic chat-app blue

| Token | Hex | Role |
|---|---|---|
| `stone` | `#F3F2EE` | Base background — cool, quiet neutral, appropriate for a reading-focused app |
| `ink` | `#1E1B16` | Primary text |
| `plum` | `#5B4B8A` | Primary accent — used for the "thinking/retrieving" state and primary actions; deliberately not blue, avoids reading as a generic AI-chatbot clone |
| `ochre` | `#C98A3B` | Citation/source-highlight accent — used only to mark which passage in the original document an answer was drawn from |
| `moss` | `#5E7A5A` | Success/confirmation accent — document indexed, answer verified against source |

Avoid: the now-ubiquitous chat-app gradient bubble aesthetic, purple-to-blue AI gradients, generic "thinking dots" spinners without a functional purpose.

### Signature visual device: the retrieval trace

Rather than hiding retrieval behind a generic "thinking..." spinner, show it: when the user asks a question, a brief animated sequence displays which source chunks are being retrieved (small passage previews sliding in from the relevant document, converging toward the answer). This is both the app's visual signature and its actual technical proof — it's showing the user (and any interviewer watching a demo) that retrieval genuinely happened before generation.

### Layout concept

```
+-------------------------------+
|  Marginal                      |  <- Bricolage Grotesque, Display
|  3 documents indexed            |  <- quiet status line
|                                |
|  [ + Add document ]             |  <- secondary button, top
|                                |
|  Ask a question...              |  <- input, persistent at bottom
|                                |
|  --- conversation area ---      |
|  You: What did I write about   |
|       X in my notes?            |
|                                |
|  Marginal: [retrieval trace     |
|  animation, then answer]        |
|  "According to your notes      |
|  from [Document, p.3]..."       |  <- citation in ochre, tap to
|                                |     jump to source passage
+-------------------------------+
```

Left-aligned throughout. No chat bubbles with rounded-rectangle backgrounds — instead, sender distinguished by a small label + left border color (`ink` for user, `plum` for the model), keeping the page feeling like an annotated document rather than a generic messaging UI.

### Motion principles

- The retrieval trace (above) is the one signature animation — everything else is functional: input field focus, document upload progress, citation tap-to-jump.
- Document indexing (chunking + embedding generation) shows real progress, not an indeterminate spinner — this can take real time on-device, and an honest progress bar matters more here than anywhere else in the app.
- Respect reduced-motion settings; retrieval trace has an instant/static fallback.

### Writing/copy principles

- Never claim the model "understands" — frame outputs as generated from retrieved passages: "Based on [source]..." not "I know that...".
- Be explicit in-app about what's happening on first launch: "Your documents and questions never leave this device" — this is the actual value proposition and should be said once, plainly, not buried in a settings screen.
- Citation labels are literal: document name + page/section, not vague ("from your notes" is too weak; "From *Lecture 4 Notes*, page 2" is the standard to hit).

---

## 3. Screens

1. **Onboarding** — one screen: what the app does, the privacy statement above, and a note about device requirements (model download size, recommended device age).
2. **Library** — list of indexed documents, add-document button, per-document status (indexed / indexing / failed).
3. **Chat** — the core screen described above: persistent input, conversation history, retrieval trace, citations.
4. **Source viewer** — tapping a citation opens the original document scrolled to the cited passage, highlighted in `ochre`.
5. **Settings** — model selection (see design.md §5 in the README for tradeoffs), clear all data, about/privacy statement.

---

## 4. Component notes

- **Document card** (Library screen): document name (Hanken, 16/24, weight 600), status line (Caption), no shadow, `stone` surface with a 1px `ink`-at-8%-opacity border — quiet, not elevated.
- **Citation chip**: inline, `ochre` text on transparent background, underlined on tap-hover — never a filled pill badge, which would compete visually with the answer text itself.
- **Primary button** (`plum` fill, `stone` text) vs **secondary button** (transparent, `plum` border) — same two-button-style discipline as your other apps.
