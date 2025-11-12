local LightSource = {
    Name = "LightSource",

    Radius = 2,         -- idk man just feel it out, start at 1
    Sharpness = 1,      -- 1 is fully sharp, 0 is fully blurred

    LightDirection = V{0.5,0.5, 1, "POINT"},

    Color = V{1,1,1,1},   -- 

    _super = "Prop", _global = true
}

-- Input: x, y, z (or a table {x, y, z})
-- Output: compressed X, Y in [0, 1] range
function LightSource:SetLightDir(x, y, z)
    -- Normalize the direction vector
    local length = math.sqrt(x*x + y*y + z*z)
    if length > 0.0001 then
        x = x / length
        y = y / length
        z = z / length
    else
        -- Default to pointing straight forward if zero vector
        return 0.5, 0.5
    end
    
    -- Compress to [0, 1] range (shader will expand back to [-1, 1])
    local compressedX = (x + 1.0) * 0.5
    local compressedY = (y + 1.0) * 0.5
    
    return compressedX, compressedY
end

function LightSource.new(properties)

    

    local lightSource = Prop.new{
        Solid = false, Visible = true,
        Color = V{1, 1, 1, 1},
        AnchorPoint = V{ 0.5, 0.5 },
        Size = V{0, 0},
        Rotation = 0,
        DrawOverChildren = false,
    }
    lightSource.Color = rawget(lightSource, "Color") or LightSource.Color:Clone()
    lightSource._propID = _G.CURRENT_PROP_ID; _G.CURRENT_PROP_ID = _G.CURRENT_PROP_ID + 1

    setmetatable(lightSource, LightSource)
    return lightSource
end

function LightSource:Update(dt)
    -- update stuff with dt
end

local function isLightOnScreen(camPos, camSize, zoom, radius, light_tl, light_br)
    local hw = camSize[1] / (zoom) / 2
    local hh = camSize[2] / (zoom) / 2
    return not (camPos[1] + hw < light_tl[1] - radius or camPos[1] - hw > light_br[1] + radius or camPos[2] + hh < light_tl[2] - radius or camPos[2] - hh > light_br[2] + radius)
end

local function shallowcopy(orig)
    local orig_type = type(orig)
    local copy
    if orig_type == 'table' then
        copy = {}
        for orig_key, orig_value in pairs(orig) do
            copy[orig_key] = orig_value
        end
    else -- number, string, boolean, etc
        copy = orig
    end
    return copy
end
  
local radFactor = 1.075 / 8 / 16
function LightSource:Draw(tx, ty)
    
    if not self:GetLayer() then return end
    -- draw method with tx, ty offsets (draw at position minus tx, ty)
    local layer = self:GetLayer()
    local cam = layer:GetParent().Camera
    local tl, br = self:GetPoint(0,0), self:GetPoint(1,1)
    if isLightOnScreen(cam.Position, layer.Canvases[1]:GetSize(), cam.Zoom, self.Radius, tl, br) then
        -- local x1, y1 = (self:GetLayer():PositionOnMasterCanvas((tl or self:GetPoint(0,0))) / self:GetScene().MasterCanvas:GetSize())()
        -- local x2, y2 = (self:GetLayer():PositionOnMasterCanvas(br or (self:GetPoint(1,1))) / self:GetScene().MasterCanvas:GetSize())()
        local x1, y1 = (((tl or self:GetPoint(0,0)) - V{tx,ty}) / self:GetLayer().Canvases[1]:GetSize())()
        local x2, y2 = (((br or self:GetPoint(1,1)) - V{tx,ty}) / self:GetLayer().Canvases[1]:GetSize())()


        
        self:GetLayer():EnqueueShaderData("lighting", "lightRects", {x1, y1, x2, y2})
        self:GetLayer():EnqueueShaderData("lighting", "lightChannels", self.Color)
        self:GetLayer():EnqueueShaderData("lighting", "radii", self.Radius*radFactor)
        self:GetLayer():EnqueueShaderData("lighting", "sharpnesses", self.Sharpness)
        self:GetLayer():EnqueueShaderData("lighting", "lightTypes", {self.LightDirection.X, self.LightDirection.Y, self.LightDirection.Z, self.LightDirection.W=="POINT" and 0 or 1})
        -- local l = self:GetLayer()
        -- print("L IS", tostring(l == nil))
        -- print("FUCKGHDGHDH", self, self:GetLayer():GetShaderData("lighting", "lightCount"))
        self:GetLayer():SetShaderData("lighting", "lightCount", (self:GetLayer():GetShaderData("lighting", "lightCount") or 0)+1)
        -- self:GetLayer():SetShaderData("lighting", "aspectRatio", {16,9})
        -- self:GetLayer():SetShaderData("lighting", "blendRange", 5)
    end

end

return LightSource