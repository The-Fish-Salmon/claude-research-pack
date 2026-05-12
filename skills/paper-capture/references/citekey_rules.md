# Citekey rules

Format: `{firstauthor-lastname-lower}{year}{first-content-word-of-title}`

## Construction

1. **First author last name**, lowercased, ASCII-folded (`Müller` -> `muller`, `O'Brien` -> `obrien`). For non-Latin scripts see "Non-Latin scripts" below.
2. **Year** as 4 digits.
3. **First content word of the title**, lowercased, ASCII-folded. Drop these stopwords if they're first: `a`, `an`, `the`, `on`, `of`, `for`, `in`, `to`, `with`, `from`, `by`, `into`, `at`. If the title starts with a number, use the next content word. For non-Latin titles see "Non-Latin scripts" below.

## Non-Latin scripts

Citekeys must be ASCII-only (regex `^[a-z]+\d{4}[a-z][a-z0-9-]*$`). For papers with non-Latin author names or titles, apply this fallback chain in order. Stop at the first that produces a valid key:

1. **Use the romanized form from the metadata source.** Semantic Scholar, Crossref, and most publishers carry a romanized author name and English title alongside the original. Prefer these (e.g. S2 returns `name: "Meng Li"` and `title: "Liquid metal mechanics"` for a Chinese paper, even if the canonical title is `液态金属力学`).
2. **If no romanized form is available, transliterate deterministically:**
   - **CJK (Chinese / Japanese / Korean):** Hanyu Pinyin for Chinese (no tone marks: `孟` -> `meng`), Hepburn for Japanese (`田中` -> `tanaka`), Revised Romanization for Korean (`김` -> `kim`). Family name first.
   - **Cyrillic:** ISO 9 / GOST 7.79 System B (`Иванов` -> `ivanov`).
   - **Arabic:** ALA-LC (`الزهراني` -> `alzahrani`, with the article collapsed and `ʿ`/`ʾ` dropped).
   - **Other scripts:** use the most common Library of Congress transliteration; document the choice in the note body.
3. **Last resort:** if no deterministic romanization is available, use the Semantic Scholar paperId (lowercased, hyphen-stripped, first 8 chars) in the title slot: `unknown2024{s2id8}`. Record `citekey_source: s2id_fallback` in the frontmatter so the choice is auditable.

**Idempotency requirement:** two runs over the same paper MUST produce the same citekey. If a non-deterministic transliteration was used, lock the key into the note frontmatter as `citekey_source: transliteration` and reuse it on re-capture rather than regenerating.

## Examples

| Authors | Year | Title | Citekey |
|---|---|---|---|
| Kim, Lee, Park | 2023 | Ionic transistors for neuromorphic computing | `kim2023ionic` |
| Müller, Smith | 2021 | The role of diffusion in EDL formation | `muller2021role` |
| Wang, Chen | 2024 | A 28 nm electrochemical transistor array | `wang2024electrochemical` |
| Single-author Patel | 2019 | On the persistence of dopant inhomogeneity | `patel2019persistence` |

## Collisions

If two real papers map to the same citekey, append `-b`, `-c`, ... in chronological order of capture:

- `kim2023ionic` (first captured)
- `kim2023ionic-b` (second paper with same key)

Add a note in both papers' frontmatter so the collision is visible:
```yaml
citekey_collision_with: [kim2023ionic-b]
```

## Manual override

The user can pass an explicit citekey at capture time:
```
/capture-paper 10.1038/... --citekey kim2023neuromorphic
```
The skill validates the override (regex `^[a-z]+\d{4}[a-z][a-z0-9-]*$`) before using it.
