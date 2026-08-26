--[[
    This user patch requires the Simple UI plugin.

    Quick Action dimensions are already scaled to device pixels, but Nerd Font
    icons pass those dimensions to KOReader's font API, which scales them a
    second time. This patch removes that extra scaling while preserving the
    original icon containers and hitboxes.
--]]

local Device = require("device")
local Font = require("ui/font")
local logger = require("logger")

local Screen = Device.screen

local QUICK_ACTION_RENDERERS = {
    "simpleui.koplugin/engines/sui_quickactions_render.lua",
    "simpleui.koplugin/modules/module_quick_actions.lua",
    "simpleui.koplugin/modules/module_action_list.lua",
    "simpleui.koplugin/screens/sui_quicksettings_bar.lua",
    "simpleui.koplugin/screens/sui_bottombar.lua",
}

local function isQuickActionRenderer(source)
    for _, path in ipairs(QUICK_ACTION_RENDERERS) do
        if source:find(path, 1, true) then return true end
    end
    return false
end

local function inverseScaleBySize(size)
    local target = math.max(1, math.floor(size))
    local low, high = 1, target

    while Screen:scaleBySize(high) < target do
        high = high * 2
    end

    while low < high do
        local mid = math.floor((low + high) / 2)
        if Screen:scaleBySize(mid) < target then
            low = mid + 1
        else
            high = mid
        end
    end

    local upper = low
    local lower = math.max(1, upper - 1)
    local lower_delta = math.abs(Screen:scaleBySize(lower) - target)
    local upper_delta = math.abs(Screen:scaleBySize(upper) - target)
    return lower_delta <= upper_delta and lower or upper
end

if not Font._simpleui_quick_action_nerd_scaling_patched then
    local original_get_face = Font.getFace
    local adjustment_logged = false

    Font.getFace = function(self, font, size, ...)
        if font == "symbols" and type(size) == "number" then
            local info = debug.getinfo(2, "S")
            local source = info and info.source or ""
            if isQuickActionRenderer(source) then
                local original_size = size
                size = inverseScaleBySize(size)
                if not adjustment_logged then
                    logger.info(
                        "simpleui: adjusted Quick Action Nerd Font size from",
                        original_size, "to", size)
                    adjustment_logged = true
                end
            end
        end
        return original_get_face(self, font, size, ...)
    end

    Font._simpleui_quick_action_nerd_scaling_patched = true
    logger.info("simpleui: Quick Action Nerd Font scaling patch enabled")
end
