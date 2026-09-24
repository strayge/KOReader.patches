--[[
    CoverBrowser's non-refresh directory scan can reach its "books to index"
    message without passing the count to ngettext. In languages with a plural
    formula that uses the count, this aborts the scan before any work begins.

    Recover the count from that scan's current file list, leaving every other
    translation and the already-correct refresh path unchanged.
--]]

local userpatch = require("userpatch")

local function patchCoverBrowser()
    local BookInfoManager = require("bookinfomanager")
    local scan = BookInfoManager.extractBooksInDirectory
    if BookInfoManager._index_count_plural_scan == scan then return end

    local original_plural, index = userpatch.getUpValue(scan, "N_")
    if type(original_plural) ~= "function" then return end

    local function pluralWithScanCount(singular, plural, count)
        if count == nil
                and singular == "Found 1 book to index."
                and plural == "Found %1 books to index."
                and debug.getinfo(2, "f").func == scan
        then
            local local_index = 1
            while true do
                local name, value = debug.getlocal(2, local_index)
                if not name then break end
                if name == "files" and type(value) == "table" then
                    count = #value
                    break
                end
                local_index = local_index + 1
            end
            assert(count ~= nil, "CoverBrowser scan file list was not found")
        end
        return original_plural(singular, plural, count)
    end

    userpatch.replaceUpValue(scan, index, pluralWithScanCount)
    BookInfoManager._index_count_plural_scan = scan
end

userpatch.registerPatchPluginFunc("coverbrowser", patchCoverBrowser)
