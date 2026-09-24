--[[
    The SimpleUI Library uses KOReader's paged FileManager, whose vertical
    swipes do not turn pages. Allow up/down paging from the middle 70% of
    screen width and middle 50% of height in file-browser folders, leaving
    the top menu and side-edge gestures available. Stop at page boundaries.
--]]

local Device = require("device")
local FileManager = require("apps/filemanager/filemanager")
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

local original_init = FileManager.init
function FileManager:init(...)
    local result = original_init(self, ...)
    if not (self._simpleui_plugin and self.file_chooser) then return result end

    self:registerTouchZones({
        {
            id = "simpleui_library_center_vertical_swipe",
            ges = "swipe",
            screen_zone = { ratio_x = 0.15, ratio_y = 0.25, ratio_w = 0.7, ratio_h = 0.5 },
            overrides = { "filemanager_swipe" },
            handler = function(ges)
                if not ges or not ges.pos then return false end
                if ges.direction ~= "north" and ges.direction ~= "south" then return false end
                if not self._simpleui_plugin then return false end
                local chooser = self.file_chooser
                if not chooser or chooser.name ~= "filemanager" then return false end

                -- User-customized menu/edge zones may extend into the middle
                -- half; they keep precedence even when rectangles overlap.
                for _, key in ipairs(RESERVED_ZONES) do
                    if inZone(ges.pos, G_defaults:readSetting(key)) then return false end
                end

                local page = chooser.page or 1
                if ges.direction == "north" then
                    if page < (chooser.page_num or 1) then chooser:onNextPage() end
                elseif page > 1 then
                    chooser:onPrevPage()
                end
                return true
            end,
        },
    })
    return result
end
