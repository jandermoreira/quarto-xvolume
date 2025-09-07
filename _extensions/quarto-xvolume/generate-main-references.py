#!/usr/bin/python3
"""
Program to combine cross-references from multiple JSON files.
"""


import os
import json

def join_crossrefs(parent_dir="."):
    combined = {}
    for entry in os.listdir(parent_dir):
        subdir = os.path.join(parent_dir, entry)
        if os.path.isdir(subdir):
            crossref_file = os.path.join(subdir, "crossrefs.json")
            if os.path.isfile(crossref_file):
                try:
                    with open(crossref_file, "r", encoding="utf-8") as f:
                        data = json.load(f)
                    for key, value in data.items():
                        if key in combined:
                            print(f"Warning: duplicate reference '{key}' found in {crossref_file}. Overwriting.")
                        combined[key] = value
                except Exception as e:
                    print(f"Error reading {crossref_file}: {e}")
    return combined

if __name__ == "__main__":
    parent = ".."
    result = join_crossrefs(parent)
    with open("../crossrefs.json", "w", encoding="utf-8") as out:
        json.dump(result, out, indent=2, ensure_ascii=False)
