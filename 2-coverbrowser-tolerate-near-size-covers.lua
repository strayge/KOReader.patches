--[[
    CoverBrowser normally rejects a cached thumbnail when the current list
    layout needs even one extra pixel. Folder previews then disappear and
    browsing books re-extracts covers that were already cached.

    Reuse a cover when scaling it to the current view would add at most three
    pixels in either dimension. Larger changes still trigger re-extraction.
    This also keeps non-refresh directory scans from reprocessing near-size
    covers merely because the list geometry changed slightly.
--]]

local userpatch = require("userpatch")
local MAX_EXTRA_PIXELS = 3

local function patchCoverBrowser()
    local BookInfoManager = require("bookinfomanager")
    if BookInfoManager._near_size_covers_patched then return end

    local original_check = BookInfoManager.isCachedCoverInvalid
    BookInfoManager.isCachedCoverInvalid = function(bookinfo, cover_specs)
        if not bookinfo.cover_w or not bookinfo.cover_h then return true end
        if type(bookinfo.cover_sizetag) ~= "string" then return true end
        if not original_check(bookinfo, cover_specs) then return false end

        local original_w, original_h = bookinfo.cover_sizetag:match("(%d+)x(%d+)")
        if not original_w or not original_h then return true end
        local needed_w, needed_h = BookInfoManager.getCachedCoverSize(
            tonumber(original_w), tonumber(original_h),
            cover_specs.max_cover_w, cover_specs.max_cover_h)
        return needed_w > bookinfo.cover_w + MAX_EXTRA_PIXELS
            or needed_h > bookinfo.cover_h + MAX_EXTRA_PIXELS
    end
    BookInfoManager._near_size_covers_patched = true
end

userpatch.registerPatchPluginFunc("coverbrowser", patchCoverBrowser)
