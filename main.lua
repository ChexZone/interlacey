local chexcore = require "chexcore"

local scene = Scene.new{
    Name = "LaceyScene",
    DrawSize = V{640, 480},
}:Properties{
    
}

local lightingLayer = scene:AddLayer(Layer.new("LightLayer", 640, 480)):Properties{
    -- Update = function (self, dt)

    -- end,

    Draw = function(self, tx, ty)
        self.ShaderQueue = {}

        self.ShaderCache.lighting:Send("baseShadowColor", V{0,0,0,1})
        self.ShaderCache.lighting:Send("lightCount", 0)
        return Layer.Draw(self, tx, ty)
    end
}

lightingLayer.ShaderCache = {
    lighting = Shader.new("assets/shaders/lighting.glsl"):Send("blendRange", 10):Send("aspectRatio", {4,3}),
    uncurve = Shader.new("assets/shaders/uncurve.glsl"),
}

lightingLayer.OverlayShaders = {"lighting", "uncurve"} -- overlay shader order

local tvLayer = scene:AddLayer(Layer.new("TVLayer", 640, 480)):Properties{
    Update = function (self, dt)
        self.ShaderCache.crt:Send("time", Chexcore._clock)
        return Layer.Update(self, dt)
    end
}

tvLayer.ShaderCache = {
    crt = Shader.new("assets/shaders/crt.glsl"),
}

tvLayer.OverlayShaders = {"crt"} -- overlay shader order





function scene:ApplyLighting()
    local queue = self.LightingQueue

    queue.lightColors = {}
    queue.focalPoints = {}
    queue.radii = {}
    queue.sharpnesses = {}
end

local radFactor = 1.075 / 8 / 16
function scene:EnqueueLight(lightSource, precomputed_tl, preomputed_br)
    -- lightSource.Radius = 0
    self.LightingQueue.sharpnesses[#self.LightingQueue.sharpnesses+1] = lightSource.Sharpness
    self.LightingQueue.radii[#self.LightingQueue.radii+1] = (lightSource.Radius*radFactor)
    self.LightingQueue.lightColors[#self.LightingQueue.lightColors+1] = lightSource.Color

    -- calculate focal point.. something like reverse Layer:GetMousePosition()?

    local x1, y1 = (lightSource:GetLayer():PositionOnMasterCanvas((precomputed_tl or lightSource:GetPoint(0,0))) / self.MasterCanvas:GetSize())()
    local x2, y2 = (lightSource:GetLayer():PositionOnMasterCanvas(preomputed_br or (lightSource:GetPoint(1,1))) / self.MasterCanvas:GetSize())()

    self.LightingQueue.focalPoints[#self.LightingQueue.focalPoints+1] = {x1, y1, x2, y2}
end

local lacey = Prop.new{
    Texture = Texture.new("assets/images/lacey-outline.png"),
    Size = V{640, 480},
    Position = V{0, 0},
    AnchorPoint = V{0.5, 0.5},
    Rotation = 0,
    Update = function (self, dt)
        print("test")
        if Input:JustPressed("f") then
            love.window.setFullscreen( not love.window.getFullscreen(), "desktop" )
        end

    end
}:Into(scene:GetLayer("TVLayer"))

local lacey = Prop.new{
    Texture = Texture.new("assets/images/lacey-face2.png"),
    Size = V{640, 480},
    Position = V{0, 0},
    AnchorPoint = V{0.5, 0.5},
    Rotation = 0,
}:Into(scene:GetLayer("TVLayer"))


local background = Prop.new{
    Texture = Texture.new{"assets/images/background/albedo.png", specularPath = "assets/images/background/normal.png", shadowPath = "assets/images/background/shadow.png"},
    Size = V{640, 480}/1,
    Color = V{0,0,1,.95},
    Position = V{0, 0},
    AnchorPoint = V{0.5, 0.5},
    Rotation = 0,
}:Into(scene:GetLayer("LightLayer"))

Chexcore:AddType(require"lightSource")
local light = LightSource.new():Properties{
    Color = V{1,1,1,1},
    Radius = 5,
    Sharpness = .5,
    Size = V{300,300},
    AnchorPoint = V{0.5, 0.5},
    Position = V{0,0},
    Update = function (self, dt)
        -- print("updating light")
        self.Position = self:GetLayer():GetMousePosition()
    end
}:Into(scene:GetLayer("LightLayer"))


Chexcore.MountScene(scene)

print(#scene:GetChildren())