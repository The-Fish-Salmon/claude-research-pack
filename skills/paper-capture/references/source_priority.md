# PDF download source priority

When the metadata is resolved and we have a DOI / arXiv id, try the sources in this order. Stop at the first that returns a valid PDF.

## Order

1. **`arxiv`** (`mcp__arxiv__download_paper`)
   - Only when the paper has an arXiv id (check Semantic Scholar metadata for `externalIds.ArXiv`).
   - Always free, always reliable. **Always prefer this when both an arXiv preprint and a journal version exist** -- skips the entire paywall dance.
2. **`paper-search`** (`mcp__paper-search__download_arxiv|biorxiv|medrxiv|pubmed`)
   - Source-specific downloaders for preprint servers and PubMed Central (PMC) open access.
   - Free, no auth needed, OA only.
3. **`chrome-devtools`** (`mcp__chrome-devtools__navigate_page` + `mcp__chrome-devtools__evaluate_script`)
   - Paywalled journal articles via the user's authenticated library proxy session.
   - Requires the user to have logged into their library EZproxy / institutional SSO once in the chrome-devtools-mcp Chrome profile (`%USERPROFILE%/.claude/chrome-profile`). Cookies persist across sessions.
   - The recipe: navigate to `https://<ezproxy-host>/login?url=<publisher-landing-url>`, then `evaluate_script` issuing a same-origin `fetch(<pdf-url>, {credentials: 'include'})`, then trigger a download via `URL.createObjectURL(blob)` + `<a download>` click.
   - See [skills/deep-research/references/paywall_workflow.md](../../deep-research/references/paywall_workflow.md) for the per-publisher PDF URL patterns (Wiley pdfdirect, ACS pdf?ref=article_openPDF, IOP /article/X/pdf, IEEE stampPDF/getPDF.jsp, etc.) and Cloudflare workarounds.

## Failure handling

Keep going down the list until one succeeds OR the list is exhausted:

```
for source in [arxiv, paper_search, chrome_devtools]:
    try:
        path = source.download(doi_or_arxiv_id)
        if path and pdf_is_valid(path):
            return path
    except (NotFound, AccessDenied, NetworkError):
        continue
return None  # skill writes note with pdf: null
```

### `pdf_is_valid`

A file passes ALL of these checks:

1. **Size:** `> 16 KB`. (The known-bad case was a 10.8 KB arXiv HTML 404 page; 16 KB cuts that out while still allowing slim 2-page conference papers.)
2. **Magic bytes:** the first 8 bytes match `%PDF-1.` (i.e. literal `%PDF-1.0` through `%PDF-1.7`, or `%PDF-2.`).
3. **No HTML smuggling:** the first 1024 bytes do NOT contain `<!DOCTYPE`, `<html`, `<HTML`, or `<head` (case-sensitive substring check). Some publishers serve auth-error HTML with a `Content-Type: application/pdf` header; the magic-byte check alone is insufficient.
4. **Trailer present:** the last 1024 bytes contain `%%EOF`. A truncated download (network drop mid-stream) often passes the magic-byte check but fails this one.

All four must pass. If any fails, treat the download as failed: delete the file, log the failure mode (size / magic / html / trailer), continue down the priority chain. Never report success on a failed `pdf_is_valid`.

If chrome-devtools-mcp is unavailable (not configured, or the user hasn't authenticated), the chain stops at paper-search. The skill writes the note with `pdf: null`; the user can drop the PDF in manually with `/ingest-pdf` later.

## Removed sources

- **`university-paper-access`** -- did plain IP-based `httpx` GET with no SSO redirect handling. When publishers served a paywall HTML page (which they do whenever auth was incomplete), UPA saved the HTML as `paper.pdf` and reported success. False positive. Replaced by chrome-devtools-mcp + library proxy.
- **`scihub`** -- Windows charmap encoding bug crashed it on first request, and it's legally grey besides. Redundant for users with institutional access.

## Output path

All PDFs land at `{vault}/80_Attachments/papers/{citekey}.pdf`. The vault path comes from the `OBSIDIAN_VAULT_PATH` env var. Examples: `/mnt/c/Users/me/Documents/MyVault/80_Attachments/papers/kim2023ionic.pdf` (WSL) or `C:\Users\me\Documents\MyVault\80_Attachments\papers\kim2023ionic.pdf` (Windows native / Desktop).

If `PAPER_DOWNLOAD_DIR` is set to a different location (e.g. for backup or for sharing across vaults), also place a copy there.

## Idempotency

If `{vault}/80_Attachments/papers/{citekey}.pdf` already exists and is valid, skip download. Re-capture only refreshes metadata.
