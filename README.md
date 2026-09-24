# Local KOReader User Patches

Custom user patches for SimpleUI. Copy the desired `.lua` files into KOReader's `patches/` directory and restart KOReader.

## Patches

### `2-coverbrowser-index-count-plural.lua`

Prevents CoverBrowser's non-refresh directory scan from aborting when the display language needs a book count to choose a plural form.

### `2-coverbrowser-skip-directory-extraction.lua`

Prevents SimpleUI folder and virtual-group paths from reaching CoverBrowser's background book extractor. Folder thumbnails can still update while book extraction is running on the page.

### `2-simpleui-quick-action-nerd-icon-scaling.lua`

Prevents Nerd Font icons in Quick Actions from being enlarged by device scaling twice.

### `2-simpleui-recursive-list-folder-covers.lua`

Makes SimpleUI's **Scan Subfolders for Covers** setting work in detailed-list mode. It uses the same bounded recursive lookup as SimpleUI's mosaic single-cover mode.

### `2-simpleui-right-align-list-folder-counts.lua`

Right-aligns book and subfolder counts on the second line of covered folders in detailed-list mode while keeping folder names left-aligned.

### `2-simpleui-hide-list-selection-underline.lua`

Makes SimpleUI's **Hide Selection Underline** setting apply to detailed-list items, including the directory focused after returning to its parent.
