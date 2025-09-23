#!/usr/bin/python3
"""
Program to collect cross-references from .qmd files in a directory tree
and output them to a JSON file.
"""

import os
import re
import json
import yaml

def get_volume(subdir):
    quarto_file = os.path.join(subdir, "_quarto.yml")
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

def collect_crossrefs_in_subdir(subdir):
    crossrefs = {}
    volume = get_volume(subdir)
    pattern = re.compile(r"^(#+)\s+(.*?)\s+\{#([a-zA-Z0-9\-_]+)\}", re.MULTILINE)

    for root, _, filenames in os.walk(subdir):
        for filename in filenames:
            if filename.endswith(".qmd") or filename.endswith(".md"):
                print(f"Checking file: {root + '/' + filename}")
                filepath = os.path.join(root, filename)
                try:
                    with open(filepath, "r", encoding="utf-8") as f:
                        content = f.read()
                    matches = pattern.findall(content)
                    for hashes, title_text, ref in matches:
                        if ref == "refs":
                            continue

                        level = len(hashes)  # número de # indica o nível do título
                        rel_path = os.path.relpath(filepath, subdir)
                        html_file = os.path.splitext(rel_path)[0] + ".html"
                        crossrefs[ref] = {
                            "text": title_text.strip(),
                            "volume": volume,
                            "level": level,
                            "file": html_file
                        }
                except Exception as e:
                    print(f"Error reading {filepath}: {e}")
    return crossrefs

def collect_all_crossrefs(root_dir="."):
    all_crossrefs = {}
    for entry in os.listdir(root_dir):
        subdir = os.path.join(root_dir, entry)
        if os.path.isdir(subdir) and os.path.isfile(os.path.join(subdir, "_quarto.yml")):
            print(f"Processing entry: {subdir}")
            refs = collect_crossrefs_in_subdir(subdir)
            all_crossrefs.update(refs)
    return all_crossrefs

if __name__ == "__main__":
    crossrefs = collect_all_crossrefs("..")
    with open("../crossrefs.json", "w", encoding="utf-8") as out:
        json.dump(crossrefs, out, indent=2, ensure_ascii=False)
