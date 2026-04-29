# PDF metadata heuristics

When a PDF has no DOI and no arXiv id, fall back to extracting
**title + first-author + year** from the first page so paper-capture can
resolve it via Semantic Scholar's title-author-year search.

## DOI regex

The canonical DOI form per CrossRef:

```
\b10\.\d{4,9}/[-._;()/:a-zA-Z0-9]+\b
```

Notes:
- The DOI prefix is `10.` followed by 4-9 digits, then `/`.
- Common spots: top of first page, footer of first page ("doi:"), running
  header on every page.
- If you find more than one match, prefer the one closest to the title.
  Publishers sometimes embed the journal's master DOI plus the article DOI;
  the article DOI is usually first.
- Strip trailing punctuation (`.`, `,`, `)`) — those are not part of the DOI.

## arXiv id regex

```
arXiv:\d{4}\.\d{4,5}(v\d+)?
```

Or the URL form:

```
https?://arxiv\.org/abs/\d{4}\.\d{4,5}
```

If the version suffix is present (e.g. `2103.04822v3`), strip it before
handing to paper-capture — Semantic Scholar uses the unversioned id.

## Title extraction

The title is almost always the **first non-trivial line** on page 1. "Trivial"
means:

- Journal name or running header (often italicized, often centered, usually
  short and ALL CAPS or Title Case)
- "ARTICLE", "RESEARCH ARTICLE", "REVIEW", "LETTER", "PERSPECTIVE" labels
- Volume / issue / DOI / submission-date strings
- "© Year Publisher" copyright lines
- arXiv preprint banner

Heuristic that works ~80% of the time on physics / chemistry / biology
papers:

1. Grab the first 30 lines of page-1 text.
2. Skip anything that matches the trivial patterns above.
3. The first line that's **at least 25 characters** and doesn't look like an
   author list (no "and", no "*", no email-style symbols) is the title.
4. If the title spans two lines (common in long titles), join them when the
   first line ends without a period.

If the heuristic returns nothing convincing, report to the user:
`Title extraction failed for {filename}. Please give me the title or DOI.`

## First-author extraction

After the title, the next 1-5 lines are usually the author list. The first
author is the first name on that list. Common forms:

- `Jane A. Smith`
- `Jane A. Smith*` (asterisk = corresponding author)
- `J. A. Smith`
- `Smith, J. A.` (last-first form, used by some journals)

For the citekey, paper-capture only needs the **last name**:

- `Smith` from `Jane A. Smith` or `J. A. Smith`
- `Smith` from `Smith, J. A.` (take the part before the comma)
- Strip diacritics (`Müller` -> `muller`, `García` -> `garcia`) — paper-capture
  does this anyway, but doing it here makes search results cleaner.

## Year extraction

Look for a four-digit number 1900-2099 in:

1. The running header / footer of page 1 (most reliable — journals always
   put the publication year there).
2. The DOI suffix (some publishers embed the year, e.g. `10.1038/s41586-021-03819-2`
   has `2021` in the article id; this is unreliable, don't rely on it).
3. The reference list of the article itself (no — that's other papers'
   years, not this paper's year).
4. The submission-date line ("Submitted YYYY", "Published YYYY"). If the
   submission and publication years differ, prefer **publication**.

## When to escalate

If after running all three heuristics you have any of:

- 0 results from DOI / arXiv sniff
- A title under 25 characters
- No four-digit year anywhere on page 1
- Multiple plausible titles

…report to the user and ask for clarification rather than guessing. A
hallucinated citekey (`smith2021unknown`) is worse than a missing one,
because it pollutes the vault.

## Sanity-check the result

Before handing the extracted (title, first-author, year) tuple to
paper-capture, confirm at least two of the three are present and look
plausible. Pure-title resolution sometimes works on Semantic Scholar but
the false-positive rate is high; better to escalate.
