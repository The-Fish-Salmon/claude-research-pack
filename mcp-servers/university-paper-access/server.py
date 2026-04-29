"""
University Paper Access MCP Server

Leverages institutional network (IP-based authentication) to search for and
download academic papers that would normally be behind paywalls. Combines
multiple free APIs for discovery with direct publisher access for full-text PDFs.

Search chain:
  1. Semantic Scholar / OpenAlex / CrossRef for discovery + metadata
  2. Unpaywall API for open-access PDF links
  3. Direct publisher download via university network (IP-based auth)

Designed for use on university campus networks or VPN.
"""

import asyncio
import json
import logging
import os
import re
import time
from pathlib import Path
from typing import Any, Dict, List, Optional
from urllib.parse import quote, urlparse

import httpx
from mcp.server.fastmcp import FastMCP

logging.basicConfig(level=logging.INFO, format="%(asctime)s - %(levelname)s - %(message)s")
logger = logging.getLogger(__name__)

# --- Configuration ---
DOWNLOAD_DIR = os.environ.get("PAPER_DOWNLOAD_DIR", str(Path.home() / "papers"))
SEMANTIC_SCHOLAR_KEY = os.environ.get("SEMANTIC_SCHOLAR_API_KEY", "")
UNPAYWALL_EMAIL = os.environ.get("UNPAYWALL_EMAIL", "user@university.edu")
REQUEST_TIMEOUT = 30
MAX_RESULTS = 20

# Ensure download directory exists
Path(DOWNLOAD_DIR).mkdir(parents=True, exist_ok=True)

mcp = FastMCP("university-paper-access")

# ─── HTTP helpers ────────────────────────────────────────────────────────────

def _headers(extra: dict | None = None) -> dict:
    """Common browser-like headers so publishers don't block us."""
    h = {
        "User-Agent": (
            "Mozilla/5.0 (Windows NT 10.0; Win64; x64) "
            "AppleWebKit/537.36 (KHTML, like Gecko) "
            "Chrome/125.0.0.0 Safari/537.36"
        ),
        "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,"
                  "application/pdf,*/*;q=0.8",
        "Accept-Language": "en-US,en;q=0.9",
    }
    if extra:
        h.update(extra)
    return h


def _semantic_scholar_headers() -> dict:
    h = _headers()
    if SEMANTIC_SCHOLAR_KEY:
        h["x-api-key"] = SEMANTIC_SCHOLAR_KEY
    return h


async def _get_json(url: str, headers: dict | None = None, params: dict | None = None) -> dict | list | None:
    """GET request returning parsed JSON, or None on failure."""
    try:
        async with httpx.AsyncClient(timeout=REQUEST_TIMEOUT, follow_redirects=True) as client:
            resp = await client.get(url, headers=headers or _headers(), params=params)
            resp.raise_for_status()
            return resp.json()
    except Exception as e:
        logger.warning(f"GET {url} failed: {e}")
        return None


# ─── Search backends ─────────────────────────────────────────────────────────

async def _search_semantic_scholar(query: str, limit: int = 10) -> List[Dict[str, Any]]:
    """Search Semantic Scholar API."""
    url = "https://api.semanticscholar.org/graph/v1/paper/search"
    params = {
        "query": query,
        "limit": min(limit, 100),
        "fields": "title,authors,year,abstract,externalIds,url,citationCount,openAccessPdf,publicationDate,journal",
    }
    data = await _get_json(url, headers=_semantic_scholar_headers(), params=params)
    if not data or "data" not in data:
        return []
    results = []
    for p in data["data"]:
        doi = (p.get("externalIds") or {}).get("DOI", "")
        arxiv_id = (p.get("externalIds") or {}).get("ArXiv", "")
        oa_pdf = (p.get("openAccessPdf") or {}).get("url", "")
        results.append({
            "title": p.get("title", ""),
            "authors": ", ".join(a.get("name", "") for a in (p.get("authors") or [])),
            "year": p.get("year"),
            "abstract": (p.get("abstract") or "")[:500],
            "doi": doi,
            "arxiv_id": arxiv_id,
            "citations": p.get("citationCount", 0),
            "open_access_pdf": oa_pdf,
            "url": p.get("url", ""),
            "journal": (p.get("journal") or {}).get("name", ""),
            "source": "semantic_scholar",
        })
    return results


async def _search_openalex(query: str, limit: int = 10) -> List[Dict[str, Any]]:
    """Search OpenAlex API (free, no key needed, 240M+ works)."""
    url = "https://api.openalex.org/works"
    params = {
        "search": query,
        "per_page": min(limit, 50),
        "mailto": UNPAYWALL_EMAIL,
    }
    data = await _get_json(url, params=params)
    if not data or "results" not in data:
        return []
    results = []
    for w in data["results"]:
        doi_raw = w.get("doi", "") or ""
        doi = doi_raw.replace("https://doi.org/", "")
        # Find best open-access URL
        oa_url = ""
        best_oa = w.get("best_oa_location") or {}
        oa_url = best_oa.get("pdf_url") or best_oa.get("landing_page_url") or ""
        results.append({
            "title": w.get("display_name", ""),
            "authors": ", ".join(
                (a.get("author") or {}).get("display_name", "")
                for a in (w.get("authorships") or [])[:5]
            ),
            "year": w.get("publication_year"),
            "abstract": _reconstruct_abstract(w.get("abstract_inverted_index")),
            "doi": doi,
            "arxiv_id": "",
            "citations": w.get("cited_by_count", 0),
            "open_access_pdf": oa_url,
            "url": doi_raw or w.get("id", ""),
            "journal": (w.get("primary_location") or {}).get("source", {}).get("display_name", "") if w.get("primary_location") else "",
            "source": "openalex",
        })
    return results


def _reconstruct_abstract(inverted_index: dict | None) -> str:
    """OpenAlex stores abstracts as inverted indexes -- reconstruct them."""
    if not inverted_index:
        return ""
    word_positions = []
    for word, positions in inverted_index.items():
        for pos in positions:
            word_positions.append((pos, word))
    word_positions.sort()
    text = " ".join(w for _, w in word_positions)
    return text[:500]


async def _search_crossref(query: str, limit: int = 10) -> List[Dict[str, Any]]:
    """Search CrossRef API."""
    url = "https://api.crossref.org/works"
    params = {
        "query": query,
        "rows": min(limit, 20),
        "mailto": UNPAYWALL_EMAIL,
    }
    data = await _get_json(url, params=params)
    if not data or "message" not in data:
        return []
    results = []
    for item in data["message"].get("items", []):
        doi = item.get("DOI", "")
        title_list = item.get("title", [])
        title = title_list[0] if title_list else ""
        authors = ", ".join(
            f"{a.get('given', '')} {a.get('family', '')}".strip()
            for a in (item.get("author") or [])[:5]
        )
        year = None
        for date_field in ["published-print", "published-online", "created"]:
            dp = item.get(date_field, {}).get("date-parts", [[]])
            if dp and dp[0]:
                year = dp[0][0]
                break
        results.append({
            "title": title,
            "authors": authors,
            "year": year,
            "abstract": "",
            "doi": doi,
            "arxiv_id": "",
            "citations": item.get("is-referenced-by-count", 0),
            "open_access_pdf": "",
            "url": f"https://doi.org/{doi}" if doi else "",
            "journal": ", ".join(item.get("container-title", [])),
            "source": "crossref",
        })
    return results


async def _search_arxiv(query: str, limit: int = 10) -> List[Dict[str, Any]]:
    """Search arXiv API."""
    url = "https://export.arxiv.org/api/query"
    params = {
        "search_query": f"all:{query}",
        "start": 0,
        "max_results": min(limit, 50),
        "sortBy": "relevance",
    }
    try:
        async with httpx.AsyncClient(timeout=REQUEST_TIMEOUT) as client:
            resp = await client.get(url, params=params)
            resp.raise_for_status()
            text = resp.text
    except Exception as e:
        logger.warning(f"arXiv search failed: {e}")
        return []

    # Simple XML parsing for arXiv Atom feed
    results = []
    entries = text.split("<entry>")[1:]  # skip header
    for entry in entries[:limit]:
        title = _xml_text(entry, "title").replace("\n", " ").strip()
        summary = _xml_text(entry, "summary").replace("\n", " ").strip()[:500]
        authors_raw = re.findall(r"<name>(.*?)</name>", entry)
        published = _xml_text(entry, "published")[:4]
        arxiv_id = ""
        id_text = _xml_text(entry, "id")
        m = re.search(r"(\d{4}\.\d{4,5})", id_text)
        if m:
            arxiv_id = m.group(1)
        doi = ""
        doi_match = re.search(r'href="https?://dx\.doi\.org/([^"]+)"', entry)
        if doi_match:
            doi = doi_match.group(1)
        pdf_url = f"https://arxiv.org/pdf/{arxiv_id}" if arxiv_id else ""
        results.append({
            "title": title,
            "authors": ", ".join(authors_raw[:5]),
            "year": int(published) if published.isdigit() else None,
            "abstract": summary,
            "doi": doi,
            "arxiv_id": arxiv_id,
            "citations": 0,
            "open_access_pdf": pdf_url,
            "url": f"https://arxiv.org/abs/{arxiv_id}" if arxiv_id else id_text,
            "journal": "arXiv",
            "source": "arxiv",
        })
    return results


def _xml_text(xml: str, tag: str) -> str:
    m = re.search(rf"<{tag}[^>]*>(.*?)</{tag}>", xml, re.DOTALL)
    return m.group(1).strip() if m else ""


# ─── Unpaywall / PDF resolution ─────────────────────────────────────────────

async def _unpaywall_lookup(doi: str) -> Optional[str]:
    """Check Unpaywall for open-access PDF URL."""
    if not doi:
        return None
    url = f"https://api.unpaywall.org/v2/{quote(doi, safe='')}"
    params = {"email": UNPAYWALL_EMAIL}
    data = await _get_json(url, params=params)
    if not data:
        return None
    best = data.get("best_oa_location") or {}
    return best.get("url_for_pdf") or best.get("url") or None


# Publisher-specific PDF URL patterns (used with university IP access)
_PUBLISHER_PDF_PATTERNS = {
    "sciencedirect.com": lambda url, doi: url.replace("/abs/", "/pdf/") if "/abs/" in url else url + "?download=true",
    "link.springer.com": lambda url, doi: url.replace("/article/", "/content/pdf/") + ".pdf" if "/article/" in url else url,
    "nature.com": lambda url, doi: url + ".pdf" if not url.endswith(".pdf") else url,
    "pubs.acs.org": lambda url, doi: url.replace("/doi/abs/", "/doi/pdf/").replace("/doi/full/", "/doi/pdf/"),
    "ieeexplore.ieee.org": lambda url, doi: None,  # IEEE needs special handling
    "onlinelibrary.wiley.com": lambda url, doi: url.replace("/abs/", "/pdfdirect/").replace("/full/", "/pdfdirect/"),
    "pubs.rsc.org": lambda url, doi: url.replace("/articlelanding/", "/articlepdf/"),
    "iopscience.iop.org": lambda url, doi: url + "/pdf" if not url.endswith("/pdf") else url,
    "aip.scitation.org": lambda url, doi: f"https://pubs.aip.org/doi/pdf/{doi}" if doi else url,
    "journals.aps.org": lambda url, doi: url.replace("/abstract/", "/pdf/"),
}


async def _resolve_pdf_url(doi: str, known_oa_url: str = "") -> Optional[str]:
    """
    Try to find a downloadable PDF URL using this priority:
    1. Known open-access URL (from Semantic Scholar / OpenAlex)
    2. Unpaywall lookup
    3. DOI resolution + publisher-specific URL transform (university access)
    """
    # 1. Already have OA URL
    if known_oa_url:
        return known_oa_url

    # 2. Unpaywall
    oa = await _unpaywall_lookup(doi)
    if oa:
        return oa

    # 3. Resolve DOI -> publisher URL -> transform to PDF URL
    if not doi:
        return None
    try:
        async with httpx.AsyncClient(timeout=REQUEST_TIMEOUT, follow_redirects=True, headers=_headers()) as client:
            resp = await client.get(f"https://doi.org/{doi}")
            landing_url = str(resp.url)
            domain = urlparse(landing_url).netloc.lower()
            # Try known publisher patterns
            for pub_domain, transformer in _PUBLISHER_PDF_PATTERNS.items():
                if pub_domain in domain:
                    pdf_url = transformer(landing_url, doi)
                    if pdf_url:
                        return pdf_url
            # Fallback: return the landing page (university network may still give access)
            return landing_url
    except Exception as e:
        logger.warning(f"DOI resolution failed for {doi}: {e}")
        return None


async def _download_pdf(url: str, filepath: str) -> bool:
    """Download a PDF file, following redirects. Uses university IP access."""
    try:
        async with httpx.AsyncClient(
            timeout=60,
            follow_redirects=True,
            headers=_headers({"Accept": "application/pdf,*/*"}),
        ) as client:
            resp = await client.get(url)
            resp.raise_for_status()
            content_type = resp.headers.get("content-type", "")
            content = resp.content
            # Verify it's actually a PDF
            if content[:5] == b"%PDF-" or "pdf" in content_type.lower():
                Path(filepath).parent.mkdir(parents=True, exist_ok=True)
                with open(filepath, "wb") as f:
                    f.write(content)
                logger.info(f"Downloaded PDF ({len(content)} bytes) -> {filepath}")
                return True
            else:
                logger.warning(f"Response is not a PDF (content-type: {content_type}, first bytes: {content[:20]})")
                # Save the HTML landing page for debugging
                html_path = filepath.replace(".pdf", "_landing.html")
                with open(html_path, "wb") as f:
                    f.write(content)
                logger.info(f"Saved landing page -> {html_path}")
                return False
    except Exception as e:
        logger.warning(f"PDF download failed from {url}: {e}")
        return False


def _sanitize_filename(text: str, max_len: int = 80) -> str:
    """Create a safe filename from paper title."""
    text = re.sub(r'[<>:"/\\|?*]', '', text)
    text = re.sub(r'\s+', '_', text.strip())
    return text[:max_len]


def _dedup_results(all_results: List[Dict]) -> List[Dict]:
    """Deduplicate results by DOI or title."""
    seen_dois = set()
    seen_titles = set()
    deduped = []
    for r in all_results:
        doi = r.get("doi", "").lower().strip()
        title = r.get("title", "").lower().strip()
        if doi and doi in seen_dois:
            continue
        if title and title in seen_titles:
            continue
        if doi:
            seen_dois.add(doi)
        if title:
            seen_titles.add(title)
        deduped.append(r)
    return deduped


# ─── MCP Tools ───────────────────────────────────────────────────────────────

@mcp.tool()
async def search_papers(
    query: str,
    sources: str = "all",
    limit: int = 10,
) -> Dict[str, Any]:
    """
    Search for academic papers across multiple databases.

    Searches Semantic Scholar, OpenAlex, CrossRef, and arXiv simultaneously,
    then deduplicates results. Returns metadata including DOI, abstract,
    citation count, and open-access PDF links where available.

    Args:
        query: Search query (keywords, paper title, or topic).
               Examples: "ion gated transistor WSe2", "physical reservoir computing",
               "2D material electrolyte gated field effect transistor"
        sources: Comma-separated list of sources to search. Options:
                 "all", "semantic_scholar", "openalex", "crossref", "arxiv".
                 Default: "all"
        limit: Max results per source (default 10, max 20).

    Returns:
        Dict with "results" (list of papers) and "total" count.
        Each paper has: title, authors, year, abstract, doi, arxiv_id,
        citations, open_access_pdf, url, journal, source.
    """
    limit = min(limit, MAX_RESULTS)
    source_list = [s.strip().lower() for s in sources.split(",")]
    use_all = "all" in source_list

    tasks = []
    if use_all or "semantic_scholar" in source_list:
        tasks.append(_search_semantic_scholar(query, limit))
    if use_all or "openalex" in source_list:
        tasks.append(_search_openalex(query, limit))
    if use_all or "crossref" in source_list:
        tasks.append(_search_crossref(query, limit))
    if use_all or "arxiv" in source_list:
        tasks.append(_search_arxiv(query, limit))

    all_results = []
    for result_list in await asyncio.gather(*tasks, return_exceptions=True):
        if isinstance(result_list, list):
            all_results.extend(result_list)
        elif isinstance(result_list, Exception):
            logger.warning(f"Search source failed: {result_list}")

    deduped = _dedup_results(all_results)

    return {
        "results": deduped,
        "total": len(deduped),
        "query": query,
        "sources_searched": source_list if not use_all else ["semantic_scholar", "openalex", "crossref", "arxiv"],
    }


@mcp.tool()
async def get_paper_details(doi: str) -> Dict[str, Any]:
    """
    Get detailed information about a paper by DOI, including full metadata
    and available PDF download URLs.

    Queries Semantic Scholar, OpenAlex, CrossRef, and Unpaywall to assemble
    the most complete metadata possible.

    Args:
        doi: The DOI of the paper (e.g., "10.1038/s41928-023-01053-4").

    Returns:
        Dict with title, authors, year, abstract, journal, citations,
        pdf_urls (list of available download links), and references.
    """
    # Query multiple sources in parallel
    ss_url = f"https://api.semanticscholar.org/graph/v1/paper/DOI:{doi}"
    ss_params = {"fields": "title,authors,year,abstract,externalIds,url,citationCount,openAccessPdf,journal,references.title,references.externalIds"}

    oa_url = f"https://api.openalex.org/works/doi:{doi}"
    cr_url = f"https://api.crossref.org/works/{doi}"

    ss_data, oa_data, cr_data, unpaywall_url = await asyncio.gather(
        _get_json(ss_url, headers=_semantic_scholar_headers(), params=ss_params),
        _get_json(oa_url, params={"mailto": UNPAYWALL_EMAIL}),
        _get_json(cr_url),
        _unpaywall_lookup(doi),
        return_exceptions=True,
    )

    result = {"doi": doi, "pdf_urls": []}

    # Merge Semantic Scholar data
    if isinstance(ss_data, dict) and "title" in ss_data:
        result["title"] = ss_data.get("title", "")
        result["authors"] = ", ".join(a.get("name", "") for a in (ss_data.get("authors") or []))
        result["year"] = ss_data.get("year")
        result["abstract"] = ss_data.get("abstract", "")
        result["citations"] = ss_data.get("citationCount", 0)
        result["journal"] = (ss_data.get("journal") or {}).get("name", "")
        oa_pdf = (ss_data.get("openAccessPdf") or {}).get("url", "")
        if oa_pdf:
            result["pdf_urls"].append({"url": oa_pdf, "source": "semantic_scholar_oa"})
        # References
        refs = ss_data.get("references") or []
        result["references"] = [
            {"title": r.get("title", ""), "doi": (r.get("externalIds") or {}).get("DOI", "")}
            for r in refs[:20]
        ]

    # Merge OpenAlex data (fill gaps)
    if isinstance(oa_data, dict):
        if not result.get("title"):
            result["title"] = oa_data.get("display_name", "")
        if not result.get("abstract"):
            result["abstract"] = _reconstruct_abstract(oa_data.get("abstract_inverted_index"))
        best_oa = oa_data.get("best_oa_location") or {}
        oa_pdf = best_oa.get("pdf_url") or ""
        if oa_pdf:
            result["pdf_urls"].append({"url": oa_pdf, "source": "openalex_oa"})

    # CrossRef data
    if isinstance(cr_data, dict) and "message" in cr_data:
        msg = cr_data["message"]
        if not result.get("title"):
            titles = msg.get("title", [])
            result["title"] = titles[0] if titles else ""

    # Unpaywall
    if isinstance(unpaywall_url, str) and unpaywall_url:
        result["pdf_urls"].append({"url": unpaywall_url, "source": "unpaywall"})

    # Publisher direct URL (university access)
    publisher_url = await _resolve_pdf_url(doi)
    if publisher_url:
        result["pdf_urls"].append({"url": publisher_url, "source": "publisher_direct"})

    result.setdefault("title", "")
    result.setdefault("authors", "")
    result.setdefault("year", None)
    result.setdefault("abstract", "")
    result.setdefault("citations", 0)
    result.setdefault("journal", "")
    result.setdefault("references", [])

    return result


@mcp.tool()
async def download_paper(
    doi: str = "",
    arxiv_id: str = "",
    url: str = "",
    filename: str = "",
) -> Dict[str, Any]:
    """
    Download a paper PDF using university network access.

    Tries multiple sources in order:
    1. arXiv (if arxiv_id provided -- always free)
    2. Open-access PDF from Semantic Scholar / OpenAlex / Unpaywall
    3. Direct publisher download via university network (IP-based auth)

    At least one of doi, arxiv_id, or url must be provided.

    Args:
        doi: Paper DOI (e.g., "10.1038/s41928-023-01053-4").
        arxiv_id: arXiv paper ID (e.g., "2301.12345").
        url: Direct URL to a PDF.
        filename: Custom filename (without .pdf extension). Auto-generated from
                  title if not provided.

    Returns:
        Dict with "status", "filepath", and "method" used.
    """
    if not doi and not arxiv_id and not url:
        return {"status": "error", "message": "Provide at least one of: doi, arxiv_id, or url."}

    # Determine filename
    if not filename:
        if doi:
            # Try to get title for filename
            details = await get_paper_details(doi)
            title = details.get("title", "")
            if title:
                filename = _sanitize_filename(title)
            else:
                filename = _sanitize_filename(doi.replace("/", "_"))
        elif arxiv_id:
            filename = f"arxiv_{arxiv_id.replace('/', '_')}"
        else:
            filename = f"paper_{int(time.time())}"

    filepath = os.path.join(DOWNLOAD_DIR, f"{filename}.pdf")

    # Strategy 1: arXiv direct (always free)
    if arxiv_id:
        arxiv_url = f"https://arxiv.org/pdf/{arxiv_id}"
        if await _download_pdf(arxiv_url, filepath):
            return {"status": "success", "filepath": filepath, "method": "arxiv"}

    # Strategy 2: Direct URL provided
    if url:
        if await _download_pdf(url, filepath):
            return {"status": "success", "filepath": filepath, "method": "direct_url"}

    # Strategy 3: Resolve via DOI
    if doi:
        # Get all available URLs
        details = await get_paper_details(doi)
        pdf_urls = details.get("pdf_urls", [])

        # Try each URL in priority order
        for entry in pdf_urls:
            pdf_url = entry["url"]
            source = entry["source"]
            logger.info(f"Trying {source}: {pdf_url}")
            if await _download_pdf(pdf_url, filepath):
                return {"status": "success", "filepath": filepath, "method": source}

    return {
        "status": "failed",
        "message": (
            "Could not download PDF from any source. "
            "The paper may require authentication beyond IP-based access. "
            "Try accessing it through your university library portal directly."
        ),
        "doi": doi,
        "arxiv_id": arxiv_id,
    }


@mcp.tool()
async def search_and_download(
    query: str,
    max_papers: int = 5,
    download_available: bool = True,
) -> Dict[str, Any]:
    """
    Search for papers and optionally download all available PDFs.

    Combines search_papers + download_paper in one step. Useful for
    building a local library of papers on a topic.

    Args:
        query: Search query (e.g., "ion gated transistor reservoir computing").
        max_papers: Maximum number of papers to search for (default 5).
        download_available: If True, attempt to download PDFs for all results.

    Returns:
        Dict with search results and download status for each paper.
    """
    search_result = await search_papers(query, limit=max_papers)
    papers = search_result.get("results", [])

    if not download_available:
        return search_result

    download_results = []
    for paper in papers:
        doi = paper.get("doi", "")
        arxiv_id = paper.get("arxiv_id", "")
        oa_url = paper.get("open_access_pdf", "")
        title = paper.get("title", "")

        dl_result = await download_paper(
            doi=doi,
            arxiv_id=arxiv_id,
            url=oa_url,
            filename=_sanitize_filename(title) if title else "",
        )
        download_results.append({
            "title": title,
            "doi": doi,
            **dl_result,
        })

    return {
        "query": query,
        "papers_found": len(papers),
        "download_results": download_results,
        "download_dir": DOWNLOAD_DIR,
    }


@mcp.tool()
async def get_references(doi: str, limit: int = 20) -> Dict[str, Any]:
    """
    Get the reference list (bibliography) of a paper.

    Useful for citation chaining -- finding related papers from a known good paper.

    Args:
        doi: DOI of the paper whose references you want.
        limit: Max number of references to return (default 20).

    Returns:
        Dict with paper title and list of references with their DOIs.
    """
    url = f"https://api.semanticscholar.org/graph/v1/paper/DOI:{doi}"
    params = {
        "fields": "title,references.title,references.authors,references.year,references.externalIds,references.citationCount,references.openAccessPdf",
    }
    data = await _get_json(url, headers=_semantic_scholar_headers(), params=params)
    if not data:
        return {"error": f"Could not find paper with DOI {doi}"}

    refs = []
    for r in (data.get("references") or [])[:limit]:
        ext_ids = r.get("externalIds") or {}
        oa_pdf = (r.get("openAccessPdf") or {}).get("url", "")
        refs.append({
            "title": r.get("title", ""),
            "authors": ", ".join(a.get("name", "") for a in (r.get("authors") or [])[:3]),
            "year": r.get("year"),
            "doi": ext_ids.get("DOI", ""),
            "arxiv_id": ext_ids.get("ArXiv", ""),
            "citations": r.get("citationCount", 0),
            "open_access_pdf": oa_pdf,
        })

    return {
        "paper_title": data.get("title", ""),
        "doi": doi,
        "references": refs,
        "total": len(refs),
    }


@mcp.tool()
async def get_citations(doi: str, limit: int = 20) -> Dict[str, Any]:
    """
    Get papers that cite a given paper (forward citation search).

    Useful for finding recent work that builds on a known paper.

    Args:
        doi: DOI of the paper you want citations of.
        limit: Max number of citing papers to return (default 20).

    Returns:
        Dict with paper title and list of citing papers.
    """
    url = f"https://api.semanticscholar.org/graph/v1/paper/DOI:{doi}"
    params = {
        "fields": "title,citations.title,citations.authors,citations.year,citations.externalIds,citations.citationCount,citations.openAccessPdf",
    }
    data = await _get_json(url, headers=_semantic_scholar_headers(), params=params)
    if not data:
        return {"error": f"Could not find paper with DOI {doi}"}

    cites = []
    for c in (data.get("citations") or [])[:limit]:
        ext_ids = c.get("externalIds") or {}
        oa_pdf = (c.get("openAccessPdf") or {}).get("url", "")
        cites.append({
            "title": c.get("title", ""),
            "authors": ", ".join(a.get("name", "") for a in (c.get("authors") or [])[:3]),
            "year": c.get("year"),
            "doi": ext_ids.get("DOI", ""),
            "arxiv_id": ext_ids.get("ArXiv", ""),
            "citations": c.get("citationCount", 0),
            "open_access_pdf": oa_pdf,
        })

    # Sort by citation count descending
    cites.sort(key=lambda x: x.get("citations", 0), reverse=True)

    return {
        "paper_title": data.get("title", ""),
        "doi": doi,
        "citing_papers": cites,
        "total": len(cites),
    }


@mcp.tool()
async def check_university_access(test_doi: str = "10.1038/nature12066") -> Dict[str, Any]:
    """
    Test whether your current network has institutional access to publisher content.

    Attempts to download a known paywalled paper to verify university
    IP-based authentication is working.

    Args:
        test_doi: A DOI to test with. Default is a Nature paper.

    Returns:
        Dict with access status for each major publisher tested.
    """
    test_urls = {
        "Nature/Springer": f"https://link.springer.com/content/pdf/{test_doi}.pdf",
        "DOI_redirect": f"https://doi.org/{test_doi}",
    }

    results = {}
    async with httpx.AsyncClient(timeout=15, follow_redirects=True, headers=_headers()) as client:
        for name, url in test_urls.items():
            try:
                resp = await client.get(url)
                content_type = resp.headers.get("content-type", "")
                is_pdf = resp.content[:5] == b"%PDF-" or "pdf" in content_type.lower()
                results[name] = {
                    "status": resp.status_code,
                    "content_type": content_type,
                    "is_pdf": is_pdf,
                    "access": "FULL ACCESS" if is_pdf else "LANDING PAGE ONLY",
                    "size_bytes": len(resp.content),
                }
            except Exception as e:
                results[name] = {"status": "error", "error": str(e)}

    any_access = any(r.get("is_pdf") for r in results.values())
    return {
        "university_access_detected": any_access,
        "details": results,
        "recommendation": (
            "University IP access is working! Papers can be downloaded directly."
            if any_access else
            "No direct PDF access detected. You may need to connect to university VPN, "
            "or your institution may use a proxy (EZproxy). Set UNIVERSITY_PROXY env var if needed."
        ),
    }


if __name__ == "__main__":
    logger.info("Starting University Paper Access MCP Server")
    logger.info(f"Download directory: {DOWNLOAD_DIR}")
    mcp.run(transport="stdio")
