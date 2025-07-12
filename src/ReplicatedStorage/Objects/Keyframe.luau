local function _getPosesFromObject(bones, keyframeObject)
	local poses = {}
	for _, joint in keyframeObject:GetDescendants() do
		local bone = bones[joint.name]
		if not bone then
			continue
		end

		if joint.weight > 0 then
			poses[joint.name] = {
				CFrame = joint.CFrame,
				Easing = joint.EasingStyle,
				Direction = joint.EasingDirection,
			}
		end
	end

	return poses
end

local KEYFRAME = {}
KEYFRAME.__index = KEYFRAME

function KEYFRAME.New(AnimationController, KeyframeObject)
	local self = setmetatable({}, KEYFRAME)

	self.InstanceRef = KeyframeObject
	self.Bones = AnimationController.Bones
	self.Time = KeyframeObject.Time
	self.Poses = _getPosesFromObject(self.Bones, KeyframeObject)
	self.AppliedWeight = 0

	return self
end

function KEYFRAME:Destroy()
	self.InstanceRef = nil
end

function KEYFRAME:GetPoses(poseName)
	if typeof(poseName) == "string" then
		return self.Poses[poseName]
	elseif typeof(poseName) == "table" then
		local poses = {}
		for _, name in poseName do
			poses[name] = self.Poses[name]
		end
		return poses
	elseif poseName == nil then
		return self.Poses
	end
end

function KEYFRAME:SetPose(alpha)
	--todo: batch these up as layers within @ animationcontroller
	self.AppliedWeight = alpha
	for name, pose in self.Poses do
		local bone = self.Bones[name]
		if bone then
			bone.Transform = bone.Transform:Lerp(pose.CFrame, alpha)
		end
	end
end

function KEYFRAME:ResetPose()
	for name, pose in self.Poses do
		local bone = self.Bones[name]
		if bone then
			bone.Transform = bone.Transform:Lerp(pose.CFrame, -self.AppliedWeight)
		end
	end
	self.AppliedWeight = 0
end

return KEYFRAME
