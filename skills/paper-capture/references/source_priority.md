# PDF download source priority

When the metadata is resolved and we have a DOI / arXiv id, try the sources in this order. Stop at the first that returns a valid PDF.

## Order

1. **`university-paper-access`** (`mcp__university-paper-access__download_paper`)
   - Uses your institutional IP / Unpaywall to find legal full text.
   - Best path. Requires `UNPAYWALL_EMAIL` env var.
   - Often succeeds for paywalled journals when on campus / VPN.
2. **`arxiv`** (`mcp__arxiv__download_paper`)
   - Only when the paper has an arXiv id.
   - Always free, always reliable.
3. **`paper-search`** (`mcp__paper-search__download_arxiv|biorxiv|medrxiv|pubmed`)
   - Source-specific downloaders for preprint servers and PMC open access.
4. **`scihub`** (`mcp__scihub__download_scihub_pdf`)
   - Last resort. Some networks block; respect that.
   - Note legal context — the user has chosen to enable this server.

## Failure handling

Keep going down the list until one succeeds OR the list is exhausted:

```
for source in [upa, arxiv, paper_search, scihub]:
    try:
        path = source.download(doi_or_arxiv_id)
        if path and pdf_is_valid(path):
            return path
    except (NotFound, AccessDenied, NetworkError):
        continue
return None  # skill writes note with pdf: null
```

`pdf_is_valid` = file > 10KB and starts with `%PDF`.

## Output path

All PDFs land at `{vault}/80_Attachments/papers/{citekey}.pdf`. The vault path comes from the `OBSIDIAN_VAULT_PATH` env var. Examples: `/mnt/c/Users/me/Documents/MyVault/80_Attachments/papers/kim2023ionic.pdf` (WSL) or `C:\Users\me\Documents\MyVault\80_Attachments\papers\kim2023ionic.pdf` (Windows native / Desktop).

If `PAPER_DOWNLOAD_DIR` is set to a different location (e.g. for backup or for sharing across vaults), also place a copy there.

## Idempotency

If `{vault}/80_Attachments/papers/{citekey}.pdf` already exists and is valid, skip download. Re-capture only refreshes metadata.
