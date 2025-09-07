#!/usr/bin/python3
"""
Program to collect cross-references from .qmd files in a directory tree
and output them to a JSON file.
"""

import os
import re
import json
import yaml

def get_volume(root_dir="."):
    quarto_file = os.path.join(root_dir, "_quarto.yml")
    if not os.path.isfile(quarto_file):
        return None
    try:
        with open(quarto_file, "r", encoding="utf-8") as f:
            data = yaml.safe_load(f)
        if isinstance(data, dict) and "book" in data:
            return data["book"].get("volume")
        return None
    except Exception as e:
        print(f"Error reading {quarto_file}: {e}")
        return None

def collect_crossrefs(root_dir="."):
    crossrefs = {}
    volume = get_volume(root_dir)
    pattern = re.compile(r"^(#+)\s+(.*?)\s+\{#([a-zA-Z0-9\-_]+)\}", re.MULTILINE)

    for dirpath, _, filenames in os.walk(root_dir):
        for filename in filenames:
            if filename.endswith(".qmd"):
                filepath = os.path.join(dirpath, filename)
                try:
                    with open(filepath, "r", encoding="utf-8") as f:
                        content = f.read()
                    matches = pattern.findall(content)
                    for _, title_text, ref in matches:
                        if ref == "refs":
                            continue
                        
                        html_file = os.path.splitext(filepath)[0] + ".html"
                        crossrefs[ref] = {
                            "file": html_file,
                            "volume": volume,
                            "text": title_text.strip()
                        }
                except Exception as e:
                    print(f"Error reading {filepath}: {e}")
    return crossrefs

if __name__ == "__main__":
    crossrefs = collect_crossrefs(".")
    with open("crossrefs.json", "w", encoding="utf-8") as out:
        json.dump(crossrefs, out, indent=2, ensure_ascii=False)
