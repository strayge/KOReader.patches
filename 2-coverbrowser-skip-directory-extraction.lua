--[[
    SimpleUI can queue uncovered folders and virtual series groups alongside
    real books for CoverBrowser's background extractor. Non-file paths cannot
    yield book metadata or a cover and can leave failed cache records.

    Keep folder items in the menu's retry queue while real books are being
    extracted; only pass existing files to the background book extractor.
--]]

local userpatch = require("userpatch")
local lfs = require("libs/libkoreader-lfs")

local function patchCoverBrowser()
    local BookInfoManager = require("bookinfomanager")
    if BookInfoManager._skip_directory_extraction_patched then return end

    local original_extract = BookInfoManager.extractInBackground
    BookInfoManager.extractInBackground = function(self, files)
        if #files == 0 then return original_extract(self, files) end
        local books = {}
        for _, request in ipairs(files) do
            if lfs.attributes(request.filepath, "mode") == "file" then
                books[#books + 1] = request
            end
        end
        if #books == 0 then
            -- Match KOReader's page-change cancellation without treating a
            -- folder-only queue as a failed subprocess launch.
            self:terminateBackgroundJobs()
            return true
        end
        return original_extract(self, books)
    end
    BookInfoManager._skip_directory_extraction_patched = true
end

userpatch.registerPatchPluginFunc("coverbrowser", patchCoverBrowser)
