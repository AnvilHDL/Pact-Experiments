import os
import http.server
import socketserver
import webbrowser
from urllib.parse import parse_qs, urlparse
import json

PORT = 3000

def get_all_dot_files(directory):
    dot_files = []
    for root, _, files in os.walk(directory):
        for file in files:
            if file.endswith('.dot'):
                rel_path = os.path.relpath(os.path.join(root, file), directory)
                dot_files.append(rel_path)
    return dot_files

def read_dot_file(filepath):
    try:
        with open(filepath, 'r', encoding='utf-8') as f:
            return f.read()
    except Exception as e:
        return f"Error reading file: {str(e)}"

HTML_TEMPLATE = """
<!DOCTYPE html>
<html>
<head>
    <title>Interactive Graph Viewer</title>
    <meta charset="utf-8">
    <style>
        body {
            margin: 0;
            padding: 0;
            font-family: Arial, sans-serif;
            display: flex;
            flex-direction: column;
            height: 100vh;
            background: #1e1e1e;
            color: #fff;
        }
        #controls {
            background: #2d2d2d;
            padding: 15px;
            border-bottom: 2px solid #444;
            display: flex;
            align-items: center;
            gap: 15px;
            flex-wrap: wrap;
        }
        select, button, input {
            padding: 8px 15px;
            border: 1px solid #555;
            background: #3d3d3d;
            color: #fff;
            border-radius: 4px;
            font-size: 14px;
        }
        select {
            min-width: 300px;
        }
        input {
            min-width: 200px;
        }
        button {
            cursor: pointer;
        }
        button:hover {
            background: #4d4d4d;
        }
        button:disabled {
            opacity: 0.5;
            cursor: not-allowed;
        }
        #graph-container {
            flex: 1;
            position: relative;
            overflow: hidden;
            background: #252525;
        }
        #graph {
            width: 100%;
            height: 100%;
        }
        .controls-group {
            display: flex;
            gap: 10px;
            align-items: center;
        }
        #info {
            color: #aaa;
            font-size: 12px;
        }
        .loader {
            position: absolute;
            top: 50%;
            left: 50%;
            transform: translate(-50%, -50%);
            font-size: 18px;
            color: #aaa;
        }
        .node-highlighted {
            filter: drop-shadow(0 0 8px #ff0) drop-shadow(0 0 12px #ff0);
        }
        .node-matched {
            filter: drop-shadow(0 0 4px #0f0);
        }
        #search-results {
            position: absolute;
            top: 60px;
            left: 15px;
            background: #2d2d2d;
            border: 1px solid #555;
            border-radius: 4px;
            padding: 10px;
            max-height: 300px;
            overflow-y: auto;
            display: none;
            z-index: 1000;
            min-width: 250px;
        }
        #search-results.show {
            display: block;
        }
        .search-result-item {
            padding: 8px;
            cursor: pointer;
            border-bottom: 1px solid #444;
        }
        .search-result-item:hover {
            background: #3d3d3d;
        }
        .search-result-item:last-child {
            border-bottom: none;
        }
        .search-count {
            color: #888;
            font-size: 11px;
            padding: 5px 8px;
            border-bottom: 1px solid #444;
        }
        .search-highlight {
            color: #4af;
            font-weight: bold;
        }
    </style>
    <script src="https://cdnjs.cloudflare.com/ajax/libs/d3/7.8.5/d3.min.js"></script>
    <script src="https://cdnjs.cloudflare.com/ajax/libs/d3-graphviz/5.0.2/d3-graphviz.min.js"></script>
</head>
<body>
    <div id="controls">
        <div class="controls-group">
            <label for="file-select">Select Graph:</label>
            <select id="file-select">
                <option value="">-- Select a .dot file --</option>
            </select>
        </div>
        <div class="controls-group">
            <input type="text" id="search-input" placeholder="Search nodes (e.g., event 22)">
            <button id="search-btn">Search</button>
            <button id="prev-result" disabled>← Prev</button>
            <button id="next-result" disabled>Next →</button>
            <button id="clear-search">Clear</button>
        </div>
        <div class="controls-group">
            <button id="zoom-in">Zoom In</button>
            <button id="zoom-out">Zoom Out</button>
            <button id="reset-view">Reset View</button>
            <button id="fit-view">Fit to Screen</button>
        </div>
        <div id="info"></div>
    </div>
    <div id="search-results"></div>
    <div id="graph-container">
        <div id="graph"></div>
    </div>

    <script>
        let currentScale = 1;
        let currentTranslate = [0, 0];
        let graphviz = null;
        let searchResults = [];
        let currentResultIndex = -1;
        
        const graphContainer = d3.select("#graph");
        const fileSelect = document.getElementById("file-select");
        const infoDiv = document.getElementById("info");
        const searchInput = document.getElementById("search-input");
        const searchBtn = document.getElementById("search-btn");
        const prevBtn = document.getElementById("prev-result");
        const nextBtn = document.getElementById("next-result");
        const clearBtn = document.getElementById("clear-search");
        const searchResultsDiv = document.getElementById("search-results");

        // Initialize graphviz renderer
        function initGraphviz() {
            graphviz = d3.select("#graph").graphviz()
                .transition(function () {
                    return d3.transition("main")
                        .ease(d3.easeLinear)
                        .duration(500);
                })
                .on("end", function() {
                    setupZoomPan();
                });
        }

        // Setup zoom and pan
        function setupZoomPan() {
            const svg = d3.select("#graph svg");
            const g = svg.select("g");
            
            const zoom = d3.zoom()
                .scaleExtent([0.1, 10])
                .on("zoom", function(event) {
                    currentScale = event.transform.k;
                    currentTranslate = [event.transform.x, event.transform.y];
                    g.attr("transform", event.transform);
                    updateInfo();
                });
            
            svg.call(zoom);
            svg.zoomBehavior = zoom;
        }

        // Load available files
        async function loadFileList() {
            try {
                const response = await fetch('/files');
                const files = await response.json();
                
                fileSelect.innerHTML = '<option value="">-- Select a .dot file --</option>';
                files.forEach(file => {
                    const option = document.createElement('option');
                    option.value = file;
                    option.textContent = file;
                    fileSelect.appendChild(option);
                });
            } catch (e) {
                console.error("Error loading file list:", e);
            }
        }

        // Load and render graph
        async function loadGraph(filename) {
            if (!filename) return;
            
            clearSearch();
            infoDiv.textContent = "Loading...";
            graphContainer.html('<div class="loader">Loading graph...</div>');
            
            try {
                const response = await fetch(`/dot?file=${encodeURIComponent(filename)}`);
                const dotContent = await response.text();
                
                graphContainer.html('');
                initGraphviz();
                graphviz.renderDot(dotContent);
                
                infoDiv.textContent = `Loaded: ${filename}`;
            } catch (e) {
                console.error("Error loading graph:", e);
                infoDiv.textContent = "Error loading graph";
                graphContainer.html('<div class="loader">Error loading graph</div>');
            }
        }

        // Search for nodes
        function searchNodes() {
            const query = searchInput.value.trim().toLowerCase();
            if (!query) return;
            
            clearSearch();
            
            const svg = d3.select("#graph svg");
            const nodes = svg.selectAll(".node");
            
            searchResults = [];
            
            nodes.each(function() {
                const node = d3.select(this);
                const title = node.select("title").text().toLowerCase();
                const labels = node.selectAll("text");
                
                let labelText = "";
                labels.each(function() {
                    labelText += d3.select(this).text().toLowerCase() + " ";
                });
                
                const searchText = title + " " + labelText;
                
                if (searchText.includes(query)) {
                    searchResults.push({
                        node: this,
                        title: node.select("title").text(),
                        label: labelText.trim() || node.select("title").text()
                    });
                }
            });
            
            if (searchResults.length > 0) {
                currentResultIndex = 0;
                displaySearchResults();
                highlightAllResults();
                navigateToResult(0);
                updateNavigationButtons();
            } else {
                infoDiv.textContent = `No matches found for "${searchInput.value}"`;
                searchResultsDiv.classList.remove("show");
            }
        }

        // Display search results dropdown
        function displaySearchResults() {
            searchResultsDiv.innerHTML = "";
            
            const countDiv = document.createElement("div");
            countDiv.className = "search-count";
            countDiv.textContent = `Found ${searchResults.length} match${searchResults.length !== 1 ? 'es' : ''}`;
            searchResultsDiv.appendChild(countDiv);
            
            searchResults.forEach((result, index) => {
                const item = document.createElement("div");
                item.className = "search-result-item";
                
                const query = searchInput.value.trim();
                const displayText = result.label || result.title;
                const highlightedText = displayText.replace(
                    new RegExp(query, 'gi'),
                    match => `<span class="search-highlight">${match}</span>`
                );
                
                item.innerHTML = `${index + 1}. ${highlightedText}`;
                item.addEventListener("click", () => {
                    currentResultIndex = index;
                    navigateToResult(index);
                    updateNavigationButtons();
                });
                
                searchResultsDiv.appendChild(item);
            });
            
            searchResultsDiv.classList.add("show");
        }

        // Highlight all matching nodes
        function highlightAllResults() {
            searchResults.forEach(result => {
                d3.select(result.node).classed("node-matched", true);
            });
        }

        // Navigate to specific result
        function navigateToResult(index) {
            if (index < 0 || index >= searchResults.length) return;
            
            // Remove previous highlight
            d3.selectAll(".node").classed("node-highlighted", false);
            
            const result = searchResults[index];
            const node = d3.select(result.node);
            
            // Add highlight to current node
            node.classed("node-highlighted", true);
            
            // Get node position
            const bbox = result.node.getBBox();
            const centerX = bbox.x + bbox.width / 2;
            const centerY = bbox.y + bbox.height / 2;
            
            // Get container dimensions
            const container = document.getElementById("graph-container");
            const width = container.clientWidth;
            const height = container.clientHeight;
            
            // Calculate transform to center the node
            const scale = Math.min(2, Math.max(0.5, currentScale)); // Zoom to a reasonable level
            const x = width / 2 - centerX * scale;
            const y = height / 2 - centerY * scale;
            
            // Apply transform
            const svg = d3.select("#graph svg");
            if (svg.zoomBehavior) {
                svg.transition().duration(750).call(
                    svg.zoomBehavior.transform,
                    d3.zoomIdentity.translate(x, y).scale(scale)
                );
            }
            
            infoDiv.textContent = `Match ${index + 1}/${searchResults.length}: ${result.title}`;
        }

        // Update navigation button states
        function updateNavigationButtons() {
            prevBtn.disabled = currentResultIndex <= 0;
            nextBtn.disabled = currentResultIndex >= searchResults.length - 1;
        }

        // Clear search
        function clearSearch() {
            searchResults = [];
            currentResultIndex = -1;
            d3.selectAll(".node").classed("node-matched", false).classed("node-highlighted", false);
            searchResultsDiv.classList.remove("show");
            searchResultsDiv.innerHTML = "";
            updateNavigationButtons();
            
            const filename = fileSelect.value;
            if (filename) {
                infoDiv.textContent = `Loaded: ${filename} | Zoom: ${(currentScale * 100).toFixed(0)}%`;
            }
        }

        // Event listeners
        searchBtn.addEventListener("click", searchNodes);
        
        searchInput.addEventListener("keypress", (e) => {
            if (e.key === "Enter") {
                searchNodes();
            }
        });
        
        searchInput.addEventListener("input", () => {
            if (!searchInput.value.trim()) {
                clearSearch();
            }
        });

        prevBtn.addEventListener("click", () => {
            if (currentResultIndex > 0) {
                currentResultIndex--;
                navigateToResult(currentResultIndex);
                updateNavigationButtons();
            }
        });

        nextBtn.addEventListener("click", () => {
            if (currentResultIndex < searchResults.length - 1) {
                currentResultIndex++;
                navigateToResult(currentResultIndex);
                updateNavigationButtons();
            }
        });

        clearBtn.addEventListener("click", () => {
            searchInput.value = "";
            clearSearch();
        });

        // Click outside to close search results
        document.addEventListener("click", (e) => {
            if (!searchResultsDiv.contains(e.target) && 
                e.target !== searchInput && 
                e.target !== searchBtn) {
                searchResultsDiv.classList.remove("show");
            }
        });

        // Zoom controls
        document.getElementById("zoom-in").addEventListener("click", () => {
            const svg = d3.select("#graph svg");
            if (svg.zoomBehavior) {
                svg.transition().duration(300).call(
                    svg.zoomBehavior.scaleBy, 1.3
                );
            }
        });

        document.getElementById("zoom-out").addEventListener("click", () => {
            const svg = d3.select("#graph svg");
            if (svg.zoomBehavior) {
                svg.transition().duration(300).call(
                    svg.zoomBehavior.scaleBy, 0.7
                );
            }
        });

        document.getElementById("reset-view").addEventListener("click", () => {
            const svg = d3.select("#graph svg");
            if (svg.zoomBehavior) {
                svg.transition().duration(300).call(
                    svg.zoomBehavior.transform, d3.zoomIdentity
                );
            }
        });

        document.getElementById("fit-view").addEventListener("click", () => {
            const svg = d3.select("#graph svg");
            const g = svg.select("g");
            const bbox = g.node().getBBox();
            const container = document.getElementById("graph-container");
            
            const width = container.clientWidth;
            const height = container.clientHeight;
            const scale = 0.9 * Math.min(width / bbox.width, height / bbox.height);
            
            if (svg.zoomBehavior) {
                svg.transition().duration(500).call(
                    svg.zoomBehavior.transform,
                    d3.zoomIdentity
                        .translate(width / 2, height / 2)
                        .scale(scale)
                        .translate(-bbox.x - bbox.width / 2, -bbox.y - bbox.height / 2)
                );
            }
        });

        function updateInfo() {
            const filename = fileSelect.value;
            if (filename && searchResults.length === 0) {
                infoDiv.textContent = `Loaded: ${filename} | Zoom: ${(currentScale * 100).toFixed(0)}%`;
            }
        }

        fileSelect.addEventListener("change", (e) => {
            loadGraph(e.target.value);
        });

        // Initialize
        loadFileList();
    </script>
</body>
</html>
"""

class GraphHandler(http.server.SimpleHTTPRequestHandler):
    def __init__(self, *args, base_dir=None, **kwargs):
        self.base_dir = base_dir
        super().__init__(*args, **kwargs)
    
    def do_GET(self):
        parsed = urlparse(self.path)
        
        if parsed.path == '/':
            self.send_response(200)
            self.send_header('Content-type', 'text/html')
            self.end_headers()
            self.wfile.write(HTML_TEMPLATE.encode())
        
        elif parsed.path == '/files':
            files = get_all_dot_files(self.base_dir)
            self.send_response(200)
            self.send_header('Content-type', 'application/json')
            self.end_headers()
            self.wfile.write(json.dumps(files).encode())
        
        elif parsed.path == '/dot':
            query = parse_qs(parsed.query)
            filename = query.get('file', [''])[0]
            
            if filename:
                filepath = os.path.join(self.base_dir, filename)
                if os.path.exists(filepath) and filepath.endswith('.dot'):
                    content = read_dot_file(filepath)
                    self.send_response(200)
                    self.send_header('Content-type', 'text/plain')
                    self.end_headers()
                    self.wfile.write(content.encode())
                else:
                    self.send_error(404, "File not found")
            else:
                self.send_error(400, "No file specified")
        else:
            self.send_error(404)

def main():
    directory = os.path.dirname(os.path.abspath(__file__))
    
    handler = lambda *args, **kwargs: GraphHandler(*args, base_dir=directory, **kwargs)
    
    with socketserver.TCPServer(("", PORT), handler) as httpd:
        url = f"http://localhost:{PORT}"
        print(f"🚀 Interactive Graph Viewer running at {url}")
        print(f"📁 Serving .dot files from: {directory}")
        print(f"🔍 Search features: Type node names and press Enter")
        print(f"Press Ctrl+C to stop the server")
        
        webbrowser.open(url)
        
        try:
            httpd.serve_forever()
        except KeyboardInterrupt:
            print("\n👋 Server stopped")

if __name__ == "__main__":
    main()