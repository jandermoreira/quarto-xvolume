# quarto-xvolume
A Quarto extension to manage multi-volume books.

## How to use

To install, run the following command for each volume[^1]:

[^1]: A single installation is enough if you create a symlink to all other volumes.
 
```bash
quarto install extension jandermoreira/quarto-xvolume
```

Edit your `_quarto.yml` files:

```yaml
project:
  type: book
  pre-render: _extensions/jandermoreira/quarto-xvolume/
  # Add the pre-render script
  collect-all-references.py  

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

## Organization

All volumes should be in the same parent folder, like:

```
my-book/
  my-book-vol1/
    _quarto.yml
    index.qmd
    chapter1.qmd
    chapter2.qmd
  my-book-vol2/
    _quarto.yml
    index.qmd
    chapter1.qmd
    chapter2.qmd
```

Each volume should have its own `_quarto.yml` with the `volume` number set.
The `base-url` should point to the location where the volumes will be hosted, without the volume number in the end.

## Warnings

- The `collect-all-references.py` script always runs before rendering the book to ensure all references are collected.
- The cross-references labels must be unique across all volumes to avoid conflicts.
- The `base-url` must be the same across all volumes to ensure correct linking.
- The `volume` number must be set to a number (1, 2, 3, ...) for each volume. Do not use non-numeric values such as I, II, III, A, B, C, etc.
- The `volume` number must be unique for each volume, of course.
- 

## Requirements
- Python 3 to run the script