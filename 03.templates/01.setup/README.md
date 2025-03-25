# Setup Templates

## Conventions

* Templates are folders.
* Installations here are intended for Windows. If installing on linux use the posix framework.
* The products list are stored in the file `ProductList.txt`. This is sufficient to produce image files. Also, this is the source of truth for the product list.
* Setup templates only contain products, not fixes. this rule is due to the fact the products lists change much less frequently, therefore fix lists are likely to be comupted multiple times.
* A template identifier is its relative path to `03.templates\01.setup` repository folder. Identifier path separator must be backslash (`\`).
