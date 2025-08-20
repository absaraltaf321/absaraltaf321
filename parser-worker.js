// parser-worker.js

// 1. Import scripts
try {
    importScripts(
        'https://cdn.jsdelivr.net/npm/marked/marked.min.js',
        'https://cdnjs.cloudflare.com/ajax/libs/highlight.js/11.9.0/highlight.min.js',
        'https://cdnjs.cloudflare.com/ajax/libs/jszip/3.10.1/jszip.min.js'
    );
} catch (e) {
    console.error('Worker script import failed:', e);
    postMessage({ type: 'error', message: 'Failed to load parsing libraries.' });
}

// 2. Setup message listener
self.onmessage = async (event) => {
    const { file } = event.data;

    if (!self.marked || !self.hljs || !self.JSZip) {
         postMessage({ type: 'error', message: 'Parsing libraries not available in worker.' });
         return;
    }

    try {
        let result;
        if (file.type === 'epub') {
            result = await parseEpub(file);
        } else {
            result = parseMarkdown(file);
        }
        postMessage({ type: 'success', payload: result });
    } catch (error) {
        console.error('Worker parsing error:', error);
        postMessage({ type: 'error', message: 'Failed to parse file: ' + error.message });
    }
};

// ===== MARKDOWN PARSING =====
function configureMarked() {
    const renderer = new self.marked.Renderer();
    const originalHeading = renderer.heading.bind(renderer);

    renderer.code = (code, lang) => {
        const language = lang || 'text';
        const highlighted = self.hljs.getLanguage(lang)
            ? self.hljs.highlight(String(code || ''), { language, ignoreIllegals: true }).value
            : self.hljs.highlightAuto(String(code || '')).value;
        return '<pre><div class="code-header"><span>' + language + '</span><button class="copy-btn" title="Copy code">📋 Copy</button></div><code class="hljs ' + language + '">' + highlighted + '</code></pre>';
    };

    renderer.image = (href, title, text) => '<img src="' + href + '" alt="' + text + '" title="' + (title || '') + '" loading="lazy">';

    renderer.blockquote = (quote) => {
        const authorMatch = quote.match(/<p>—(.*?)<\/p>\s*$/);
        if (authorMatch) {
            const content = quote.replace(authorMatch[0], '');
            const author = authorMatch[1].trim();
            return '<blockquote>' + content + '<p class="quote-author">— ' + author + '</p></blockquote>';
        }
        return '<blockquote>' + quote + '</blockquote>';
    };

    renderer.heading = (text, level, raw) => {
        const anchor = String(raw || '').toLowerCase().replace(/[^\w\u4e00-\u9fa5]+/g, '-');
        const bookmarkIcon = '<span class="bookmark-icon" title="Bookmark section">☆</span>';
        const headingHtml = originalHeading(text, level, raw, self.marked);
        return headingHtml.replace('id="' + anchor + '"', 'id="' + anchor + '">' + bookmarkIcon);
    };

    self.marked.setOptions({ renderer, breaks: true, gfm: true });
}

function parseMarkdown(file) {
    configureMarked();
    const html = self.marked.parse(String(file.content || ''));
    return { html, type: 'markdown' };
}

// ===== EPUB PARSING =====
const arrayBufferToBase64 = (buffer) => {
    let binary = '';
    const bytes = new Uint8Array(buffer);
    for (let i = 0; i < bytes.byteLength; i++) {
        binary += String.fromCharCode(bytes[i]);
    }
    return self.btoa(binary);
};

function getMimeTypeFromPath(path) {
    const extension = path.split('.').pop().toLowerCase();
    const mimeTypes = {
        'jpg': 'image/jpeg', 'jpeg': 'image/jpeg', 'png': 'image/png',
        'gif': 'image/gif', 'svg': 'image/svg+xml', 'webp': 'image/webp'
    };
    return mimeTypes[extension] || 'application/octet-stream';
}

function resolveEpubPath(htmlFilePath, relativeAssetPath) {
    const pathParts = htmlFilePath.split('/');
    pathParts.pop();
    const assetParts = relativeAssetPath.split('/');
    for (const part of assetParts) {
        if (part === '..') {
            if (pathParts.length > 0) pathParts.pop();
        } else if (part !== '.' && part !== '') {
            pathParts.push(part);
        }
    }
    return pathParts.join('/');
}

function scopeCss(css, scope) {
    const parts = css.split(/([{}])/);
    let depth = 0;
    for (let i = 0; i < parts.length; i++) {
        if (parts[i] === '{') {
            if (depth === 0) {
                const selectorGroup = parts[i - 1];
                if (!selectorGroup.trim().startsWith('@')) {
                    const selectors = selectorGroup.split(',').map(s => {
                        const trimmed = s.trim();
                        if (trimmed.toLowerCase() === 'body' || trimmed.toLowerCase() === 'html') return scope;
                        return scope + ' ' + trimmed;
                    });
                    parts[i - 1] = selectors.join(', ');
                }
            }
            depth++;
        } else if (parts[i] === '}') {
            depth--;
        }
    }
    return parts.join('');
}

async function aggregateEpubContent(zip, manifest, spine) {
    let aggregatedHtml = '';
    let aggregatedCss = '';
    const parser = new self.DOMParser(); // FIXED

    for (const id in manifest) {
        const item = manifest[id];
        if (item.mediaType === 'text/css') {
            const cssFile = zip.file(decodeURIComponent(item.href));
            if (cssFile) {
                const rawCss = await cssFile.async('string');
                aggregatedCss += scopeCss(rawCss, '#epub-content') + '\n';
            }
        }
    }

    for (const idref of spine) {
        const manifestItem = manifest[idref];
        if (!manifestItem || !manifestItem.href) continue;
        const htmlFile = zip.file(decodeURIComponent(manifestItem.href));
        if (!htmlFile) continue;
        
        const rawHtml = await htmlFile.async('string');
        const htmlDoc = parser.parseFromString(rawHtml, 'text/html');

        htmlDoc.querySelectorAll('script, link[rel="stylesheet"]').forEach(el => el.remove());
        
        const assetTags = htmlDoc.querySelectorAll('img[src], image[href]');
        for (const tag of assetTags) {
            const attr = tag.hasAttribute('src') ? 'src' : 'href';
            const relativePath = tag.getAttribute(attr);
            if (!relativePath || relativePath.startsWith('data:')) continue;

            try {
                const absolutePath = resolveEpubPath(manifestItem.href, relativePath);
                const assetFile = zip.file(decodeURIComponent(absolutePath));
                if (assetFile) {
                    const buffer = await assetFile.async('arraybuffer');
                    const mimeType = getMimeTypeFromPath(absolutePath);
                    const base64 = arrayBufferToBase64(buffer);
                    tag.setAttribute(attr, 'data:' + mimeType + ';base64,' + base64);
                }
            } catch (e) {
                console.warn('Could not process asset ' + relativePath + ': ' + e);
            }
        }
        
        if (htmlDoc.body) {
            aggregatedHtml += htmlDoc.body.innerHTML;
        }
    }

    return { html: aggregatedHtml, css: aggregatedCss };
}


async function parseEpub(file) {
    const zip = await self.JSZip.loadAsync(file.content);
    const containerXmlFile = zip.file("META-INF/container.xml");
    if (!containerXmlFile) throw new Error("META-INF/container.xml not found.");
    const containerXml = await containerXmlFile.async("string");
    const parser = new self.DOMParser(); // FIXED
    const containerDoc = parser.parseFromString(containerXml, "application/xml");
    const opfPath = containerDoc.getElementsByTagName("rootfile")[0]?.getAttribute("full-path");
    if (!opfPath) throw new Error("Could not find .opf file path in container.xml");
    
    const basePath = opfPath.includes('/') ? opfPath.substring(0, opfPath.lastIndexOf('/') + 1) : "";

    const opfFile = zip.file(opfPath);
    if (!opfFile) throw new Error('.opf file not found at path: ' + opfPath);
    const opfXml = await opfFile.async("string");
    const opfDoc = parser.parseFromString(opfXml, "application/xml");

    const manifest = {};
    const manifestItems = opfDoc.getElementsByTagName("item");
    for (const item of manifestItems) {
        const href = item.getAttribute("href");
        if (href) {
            manifest[item.getAttribute("id")] = {
                href: basePath + href,
                mediaType: item.getAttribute("media-type"),
                id: item.getAttribute("id")
            };
        }
    }

    const spine = [];
    const spineItems = opfDoc.getElementsByTagName("itemref");
    for (const item of spineItems) {
        spine.push(item.getAttribute("idref"));
    }

    const content = await aggregateEpubContent(zip, manifest, spine);
    
    return { ...content, type: 'epub' };
}
