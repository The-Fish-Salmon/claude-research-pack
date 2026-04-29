# Citekey rules

Format: `{firstauthor-lastname-lower}{year}{first-content-word-of-title}`

## Construction

1. **First author last name**, lowercased, ASCII-folded (`Müller` -> `muller`, `O'Brien` -> `obrien`).
2. **Year** as 4 digits.
3. **First content word of the title**, lowercased, ASCII-folded. Drop these stopwords if they're first: `a`, `an`, `the`, `on`, `of`, `for`, `in`, `to`, `with`, `from`, `by`, `into`, `at`. If the title starts with a number, use the next content word.

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
