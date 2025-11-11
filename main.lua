local chexcore = require "chexcore"

local scene = Scene.new{
    Name = "LaceyScene",
    DrawSize = V{640, 480},
}:Properties{
    
}

scene:AddLayer(Layer.new("MainLayer", 640, 480)):Properties{
}

local lacey = Prop.new{
    Texture = Texture.new("assets/images/testLacey.png"),
    Size = V{640, 480},
    Position = V{0, 0},
    AnchorPoint = V{0.5, 0.5},
    Rotation = 0,
}:Properties{
    Update = function (self, dt)
        -- self.Rotation = self.Rotation + dt
    end
}:Into(scene:GetLayer("MainLayer"))

Chexcore.MountScene(scene)

print(#scene:GetChildren())