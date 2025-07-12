local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local _keyframe = require(ReplicatedStorage.Objects.Keyframe)

local KEYFRAME_SEQUENCE = {}
KEYFRAME_SEQUENCE.__index = KEYFRAME_SEQUENCE

function _sortKeyframes(list)
	table.sort(list, function(a, b)
		return a.Time < b.Time
	end)

	return list
end

function KEYFRAME_SEQUENCE.New(AnimationController, KeyframeSequenceObject)
	local self = setmetatable({}, KEYFRAME_SEQUENCE)

	self.InstanceRef = KeyframeSequenceObject
	self.Loop = KeyframeSequenceObject.Loop
	self.AnimationController = AnimationController

	self.PlaybackSpeed = 1

	self.CurrentTime = 0
	self.FrameTime = 0
	self.NextFrameTime = 0
    self.FrameDelta = 1/60

	self.FrameIndex = 1
	self.NextFrameIndex = 1

	local keyframes = {}
	for _, keyframeObject in KeyframeSequenceObject:GetChildren() do
		local keyframe = _keyframe.New(AnimationController, keyframeObject)
		table.insert(keyframes, keyframe)
	end

	self.Keyframes = _sortKeyframes(keyframes)

	return self
end

function KEYFRAME_SEQUENCE:Destroy()
	for _, keyframe in ipairs(self.Keyframes) do
		keyframe:Destroy()
	end
	self.InstanceRef = nil
end

function KEYFRAME_SEQUENCE:GetKeyframes()
	return self.Keyframes
end

function KEYFRAME_SEQUENCE:ResetState()
	self.CurrentTime = 0
	self.FrameTime = 0
	self.NextFrameTime = 0
    self.FrameDelta = 1/60

	self.FrameIndex = 1
	self.NextFrameIndex = 1
end

function KEYFRAME_SEQUENCE:Play()
	self:ResetState()

	local totalFrameCount = #self.Keyframes
    local firstKeyframe = self.Keyframes[1]
    local lastKeyframe = self.Keyframes[totalFrameCount]

    local direction = math.sign(self.PlaybackSpeed)

    local function _nextKeyframe()
        local nextKeyframe
        
        -- this guy Circular
        local nextFrameOutOfBounds = 
            self.NextFrameIndex > totalFrameCount 
            or self.NextFrameIndex < 1

        local skippedFrames = self.NextFrameIndex - self.FrameIndex > 1 
		if nextFrameOutOfBounds then
            if skippedFrames then
                nextKeyframe = direction == 1 
                    and self.Keyframes[self.NextFrameIndex % totalFrameCount]
                    or self.Keyframes[self.NextFrameIndex % totalFrameCount]
            else
                nextKeyframe = direction == 1 
                    and firstKeyframe
                    or lastKeyframe
            end
        else
            nextKeyframe = self.Keyframes[self.NextFrameIndex]
        end

        return nextKeyframe, nextFrameOutOfBounds
    end

    local function _nextFrameConditionMet()
        if direction == 1 then
            return self.CurrentTime >= self.NextFrameTime
        else
            return self.CurrentTime <= self.NextFrameTime
        end
    end

    local function _handleSequenceEnd()
		if self.Loop then
			self:ResetState()

			if direction == -1 then
				-- For backward playback,
				-- reset to the end of the animation
				self.CurrentTime = lastKeyframe.Time
				self.FrameIndex = totalFrameCount
			end
		else
			self:Stop()
			return
		end
    end

	self.RunCon = RunService.PreAnimation:Connect(function(dT)
        local adjustedDeltaTime = dT * self.PlaybackSpeed
        self.CurrentTime += adjustedDeltaTime
        
        local dropFrames = math.abs(adjustedDeltaTime) / self.FrameDelta
        dropFrames = math.floor(dropFrames) * direction
        dropFrames = math.min(dropFrames, totalFrameCount - 1)
  
		direction = math.sign(self.PlaybackSpeed)
		self.NextFrameIndex = self.FrameIndex + direction + dropFrames
        
		local keyframe = self.Keyframes[self.FrameIndex]
        local nextKeyframe, nextFrameOutOfBounds = _nextKeyframe()

        -- tween between keyframes
		self.FrameTime = keyframe.Time
		self.NextFrameTime = nextKeyframe.Time

		if nextKeyframe then
            self.FrameDelta = direction == 1 
                and self.NextFrameTime - self.FrameTime
                or self.FrameTime - self.NextFrameTime
            
			local alpha = math.abs(self.CurrentTime - self.FrameTime) / self.FrameDelta
            alpha = math.min(alpha, 1)

			keyframe:SetPose(1 - alpha)
			nextKeyframe:SetPose(alpha)
		end

        -- go to next keyframe
		if _nextFrameConditionMet() then
			self.FrameIndex = self.NextFrameIndex

			if nextFrameOutOfBounds then
				_handleSequenceEnd()
			end
		end
	end)
end

function KEYFRAME_SEQUENCE:AdjustSpeed(speed)
	self.PlaybackSpeed = speed or 1
end

function KEYFRAME_SEQUENCE:Stop()
    self:ResetState()
	if self.RunCon then
		self.RunCon:Disconnect()
		self.RunCon = nil
	end
end

return KEYFRAME_SEQUENCE
