# Paywall Workflow — chrome-devtools-mcp + Library EZproxy

The reliable end-to-end recipe for fetching paywalled academic PDFs. Replaces the legacy `university-paper-access` (IP-only fetch, silently saved paywall HTML on failure) and `scihub` (Windows charmap encoding bug, legally grey) servers from earlier pack versions.

## When to use

- Any paper behind a publisher paywall when you have institutional access.
- Any paper that `paper-search`'s OA channels (Semantic Scholar Open-Access PDF, arXiv, PubMed Central) couldn't reach.
- Bypassing Cloudflare bot detection on Wiley / ACS landing pages.

## Prerequisites

1. `chrome-devtools` MCP server is installed (the pack installer adds it to `~/.claude.json` automatically). Config args include `--user-data-dir=%USERPROFILE%/.claude/chrome-profile` for profile persistence and `--chromeArg=--disable-blink-features=AutomationControlled` to defeat Cloudflare's basic automation detection.
2. Chrome stable installed.
3. The user has logged into their library's EZproxy / Shibboleth SSO ONCE in the chrome-devtools-mcp Chrome profile. Cookies persist across sessions.

## First-run authentication

Tell the user (or perform yourself if you know their proxy URL):

```
mcp__chrome-devtools__navigate_page url=https://<their-library-ezproxy-host>/login
```

Common patterns:
- OCLC EZproxy: `https://ezproxy.<institution>.edu/login`
- OCLC IDM (newer OCLC): `https://www-<institution>.idm.oclc.org/login`
- OpenAthens: `https://login.openathens.net/auth/<institution>.<tld>/<id>`

Chrome opens visible. The user signs in via institutional SSO (Shibboleth, ADFS, Okta, etc.). The session cookie persists in the profile dir and survives across MCP restarts.

## Per-paper recipe

For each paper to download:

### 1. Navigate via the EZproxy login URL

```
mcp__chrome-devtools__navigate_page
  url = https://<ezproxy-host>/login?url=https://<publisher-landing-url>
```

The proxy redirects to the publisher's landing page with auth cookies attached. You can verify access by snapshotting the page — look for an institution badge (e.g. "Access provided by &lt;Your University&gt;", "&lt;Your University&gt; Libraries") or the presence of a "Download PDF" link.

### 2. Fetch the PDF via same-origin JavaScript

```
mcp__chrome-devtools__evaluate_script function="async () => {
  const url = '<publisher-pdf-url>';   // see patterns below
  const r = await fetch(url, {credentials: 'include', redirect: 'follow'});
  if (!r.ok) return {ok: false, status: r.status};
  const blob = await r.blob();
  const a = document.createElement('a');
  a.href = URL.createObjectURL(blob);
  a.download = '<citekey>.pdf';
  document.body.appendChild(a);
  a.click();
  await new Promise(r => setTimeout(r, 1500));   // let Chrome flush the file
  return {ok: true, size: blob.size};
}"
```

### 3. Verify and move

The PDF lands in the OS default Downloads folder (`%USERPROFILE%\Downloads` on Windows, `~/Downloads` on macOS/Linux). Move it to the vault:

```
mv "<Downloads>/<citekey>.pdf" "<vault>/80_Attachments/papers/<citekey>.pdf"
```

Then update the lit-note frontmatter: `pdf: 80_Attachments/papers/<citekey>.pdf`.

### 4. Navigate before the next paper

**Critical**: do not try to download two papers from the same loaded page. Chrome silently blocks the 2nd download with an "Allow this site to download multiple files?" prompt that JavaScript cannot dismiss. Re-navigate (even to the same publisher's next paper) before the next fetch.

## Publisher PDF URL patterns

| Publisher | Landing URL pattern | PDF URL pattern |
|---|---|---|
| Wiley | `https://onlinelibrary.wiley.com/doi/<DOI>` (often redirects to `https://advanced.onlinelibrary.wiley.com/...` or other branded subdomains) | `https://<same-subdomain>.onlinelibrary.wiley.com/doi/pdfdirect/<DOI>` |
| ACS | `https://pubs.acs.org/doi/<DOI>` | `https://pubs.acs.org/doi/pdf/<DOI>?ref=article_openPDF` |
| IOPscience | `https://iopscience.iop.org/article/<DOI>` | `https://iopscience.iop.org/article/<DOI>/pdf` |
| IEEE Xplore | `https://ieeexplore.ieee.org/document/<arnumber>` | `https://ieeexplore.ieee.org/stampPDF/getPDF.jsp?tp=&arnumber=<arnumber>&ref=` (find `arnumber` from `/document/<arnumber>` URL; the `/stamp/stamp.jsp` page wraps an iframe with this URL) |
| Springer / Nature | `https://www.nature.com/articles/<id>` or `https://link.springer.com/article/<DOI>` | `https://www.nature.com/articles/<id>.pdf` (Nature) or `https://link.springer.com/content/pdf/<DOI>.pdf` (Springer) |
| Elsevier (ScienceDirect) | `https://www.sciencedirect.com/science/article/pii/<PII>` | `https://www.sciencedirect.com/science/article/pii/<PII>/pdfft?isDTMRedir=true&download=true` (Elsevier often gates this behind extra clicks; the manuscript-PDF endpoint may differ from the publisher version) |
| MDPI | `https://www.mdpi.com/<journal-id>/<vol>/<issue>/<article>` | `https://www.mdpi.com/<journal-id>/<vol>/<issue>/<article>/pdf` (often triggers `ERR_ABORTED` on direct navigation — that's Chrome handling it as a download; the file lands in Downloads anyway) |
| arXiv | `https://arxiv.org/abs/<id>` | `https://arxiv.org/pdf/<id>` (always free; **prefer this when available** — skip the entire paywall dance) |

## Troubleshooting

### Cross-origin fetch fails (`TypeError: Failed to fetch` or 403)

Ensure the page you're calling `evaluate_script` on is **on the same subdomain** as the PDF URL. Wiley splits journals across `advanced.onlinelibrary.wiley.com`, `chemistry-europe.onlinelibrary.wiley.com`, etc. — fetching from a different subdomain triggers CORS preflight and Wiley doesn't send `Access-Control-Allow-Credentials: true`.

Fix: navigate to a URL that lands on the **same subdomain** as the target PDF before issuing the fetch.

### Cloudflare Turnstile shows on the landing page

This is rare with the `--disable-blink-features=AutomationControlled` flag set, but happens when Cloudflare's adaptive fingerprinting trips on canvas/WebGL/mouse-entropy signals.

Fix: ask the user to manually click the "Verify you are human" checkbox in the visible Chrome window. Cloudflare sets a `cf_clearance` cookie that covers ~30 minutes of subsequent same-domain requests.

If Turnstile keeps re-challenging, the request is being detected as automated regardless. Two fallbacks:
- Connect chrome-devtools-mcp to the user's regular daily Chrome via `--browserUrl=http://127.0.0.1:9222` (their normal browsing fingerprint is harder to flag).
- Have the user click the "Download PDF" button manually in the Chrome window. The download still lands in `Downloads/` and is movable from there.

### `403 Forbidden` on `/doi/pdfdirect/` (Wiley) without Cloudflare page

Wiley blocks direct programmatic fetch from any browser whose `navigator.webdriver === true`. Verify the flag took effect:

```
mcp__chrome-devtools__evaluate_script function="() => navigator.webdriver"
```

It must return `false`. If it returns `true`, the `--disable-blink-features=AutomationControlled` flag did not get through to Chrome — check the MCP server config in `~/.claude.json` and restart Claude Code.

### Download appears successful (JS returns `ok: true, size: N`) but no file in Downloads

This is Chrome's "automatic downloads" rate-limiter on a per-page basis. Re-navigate to the paper's landing page (or any other URL on the same publisher) to reset the counter, then retry the fetch.

### Paper has both a journal version and an arXiv preprint

Use the arXiv version. Always. It's free, has no Cloudflare, and identical content (or close enough to count for lit-review purposes). Look for `[XV: <arxiv-id>]` in the citation block of the lit-review draft, or query Semantic Scholar's `paperId` for `externalIds.ArXiv`.

## Why this works (one-liner)

The publisher's PDF endpoint accepts an authenticated session-cookie request from a real-looking browser. EZproxy provides the institutional auth, the persistent profile preserves it across sessions, the AutomationControlled flag preserves the "real-looking" part, and same-origin fetch + blob URL anchor click turns Chrome's render-inline behavior into a write-to-disk.

## Why the legacy MCPs don't work

- **`university-paper-access`** does plain `httpx` GET requests with the user's IP only. No cookie store, no SSO redirect handling. When publishers serve a paywall HTML page (which they do whenever auth is incomplete), UPA saves the HTML as `paper.pdf` and reports success. False positive.
- **`scihub`** server has a Windows `cp1252` codec bug that crashes on first request. Even if fixed, Sci-Hub is legally grey and unnecessary when the user has institutional access.
