--[[
    This user patch requires the Simple UI plugin.

    Simple UI replaces KOReader's detailed-list directory layout when a folder
    has a cover. The replacement puts the folder name and item counts in a
    VerticalGroup whose default alignment is centered, so the counts appear in
    the middle of the second line instead of at the trailing edge.

    This patch changes only that covered-folder column to right alignment. The
    folder name remains left aligned because its TextBoxWidget already occupies
    the full column width, while the narrower count widget moves to the right.
--]]

local userpatch = require("userpatch")

local function patchSimpleUI()
    local ok_fc, FolderCovers = pcall(require, "features/library/sui_foldercovers")
    local ok_list, ListMenu = pcall(require, "listmenu")
    if not (ok_fc and ok_list) then return end

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

        if ListMenuItem._setListFolderCover
                == ListMenuItem._simpleui_right_aligned_count_update
        then
            return
        end

        local original_set_folder_cover = ListMenuItem._setListFolderCover
        local function setFolderCoverWithRightAlignedCount(self, ...)
            original_set_folder_cover(self, ...)

            -- Current Simple UI widget tree:
            -- underline group -> overlap group -> content container -> row
            -- -> main container -> name/count column.
            local underline_group = self._underline_container
                and self._underline_container[1]
            local overlap_group = underline_group and underline_group[2]
            local content_container = overlap_group and overlap_group[2]
            local row = content_container and content_container[1]
            local main_container = row and row[2]
            local name_count_column = main_container and main_container[1]

            -- Require both text rows so a future Simple UI layout change makes
            -- this patch a safe no-op instead of altering an unrelated group.
            if name_count_column
                    and name_count_column[1]
                    and name_count_column[3]
            then
                name_count_column.align = "right"
            end
        end

        ListMenuItem._setListFolderCover = setFolderCoverWithRightAlignedCount
        ListMenuItem._simpleui_right_aligned_count_update = setFolderCoverWithRightAlignedCount
        ListMenuItem._simpleui_right_aligned_count_original = original_set_folder_cover
    end

    installListPatch()

    -- Folder covers can be toggled after startup, and Simple UI removes its
    -- list methods during teardown. Reapply after install and release retained
    -- wrappers after uninstall so hot reloads use the current plugin modules.
    if not FolderCovers._simpleui_right_aligned_count_lifecycle_patched then
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
                ListMenuItem._simpleui_right_aligned_count_update = nil
                ListMenuItem._simpleui_right_aligned_count_original = nil
            end
            return result
        end
        FolderCovers._simpleui_right_aligned_count_lifecycle_patched = true
    end
end

userpatch.registerPatchPluginFunc("simpleui", patchSimpleUI)
