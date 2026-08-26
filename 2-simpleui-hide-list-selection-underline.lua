--[[
    This user patch requires the Simple UI plugin.

    Simple UI's "Hide Selection Underline" setting normally affects mosaic
    items only. Detailed-list items still use KOReader's stock focus handlers,
    which paint a dark underline when returning to a parent folder and restoring
    focus to the directory that was just visited.

    This patch makes detailed-list focus honor the same Simple UI setting. It
    preserves KOReader's normal focus handling and only replaces the resulting
    underline color with Simple UI's surface color when hiding is enabled.
--]]

local userpatch = require("userpatch")

local function patchSimpleUI()
    local ok_fc, FolderCovers = pcall(require, "features/library/sui_foldercovers")
    local ok_style, SUIStyle = pcall(require, "features/sui_style")
    local ok_list, ListMenu = pcall(require, "listmenu")
    if not (ok_fc and ok_style and ok_list) then return end

    local function getListMenuItem()
        return userpatch.getUpValue(ListMenu._updateItemsBuildUI, "ListMenuItem")
    end

    local function hideUnderline(item)
        if FolderCovers.isEnabled() and FolderCovers.getHideUnderline()
                and item._underline_container
        then
            item._underline_container.color = SUIStyle.COLOR.surface
        end
    end

    local function installListPatch()
        local ListMenuItem = getListMenuItem()
        if not ListMenuItem or not ListMenuItem._simpleui_lm_patched then return end

        if ListMenuItem.onFocus == ListMenuItem._simpleui_hidden_list_underline_focus
                and ListMenuItem.onUnfocus == ListMenuItem._simpleui_hidden_list_underline_unfocus
        then
            return
        end

        local original_on_focus = ListMenuItem.onFocus
        local original_on_unfocus = ListMenuItem.onUnfocus

        local function onFocusWithHiddenUnderline(self, ...)
            local result = original_on_focus(self, ...)
            hideUnderline(self)
            return result
        end

        local function onUnfocusWithHiddenUnderline(self, ...)
            local result = original_on_unfocus(self, ...)
            hideUnderline(self)
            return result
        end

        ListMenuItem.onFocus = onFocusWithHiddenUnderline
        ListMenuItem.onUnfocus = onUnfocusWithHiddenUnderline
        ListMenuItem._simpleui_hidden_list_underline_focus = onFocusWithHiddenUnderline
        ListMenuItem._simpleui_hidden_list_underline_unfocus = onUnfocusWithHiddenUnderline
        ListMenuItem._simpleui_hidden_list_underline_original_focus = original_on_focus
        ListMenuItem._simpleui_hidden_list_underline_original_unfocus = original_on_unfocus
    end

    installListPatch()

    -- Folder covers can be toggled after startup. Restore the original list
    -- focus handlers during teardown so disabling or hot-reloading Simple UI
    -- does not retain wrappers that reference old plugin modules.
    if not FolderCovers._simpleui_hidden_list_underline_lifecycle_patched then
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
                if ListMenuItem.onFocus
                        == ListMenuItem._simpleui_hidden_list_underline_focus
                then
                    ListMenuItem.onFocus =
                        ListMenuItem._simpleui_hidden_list_underline_original_focus
                end
                if ListMenuItem.onUnfocus
                        == ListMenuItem._simpleui_hidden_list_underline_unfocus
                then
                    ListMenuItem.onUnfocus =
                        ListMenuItem._simpleui_hidden_list_underline_original_unfocus
                end
                ListMenuItem._simpleui_hidden_list_underline_focus = nil
                ListMenuItem._simpleui_hidden_list_underline_unfocus = nil
                ListMenuItem._simpleui_hidden_list_underline_original_focus = nil
                ListMenuItem._simpleui_hidden_list_underline_original_unfocus = nil
            end
            return result
        end
        FolderCovers._simpleui_hidden_list_underline_lifecycle_patched = true
    end
end

userpatch.registerPatchPluginFunc("simpleui", patchSimpleUI)
