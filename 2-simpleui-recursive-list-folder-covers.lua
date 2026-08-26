--[[
    This user patch requires the Simple UI plugin.

    Simple UI's "Scan Subfolders for Covers" setting normally applies to
    mosaic folder covers, but detailed-list folder covers only inspect books
    directly inside each folder. As a result, a folder containing only series
    subfolders has no thumbnail even when its descendants have cached covers.

    This patch gives detailed-list folder covers the same fallback as mosaic
    single-cover mode. It honors Simple UI's existing placeholder and recursive
    cover settings and uses the same bounded recursive cover finder.
--]]

local userpatch = require("userpatch")

local function removePendingRetry(item)
    local menu = item.menu
    if not menu then return end

    if menu._fc_pending_set then
        menu._fc_pending_set[item] = nil
    end

    local pending = menu.items_to_update
    if not pending then return end
    for i = #pending, 1, -1 do
        if pending[i] == item then
            table.remove(pending, i)
        end
    end
end

local function patchSimpleUI()
    local ok_fc, FolderCovers = pcall(require, "features/library/sui_foldercovers")
    local ok_finder, CoverFinder = pcall(require, "features/library/sui_cover_finder")
    local ok_bim, BookInfoManager = pcall(require, "bookinfomanager")
    local ok_list, ListMenu = pcall(require, "listmenu")
    if not (ok_fc and ok_finder and ok_bim and ok_list) then return end

    local function getListMenuItem()
        return userpatch.getUpValue(ListMenu._updateItemsBuildUI, "ListMenuItem")
    end

    local function installListPatch()
        local ListMenuItem = getListMenuItem()
        if not ListMenuItem
                or not ListMenuItem._simpleui_lm_patched
                or type(ListMenuItem._setListFolderCover) ~= "function"
        then
            return
        end

        if ListMenuItem.update == ListMenuItem._simpleui_recursive_list_update then
            return
        end

        local original_update = ListMenuItem.update
        local function updateWithRecursiveFolderCover(self, ...)
            original_update(self, ...)

            if self._foldercover_processed or not self.do_cover_image then return end
            if not self.mandatory or not FolderCovers.isEnabled() then return end
            if not FolderCovers.getSubfolderCover() or not FolderCovers.getRecursiveCover() then return end
            if self.menu and self.menu.no_refresh_covers then return end

            local entry = self.entry
            if not entry or entry.is_file or entry.file or entry.is_go_up then return end
            if entry.is_virtual_meta_leaf or entry.is_series_group then return end
            if not entry.path or not self.menu then return end

            -- Match mosaic single-cover behavior: recursive fallback is only
            -- used for a folder with subfolders but no directly contained books.
            local entries = CoverFinder.entriesWithNoFilter(self.menu, entry.path)
            if not entries then return end

            local has_files = false
            local has_subfolders = false
            for _, child in ipairs(entries) do
                if child.is_file or child.file then
                    has_files = true
                    break
                elseif not child.is_go_up then
                    has_subfolders = true
                end
            end
            if has_files or not has_subfolders then return end

            local cover = CoverFinder.findCoverRecursive(
                self.menu, entry.path, 1, 3, BookInfoManager)
            if not cover then return end

            self:_setListFolderCover({
                cover_bb = cover.data,
                cover_w = cover.w,
                cover_h = cover.h,
                has_cover = true,
                cover_fetched = true,
            })

            -- CoverMenu owns this queue while processing asynchronous retries.
            -- During initial construction it is safe to remove the unnecessary
            -- directory retry. During a retry, mark it resolved and let the
            -- scheduler remove its current entry without mutating under iteration.
            self.bookinfo_found = true
            if self.init_done then
                if self.menu._fc_pending_set then
                    self.menu._fc_pending_set[self] = nil
                end
            else
                removePendingRetry(self)
            end
        end

        ListMenuItem.update = updateWithRecursiveFolderCover
        ListMenuItem._simpleui_recursive_list_update = updateWithRecursiveFolderCover
    end

    installListPatch()

    -- Folder covers may be enabled after Simple UI starts. Install the list
    -- wrapper after Simple UI installs its own cover-browser patches as well.
    if not FolderCovers._simpleui_recursive_list_install_patched then
        local original_install = FolderCovers.install
        local original_uninstall = FolderCovers.uninstall
        FolderCovers.install = function(...)
            local result = original_install(...)
            installListPatch()
            return result
        end
        FolderCovers.uninstall = function(...)
            local ListMenuItem = getListMenuItem()
            local result = original_uninstall(...)
            if ListMenuItem then
                -- Release the old wrapper and its module upvalues. Simple UI
                -- restores ListMenuItem.update itself during this uninstall.
                ListMenuItem._simpleui_recursive_list_update = nil
            end
            return result
        end
        FolderCovers._simpleui_recursive_list_install_patched = true
    end
end

userpatch.registerPatchPluginFunc("simpleui", patchSimpleUI)
