local CONTROLLER = {}
CONTROLLER.__index = CONTROLLER

function CONTROLLER.Attach(rig)
    local self = setmetatable({}, CONTROLLER)

    self.Rig = rig
    self.Bones = self:GetBones()

    return self
end

function CONTROLLER:GetBones()
    local rootBone = self.Rig.PrimaryPart:FindFirstChildOfClass("Bone")

    local bones = {["root"] = rootBone}
    for _, bone in rootBone:GetDescendants() do
       bones[bone.Name] = bone
    end

    return bones
end

return CONTROLLER
