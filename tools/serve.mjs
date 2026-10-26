// A tiny static file server for the repo root, so every build can be opened
// at the same kind of address the Lab page will use:
//   /apps/<name>/dist/index.html  (each build)   /samples/…  (the shared kit)
//
// Usage: node tools/serve.mjs [port]     (default 4173)

import { createServer } from "node:http";
import { readFile, stat } from "node:fs/promises";
import { extname, join, normalize } from "node:path";
import { fileURLToPath } from "node:url";
import { gzipSync } from "node:zlib";

const REPO_ROOT = fileURLToPath(new URL("..", import.meta.url));
const PORT = Number(process.argv[2] ?? 4173);

const CONTENT_TYPES = {
	".html": "text/html; charset=utf-8", ".js": "text/javascript", ".mjs": "text/javascript",
	".css": "text/css", ".json": "application/json", ".wav": "audio/wav", ".svg": "image/svg+xml", ".map": "application/json"
};

/** The file a URL asks for, kept inside the repo; a folder means its index.html. */
async function fileFor(url) {
	const path = normalize(decodeURIComponent(new URL(url, "http://local").pathname));
	const file = join(REPO_ROOT, path);
	if (!file.startsWith(REPO_ROOT)) return null;
	const info = await stat(file).catch(() => null);
	if (!info) return null;
	return info.isDirectory() ? join(file, "index.html") : file;
}

/** Text is gzipped when the browser accepts it, as any real host would, so load times are realistic. */
function compressedIfWanted(request, body, type) {
	const isText = /text|javascript|json|svg/.test(type);
	const accepted = /gzip/.test(request.headers["accept-encoding"] ?? "");
	return isText && accepted ? { body: gzipSync(body), encoding: { "content-encoding": "gzip" } } : { body, encoding: {} };
}

async function respond(request, response) {
	const file = await fileFor(request.url);
	const found = file && (await readFile(file).catch(() => null));
	if (!found) return response.writeHead(404).end("Not found");
	const type = CONTENT_TYPES[extname(file)] ?? "application/octet-stream";
	const { body, encoding } = compressedIfWanted(request, found, type);
	response.writeHead(200, { "content-type": type, "cache-control": "no-cache", ...encoding });
	response.end(body);
}

createServer(respond).listen(PORT, () => console.log(`Serving the repo at http://localhost:${PORT}/`));
