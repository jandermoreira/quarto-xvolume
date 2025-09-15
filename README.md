# quarto-xvolume
A Quarto extension to manage multi-volume books in Quarto.

## Organization

All volumes should be in the same parent folder, like:

```
my-book/  (base folder)
  _extensions/
    quarto-xvolume
  authors/
    author1.qmd
    author2.qmd
  my-book-vol1/
    _extensions/  (symlink or actual folder)
    _quarto.yml
    index.qmd
    chapter1.qmd
    chapter2.qmd
  my-book-vol2/
    _extensions/  (symlink or actual folder)
    _quarto.yml
    index.qmd
    chapter1.qmd
    chapter2.qmd
```

## Installation and Usage

**First method**

Run the following command for each volume:

```bash
quarto install extension jandermoreira/quarto-xvolume
```

**Second method** (prefered)

Run the following command in the parent folder of all volumes and create symlinks to each volume:

```bash
quarto install extension jandermoreira/quarto-xvolume
```

```bash
cd my-book-vol1
ln -s ../_extensions
```

## Configuration of each volume

Edit your `_quarto.yml` files:

```yaml
project:
  type: book
  # Add the pre-render script
  pre-render: _extensions/jandermoreira/quarto-xvolume/collect-all-references.py  

filters:
    # Add the quarto-xvolume filter
  - quarto-xvolume

quarto-xvolume:
    # Add the location where the volumes will be hosted
    # without the volume number at the end
    base-url: "https://example.com/my-book-vol" 

book:
    title: "My Book Title - Volume 2"
    # Add the volume number
    volume: 2
```


## Warnings

- The `collect-all-references.py` script always runs before rendering the book to ensure all references are collected.
- The cross-references labels must be unique across all volumes to avoid conflicts.
- The `base-url` must be the same across all volumes to ensure correct linking.
- The `volume` number must be set to a number (1, 2, 3, ...) for each volume. Do not use non-numeric values such as I, II, III, A, B, C, etc.
- The `volume` number must be unique for each volume, of course.

## About authors and their photos
Author files must be in the `authors` folder in the parent folder of all volumes.
Each author file must have the following structure:

```yaml
---
name: First name
surname: Last name
middle_name: Middle name (optional)
description: Short description of the author
type: author, editor, organizer, etc. # (not used yet)
photo: path/to/photo.jpg 
email: email
contribution: ["@sec-label1", "@sec-label2"] # (optional, list of chapters where the author contributed)

## Requirements
- Python 3 to run the script