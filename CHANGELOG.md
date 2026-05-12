# Changelog

## 2026-05-12 — Integrity and rate-limit pass

Fixes from a 5-agent end-to-end audit of the pack against real MCP servers. All edits are to skill prompts and reference docs — no script or MCP server code changed.

### Citation integrity

- **`paper-capture/SKILL.md`** — Workflow rewritten:
  - Step 2 documents the `DOI:` prefix required by `mcp__paper-mcp__paper_get_metadata` and a 429-vs-404 retry policy (3 attempts with 2s/4s/8s backoff). A 429 no longer collapses to "metadata not found".
  - New step 3: retraction check via Crossref after metadata fetch. When the Crossref title is prefixed `RETRACTED:` or the response carries `update-type: retraction`, the note gets `retracted: true` in frontmatter, a `[RETRACTED]` prefix on the body title, and a loud confirmation line to the user (`Captured (RETRACTED): ...`). Retracted papers are still captured (researchers need them for context) but never silently.
  - Step 5: fallback chain updated from the legacy `university-paper-access -> arxiv -> scihub` reference to the current `arxiv -> paper-search -> chrome-devtools` order, matching `references/source_priority.md`. `pdf_is_valid` is now mandatory after every download — a returned file path is no longer proof of success.
  - New error path: "PDF download appeared to succeed but `pdf_is_valid` returned false" (HTML error page saved as `.pdf`, truncated download, etc.) — delete the file, continue down the priority chain, do not report success.

- **`paper-capture/references/source_priority.md`** — `pdf_is_valid` strengthened from "size > 10 KB and starts with `%PDF`" to four checks:
  1. Size > 16 KB.
  2. First 8 bytes match `%PDF-1.`.
  3. First 1024 bytes contain no `<!DOCTYPE`, `<html`, `<HTML`, or `<head` (some publishers serve auth-error HTML with `Content-Type: application/pdf`).
  4. Last 1024 bytes contain `%%EOF` (catches truncated downloads).

  Bug case that motivated the change: `mcp__paper-search__download_arxiv` saved a 10.8 KB arXiv 404 HTML page as `{id}.pdf` and reported success. The new check rejects it on size + HTML smuggling.

- **`paper-capture/references/citekey_rules.md`** — New "Non-Latin scripts" section:
  - Prefer metadata-source romanization (most S2/Crossref records carry an English title and romanized author name).
  - Otherwise deterministic transliteration: Pinyin (no tones) for Chinese, Hepburn for Japanese, Revised Romanization for Korean, ISO 9 / GOST 7.79 System B for Cyrillic, ALA-LC for Arabic.
  - Last resort: `unknown{year}{first-8-chars-of-S2-paperId}`, recorded as `citekey_source: s2id_fallback` in frontmatter.
  - Idempotency requirement: same paper must produce same citekey across runs.

### Rate-limit discipline (Semantic Scholar)

The Semantic Scholar Graph API key default is 1 request/second cumulative across all endpoints. The pack's old defaults (3 parallel investigators, S2 as primary discovery server) tripped this limit constantly.

- **`deep-research/references/iron_rules.md`** — New rule 8: "Semantic Scholar budget". Codifies the discovery-vs-resolution split (S2 for resolution and pre-flight; paper-search / arxiv for discovery), the 1.1s minimum spacing for cross-investigator S2 calls, the 2s/4s/8s 429 backoff, and the investigator-parallelism cap.

- **`deep-research/SKILL.md`** — "Spawning sub-agents" section updated:
  - Default investigator cap is **2** when S2 is the primary metadata path (`s2_primary` runs).
  - Cap stays at **3** when the run is arxiv/paper-search heavy (`oa_primary`) or the user has a higher-rate S2 key.
  - Scoping agent now tags the run with `s2_primary` / `oa_primary` so the spawn count is derived, not guessed.
  - Citation pre-flight wall-clock time noted: ~N seconds for N citations under 1 RPS.

- **`deep-research/agents/investigator.md`** — New "Rate-limit awareness" section:
  - Discovery rule: prefer paper-search / arxiv; reserve S2 for resolution / citation-graph / pre-flight.
  - Each S2 call logged as `[S2 call planned: <endpoint>]` in the scratch trail so the spawning agent can serialize.
  - 429 backoff policy and the "429 is not a not-found" rule reinforced.
  - Vault-cache check before every S2 metadata call: if `30_Literature/{citekey}.md` already exists, read from cache.
  - Also documents the `DOI:` input-format quirk on `mcp__paper-mcp__paper_get_metadata`.

### Documentation

- **`INSTALL_WINDOWS.md`** — Path B manual-fallback section now lists `SEMANTIC_SCHOLAR_API_KEY` alongside the other five env vars, with a sub-section explaining why it matters, the three S2 endpoints the pack actually uses (for the application form), the default 1 RPS rate, and that a higher-rate institutional key can lift the parallel-investigator cap.

### Bugs explicitly addressed (severity-ordered)

| Sev | Bug | Resolution |
|---|---|---|
| 1 | `download_arxiv` silently saves HTML 404 as `{id}.pdf` and reports success | `pdf_is_valid` 4-check post-download validation in `source_priority.md`; mandatory call in `paper-capture/SKILL.md` step 5 |
| 1 | Workflow text references removed `university-paper-access` and `scihub` MCPs | `paper-capture/SKILL.md` step 5 updated to current chain |
| 2 | No retraction detection; Wakefield Lancet DOI would ingest silently | Crossref check in `paper-capture/SKILL.md` step 3, `retracted: true` frontmatter, prefixed title |
| 2 | `paper_get_metadata` 429 collapses into "not found" | 3-attempt 2s/4s/8s backoff; iron rule 8; investigator awareness section |
| 2 | Citekey rules silent on CJK / non-Latin scripts; same paper → different keys across runs | New "Non-Latin scripts" section with deterministic transliteration policy |
| 2 | Parallel investigators contend for 1 RPS S2 budget | Investigator cap = 2 under `s2_primary`; cross-investigator S2 serialization rule |
| 3 | `paper_get_metadata` requires undocumented `DOI:` prefix | Documented in `investigator.md` and `paper-capture/SKILL.md` step 2 |
| 3 | `search_semantic_scholar` has no relevance gate (returns keyword matches for nonsense queries) | Mitigated by mandatory pre-flight + iron rule 8's "S2 for resolution, not discovery" |

### Out of scope for this release

- Sustained-load behavior across all servers (only S2 has documented rate handling).
- Devil's advocate and ethics gate fuzzing.
- Live-config (`settings.local.json`) allowlist completeness — the pack ships skill prompts and templates; the user maintains their own permission allowlist. New tool names introduced in this release that may need allowlisting:
  `mcp__obsidian__read_notes`, `mcp__obsidian__search_notes`,
  `mcp__paper-mcp__paper_get_metadata` and siblings,
  `mcp__semantic-scholar__get_semantic_scholar_citations_and_references`,
  `mcp__arxiv__get_abstract`, `mcp__arxiv__read_paper`,
  `mcp__paper-search__{search,read,download}_{biorxiv,medrxiv,pubmed}`,
  and the `mcp__chrome-devtools__*` tools used by the paywall workflow.

### Migration notes

- If upgrading from a pre-2026-05-12 install, redeploy the skill files (run the installer or copy `skills/` over the installed copy). No env-var or MCP-server changes are required by this release. The 429-handling and `pdf_is_valid` strengthening take effect on next `/research` or `/capture-paper` invocation.
- If your installed `settings.local.json` lists `mcp__university-paper-access__*` or `mcp__scihub__*` entries, remove them — the corresponding MCP servers were dropped in an earlier release and the allowlist entries are dead.
- If you don't have a Semantic Scholar API key, get one at https://www.semanticscholar.org/product/api#api-key-form. The pack works without it but the citation-discipline gate is weaker.
