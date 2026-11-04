
const searchForm = document.getElementById("search-form");
const searchInput = document.getElementById("search-input");
const searchMessage = document.getElementById("search-message");
const searchResults = document.getElementById("search-results");

if (searchForm && searchInput && searchMessage && searchResults) {
    searchForm.addEventListener("submit", async function (event) {
        event.preventDefault();

        const query = searchInput.value.trim();

        if (!query) {
            searchMessage.textContent =
                "Please enter a topic, paper title, or research concept.";
            searchInput.focus();
            searchResults.replaceChildren();
            return;
        }

        searchMessage.textContent = "Searching your research database...";
        searchResults.replaceChildren();

        try {
            const response = await fetch(
                `/api/search?q=${encodeURIComponent(query)}`
            );

            const data = await response.json();

            if (!response.ok) {
                throw new Error(data.error || "Search request failed.");
            }

            if (!data.results || data.results.length === 0) {
                searchMessage.textContent =
                `No relevant papers found for "${query}". Try a broader topic or different search terms.`;
                return;
        }

            searchMessage.textContent =
                `Found ${data.count} ${data.count === 1 ? "paper" : "papers"} for "${query}".`;

            data.results.forEach((paper) => {
                const card = document.createElement("article");
                card.className = "search-result-card";

                const heading = document.createElement("h3");
                heading.textContent = paper.title || "Untitled paper";
                card.appendChild(heading);

                const metadata = document.createElement("p");
                metadata.className = "search-result-meta";

                const details = [];
                if (paper.publication_year) {
                    details.push(String(paper.publication_year));
                }
                details.push(`Paper ID: ${paper.paper_id}`);
                if (typeof paper.relevance === "number") {
                details.push(
                `Similarity: ${(paper.relevance * 100).toFixed(1)}%`
                );
        }

        metadata.textContent = details.join(" · ");
        card.appendChild(metadata);

                if (paper.abstract) {
                    const abstract = document.createElement("p");
                    abstract.className = "search-result-abstract";
                    abstract.textContent = paper.abstract;
                    card.appendChild(abstract);
                }

                if (paper.matching_chunk) {
                    const chunkLabel = document.createElement("p");
                    chunkLabel.className = "search-result-label";
                    chunkLabel.textContent = "Matching research excerpt";
                    card.appendChild(chunkLabel);

                    const chunk = document.createElement("p");
                    chunk.className = "search-result-chunk";
                    chunk.textContent = paper.matching_chunk;
                    card.appendChild(chunk);
                }

                if (paper.doi) {
                    const doi = document.createElement("p");
                    doi.className = "search-result-doi";
                    doi.textContent = `DOI: ${paper.doi}`;
                    card.appendChild(doi);
                }

                searchResults.appendChild(card);
            });
        } catch (error) {
            console.error("Research search failed:", error);
            searchMessage.textContent =
                "Search failed. Check the Flask server and try again.";
        }
    });
}

document.querySelectorAll(".nav-link").forEach(function (link) {
    link.addEventListener("click", function () {
        document.querySelectorAll(".nav-link").forEach(function (item) {
            item.classList.remove("active");
        });

        link.classList.add("active");
    });
});

async function loadDashboardStats() {
    const statElements = {
        total_papers: document.getElementById("total-papers"),
        research_chunks: document.getElementById("research-chunks"),
        citation_links: document.getElementById("citation-links"),
        audit_events: document.getElementById("audit-events"),
    };

    try {
        const response = await fetch("/api/stats");

        if (!response.ok) {
            throw new Error("Statistics request failed");
        }

        const stats = await response.json();

        for (const [key, element] of Object.entries(statElements)) {
            if (element) {
                element.textContent = stats[key] ?? "—";
            }
        }

        document.querySelectorAll(".stat-card span").forEach((element) => {
            element.textContent = "Live database count";
        });
    } catch (error) {
        console.error("Could not load dashboard statistics:", error);

        document.querySelectorAll(".stat-card span").forEach((element) => {
            element.textContent = "Unable to load data";
        });
    }
}

loadDashboardStats();


async function loadPaperLibrary() {
    const paperList = document.getElementById("paper-list");
    const paperFilter = document.getElementById("paper-filter");
    const libraryCount = document.getElementById("library-count");
    const libraryMessage = document.getElementById("library-message");

    if (!paperList || !paperFilter || !libraryCount || !libraryMessage) {
        return;
    }

    let papers = [];

    function renderPapers() {
        const query = paperFilter.value.trim().toLowerCase();

        const filteredPapers = papers.filter((paper) => {
            const searchableText = [
                paper.title,
                paper.abstract,
                paper.doi,
                paper.publication_year
            ].filter(Boolean).join(" ").toLowerCase();

            return searchableText.includes(query);
        });

        paperList.replaceChildren();
        libraryCount.textContent =
            `${filteredPapers.length} ${filteredPapers.length === 1 ? "PAPER" : "PAPERS"}`;

        if (filteredPapers.length === 0) {
            libraryMessage.textContent = papers.length
                ? "No papers match your search. Try another title, topic, or DOI."
                : "Your research library is empty.";
            libraryMessage.hidden = false;
            return;
        }

        libraryMessage.hidden = true;

        filteredPapers.forEach((paper) => {
            const card = document.createElement("article");
            card.className = "paper-card";

            const heading = document.createElement("h3");
            heading.textContent = paper.title || "Untitled paper";
            card.appendChild(heading);

            const metadata = document.createElement("p");
            metadata.className = "paper-meta";

            const details = [];
            if (paper.publication_year) {
                details.push(String(paper.publication_year));
            }
            details.push(`Paper ID: ${paper.paper_id}`);
            metadata.textContent = details.join(" · ");
            card.appendChild(metadata);

            if (paper.abstract) {
                const abstract = document.createElement("p");
                abstract.className = "paper-abstract";
                abstract.textContent = paper.abstract;
                card.appendChild(abstract);
            }

            if (paper.doi) {
                const doi = document.createElement("p");
                doi.className = "paper-doi";
                doi.textContent = `DOI: ${paper.doi}`;
                card.appendChild(doi);
            }

            paperList.appendChild(card);
        });
    }

    paperFilter.addEventListener("input", renderPapers);

    try {
        const response = await fetch("/api/papers");

        if (!response.ok) {
            throw new Error(`Request failed with status ${response.status}`);
        }

        const data = await response.json();
        papers = Array.isArray(data.papers) ? data.papers : [];

        renderPapers();
    } catch (error) {
        console.error("Could not load Paper Library:", error);
        libraryCount.textContent = "UNAVAILABLE";
        libraryMessage.textContent =
            "Unable to load papers. Check the Flask server and try refreshing the page.";
        libraryMessage.hidden = false;
    }
}

loadPaperLibrary();
async function checkDatabaseHealth() {
    const statusText = document.getElementById("database-status-text");
    const statusDot = document.getElementById("database-status-dot");

    try {
        const response = await fetch("/api/health");
        const health = await response.json();

        if (!response.ok || health.connected !== true) {
            throw new Error("Database unavailable");
        }

        statusText.textContent = "PostgreSQL connected";
        statusDot.classList.add("connected");
        statusDot.classList.remove("disconnected");

    } catch (error) {
        statusText.textContent = "PostgreSQL disconnected";
        statusDot.classList.add("disconnected");
        statusDot.classList.remove("connected");

        console.error("Database health check failed:", error);
    }
}

checkDatabaseHealth();
setInterval(checkDatabaseHealth, 30000);

async function loadCitations() {
    const citationList = document.getElementById("citation-list");

    if (!citationList) return;

    try {
        const response = await fetch("/api/citations");

        if (!response.ok) {
            throw new Error("Unable to load citations.");
        }

        const data = await response.json();
        citationList.replaceChildren();

        if (!data.citations || data.citations.length === 0) {
            citationList.textContent = "No citation records found.";
            return;
        }

        data.citations.forEach((citation) => {
            const card = document.createElement("article");
            card.className = "data-card";

            const heading = document.createElement("h3");
            heading.textContent =
                citation.citing_title + " → " + citation.cited_title;

            const context = document.createElement("p");
            context.textContent =
                citation.citation_context || "No citation context available.";

            const metadata = document.createElement("p");
            metadata.textContent =
                `Paper ${citation.citing_paper_id} cites Paper ${citation.cited_paper_id}`;

            card.append(heading, context, metadata);
            citationList.appendChild(card);
        });
    } catch (error) {
        console.error("Citation loading failed:", error);
        citationList.textContent = "Unable to load citation records.";
    }
}

async function loadAuditHistory() {
    const auditList = document.getElementById("audit-list");

    if (!auditList) return;

    try {
        const response = await fetch("/api/audit");

        if (!response.ok) {
            throw new Error("Unable to load audit history.");
        }

        const data = await response.json();
        auditList.replaceChildren();

        if (!data.events || data.events.length === 0) {
            auditList.textContent = "No audit events recorded yet.";
            return;
        }

        data.events.forEach((event) => {
            const card = document.createElement("article");
            card.className = "data-card";

            const heading = document.createElement("h3");
            heading.textContent = `${event.action_type} — ${event.new_title || event.old_title || "Paper record"}`;

            const details = document.createElement("p");
            details.textContent = `Paper ID: ${event.paper_id}`;

            const timestamp = document.createElement("p");
            timestamp.textContent = event.changed_at
                ? new Date(event.changed_at).toLocaleString()
                : "Time unavailable";

            card.append(heading, details, timestamp);
            auditList.appendChild(card);
        });
    } catch (error) {
        console.error("Audit history loading failed:", error);
        auditList.textContent = "Unable to load audit history.";
    }
}

loadCitations();
loadAuditHistory();
