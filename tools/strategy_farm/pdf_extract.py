"""Extract text from a PDF using PyMuPDF. Usage: pdf_extract.py <path> [max_pages]"""
import sys
import fitz

def extract(path, max_pages=None):
    doc = fitz.open(path)
    total = doc.page_count
    limit = min(total, max_pages) if max_pages else total
    print(f"=== {path} | {total} pages | showing {limit} ===\n")
    for i in range(limit):
        text = doc[i].get_text()
        if text.strip():
            print(f"--- Page {i+1} ---")
            print(text.encode("utf-8", errors="replace").decode("utf-8"))

if __name__ == "__main__":
    path = sys.argv[1]
    mp = int(sys.argv[2]) if len(sys.argv) > 2 else None
    extract(path, mp)
