require "ISUI/ISPanel"

local EXP_WIDTH = 500.0
local EXP_HEIGHT = 500.0
local ROULETTE_ENABLED = false

local roulette_pos = 0
local roulette_step = 10 -- higher, faster roulette
local choice = -1 -- -1 equals no choice made yet
local radius = 100

-- Overrides ISInventoryPage to add a new child with the roulette.
local og_createChildren = ISInventoryPage.createChildren
function ISInventoryPage:createChildren()
    og_createChildren(self)
    if (ROULETTE_ENABLED) then
        local cx = (getCore():getScreenWidth()  / 2) - (EXP_WIDTH  / 2)
        local cy = (getCore():getScreenHeight() / 2) - (EXP_HEIGHT / 2)
        RouletteUI.instance = RouletteUI:new(cx, cy, 0, 0)
        RouletteUI.instance:initialise()
        RouletteUI.instance:addToUIManager()
        RouletteUI.instance:noBackground()
        RouletteUI.instance:setOptions({})
    end
end

-- RouletteUI element
RouletteUI = ISPanel:derive("RouletteUI");
function RouletteUI:new(x, y, w, h)
	local o = {}
	o = ISPanel:new(x, y, w, h)
	setmetatable(o, self)
    self.__index = self
    return o
end

function RouletteUI:chooseIndex(idx)
    choice = idx
end

function RouletteUI:show()
    RouletteUI.instance:setWidth(EXP_WIDTH)
    RouletteUI.instance:setHeight(EXP_HEIGHT)
end

function RouletteUI:hide()
    RouletteUI.instance:setWidth(0)
    RouletteUI.instance:setHeight(0)
end

function RouletteUI:setOptions(opts)
    -- pre calculate positions for options in roulette
    local cx = self.width  / 2
    local cy = self.height / 2
    local text_radius = radius + 200
    local text_angle_inc = (2 * math.pi) / #opts
    for i=0, #opts-1 do
        local angle = i * text_angle_inc
        local x = cx + text_radius * math.cos(angle)
        local y = cy + text_radius * math.sin(angle)

        opts[i+1].x = x
        opts[i+1].y = y
    end
    self.options = opts
end

function RouletteUI:prerender()
    if (#self.options < 1) then return end
    local num_rects = 100
    local cx = self.width / 2
    local cy = self.height / 2
    local angle_inc = (2 * math.pi) / num_rects

    -- Add text with options.
    for i=0, #self.options-1 do
        self:drawTextCentre(self.options[i+1].label, self.options[i+1].x, self.options[i+1].y, 1, 1, 1, 1, UIFont.Small);
    end

    -- No choice made yet. Spin the roulette.
    if (choice == -1) then
        for i=0, num_rects - 1 do
            local angle = i * angle_inc
            local x = cx + radius * math.cos(angle)
            local y = cy + radius * math.sin(angle)

            -- draw outline of circle
            -- self:drawRect(x, y, 5.0, 5.0, 1.0, 1.0, 1.0, 1.0)

            -- line to radius
            if (i == roulette_pos) then
                self:line(cx, cy, x, y)
            end
        end
        roulette_pos = roulette_pos + roulette_step
        if (roulette_pos >= num_rects) then roulette_pos = 0 end
    -- Point towards the choice instead.
    else
        local option_chosen = self.options[choice]
        print("chosen: "..option_chosen.label)
        self.line(cx, cy, option_chosen.x, option_chosen.y)
    end
end

function RouletteUI:line(cx, cy, x, y)
    local m = (cy - y) / (cx - x)

    local step = 1
    if (cx > x) then
        step = -1
    end
    for line_x=cx, x, step do
        local line_y = m * (line_x - x) + y
        self:drawRect(line_x, line_y, 5.0, 5.0, 1.0, 1.0, 0.0, 0.0)
    end
end