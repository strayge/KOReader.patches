--[[
    The SimpleUI Library uses KOReader's paged FileManager, whose vertical
    swipes do not turn pages. Allow up/down paging from the middle 70% of
    screen width and middle 50% of height in file-browser folders and History,
    leaving the top menu and side-edge gestures available. Stop at page boundaries.
--]]

local Device = require("device")
local FileManager = require("apps/filemanager/filemanager")
local FileManagerHistory = require("apps/filemanager/filemanagerhistory")
local Screen = Device.screen
local RESERVED_ZONES = {
    "DTAP_ZONE_MENU", "DTAP_ZONE_MENU_EXT",
    "DSWIPE_ZONE_LEFT_EDGE", "DSWIPE_ZONE_RIGHT_EDGE",
}

local function inZone(pos, zone)
    if not zone then return false end
    local w, h = Screen:getWidth(), Screen:getHeight()
    return pos.x >= zone.x * w and pos.x < (zone.x + zone.w) * w
       and pos.y >= zone.y * h and pos.y < (zone.y + zone.h) * h
end

local function registerPager(widget, getPager, overrides)
    widget:registerTouchZones({
        {
            id = "simpleui_center_vertical_page_swipe",
            ges = "swipe",
            screen_zone = { ratio_x = 0.15, ratio_y = 0.25, ratio_w = 0.7, ratio_h = 0.5 },
            overrides = overrides,
            handler = function(ges)
                if not ges or not ges.pos then return false end
                if ges.direction ~= "north" and ges.direction ~= "south" then return false end
                local pager = getPager()
                if not pager then return false end

                -- User-customized menu/edge zones may extend into the center;
                -- they keep precedence even when rectangles overlap.
                for _, key in ipairs(RESERVED_ZONES) do
                    if inZone(ges.pos, G_defaults:readSetting(key)) then return false end
                end

                local page = pager.page or 1
                if ges.direction == "north" then
                    if page < (pager.page_num or 1) then pager:onNextPage() end
                elseif page > 1 then
                    pager:onPrevPage()
                end
                return true
            end,
        },
    })
end

local original_init = FileManager.init
function FileManager:init(...)
    local result = original_init(self, ...)
    if self._simpleui_plugin and self.file_chooser then
        registerPager(self, function()
            local chooser = self.file_chooser
            return self._simpleui_plugin and chooser and chooser.name == "filemanager" and chooser
        end, { "filemanager_swipe" })
    end
    return result
end

local original_show_history = FileManagerHistory.onShowHist
function FileManagerHistory:onShowHist(...)
    local result = original_show_history(self, ...)
    local history = self.booklist_menu
    if self.ui and self.ui._simpleui_plugin and history and history.name == "history" then
        registerPager(history, function()
            return self.ui._simpleui_plugin and history
        end)
        local original_resize = history.onScreenResize
        history.onScreenResize = function(widget, ...)
            local resize_result = original_resize(widget, ...)
            widget:updateTouchZonesOnScreenResize({ w = Screen:getWidth(), h = Screen:getHeight() })
            return resize_result
        end
    end
    return result
end
