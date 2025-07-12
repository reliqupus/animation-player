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

	self.AnimationController = AnimationController
	self.InstanceRef = KeyframeSequenceObject
	
	-- keyframes
	local keyframes = {}
	for _, keyframeObject in KeyframeSequenceObject:GetChildren() do
		local keyframe = _keyframe.New(AnimationController, keyframeObject)
		table.insert(keyframes, keyframe)
	end
	
	self.Keyframes = _sortKeyframes(keyframes)
	
	-- playback state & info
	self.Loop = KeyframeSequenceObject.Loop
	self.Length = self.Keyframes[#self.Keyframes].Time
	self.PlaybackSpeed = 1

	self.PlaybackTime = 0
	self.FrameTime = 0
	self.NextFrameTime = 0
	self.FrameDelta = 1 / 60

	self.FrameIndex = 1
	self.NextFrameIndex = 1

	-- events
	self.Looped = Instance.new("BindableEvent")
	self.Started = Instance.new("BindableEvent")
	self.Ended = Instance.new("BindableEvent")

	return self
end

function KEYFRAME_SEQUENCE:Destroy()
	self.InstanceRef = nil
	for _, keyframe in ipairs(self.Keyframes) do
		keyframe:Destroy()
	end

	self.Looped:Destroy()
	self.Started:Destroy()
	self.Ended:Destroy()
end

function KEYFRAME_SEQUENCE:ResetAllPoses()
	for _, keyframe in ipairs(self.Keyframes) do
		keyframe:ResetPose()
	end
end

function KEYFRAME_SEQUENCE:ResetState()
	self.PlaybackTime = 0
	self.FrameTime = 0
	self.NextFrameTime = 0
	self.FrameDelta = 1 / 60

	self.FrameIndex = 1
	self.NextFrameIndex = 1
end

function KEYFRAME_SEQUENCE:Play()
	local totalFrameCount = #self.Keyframes
	local firstKeyframe = self.Keyframes[1]
	local lastKeyframe = self.Keyframes[totalFrameCount]

	local direction = math.sign(self.PlaybackSpeed)

	local function _nextKeyframe()
		local nextKeyframe
		local nextFrameOutOfBounds = 
			self.NextFrameIndex > totalFrameCount 
			or self.NextFrameIndex < 1

		local skippedFrames = self.NextFrameIndex - self.FrameIndex > 1
		if nextFrameOutOfBounds then
			if skippedFrames then
				local loopedIndex = self.NextFrameIndex % totalFrameCount
				nextKeyframe = self.Keyframes[loopedIndex]
			else
				nextKeyframe = direction == 1 and firstKeyframe or lastKeyframe
			end
		else
			nextKeyframe = self.Keyframes[self.NextFrameIndex]
		end

		return nextKeyframe, nextFrameOutOfBounds
	end

	local function _nextFrameConditionMet()
		if direction == 1 then
			return self.PlaybackTime >= self.NextFrameTime
		else
			return self.PlaybackTime <= self.NextFrameTime
		end
	end

	local function _handleSequenceEnd()
		if self.Loop then
			self:ResetState()
			self.Looped:Fire()

			if direction == -1 then
				-- For backward playback,
				-- reset to the end of the animation
				self.PlaybackTime = lastKeyframe.Time
				self.FrameIndex = totalFrameCount
			end
		else
			self:Stop()
			self.Ended:Fire()
		end
	end

	self.RunCon = RunService.PreAnimation:Connect(function(dT)
		-- playback speed 
		direction = math.sign(self.PlaybackSpeed)

		local adjustedDeltaTime = dT * self.PlaybackSpeed
		self.PlaybackTime += adjustedDeltaTime

		-- amount of frames to drop
		local droppedFrames = math.abs(adjustedDeltaTime) / self.FrameDelta
		droppedFrames = math.floor(droppedFrames)
		droppedFrames = math.min(droppedFrames, totalFrameCount - 1) * direction

		-- get keyframes
		self.NextFrameIndex = self.FrameIndex + direction + droppedFrames

		local keyframe = self.Keyframes[self.FrameIndex]
		local nextKeyframe, nextFrameOutOfBounds = _nextKeyframe()

		-- tween between keyframes
		self.FrameTime = keyframe.Time
		self.NextFrameTime = nextKeyframe.Time

		if nextKeyframe then
			self.FrameDelta = direction == 1 
				and self.NextFrameTime - self.FrameTime
				or self.FrameTime - self.NextFrameTime

			local alpha = math.abs(self.PlaybackTime - self.FrameTime) / self.FrameDelta
			alpha = math.min(alpha, 1)

			keyframe:SetPose(1 - alpha)
			nextKeyframe:SetPose(alpha)

			-- TODO: handle easing inside SetPose
			-- each bone has individual easing
			-- respect tat . .. 
		end

		-- go to next keyframe
		if _nextFrameConditionMet() then
			self.FrameIndex = self.NextFrameIndex

			if nextFrameOutOfBounds then
				_handleSequenceEnd()
			end
		end
	end)

	self.Started:Fire()
end

function KEYFRAME_SEQUENCE:Pause()
	if self.RunCon then
		self.RunCon:Disconnect()
		self.RunCon = nil
	end
end

function KEYFRAME_SEQUENCE:Stop()
	if self.RunCon then
		self.RunCon:Disconnect()
		self.RunCon = nil
	end

	self:ResetState()
	self:ResetAllPoses()
end

function KEYFRAME_SEQUENCE:AdjustSpeed(speed)
	self.PlaybackSpeed = speed or 1
end

function KEYFRAME_SEQUENCE:AdjustTimePostion(timePosition)
	self.CurrentTime = timePosition or 0
end

function KEYFRAME_SEQUENCE:GetKeyframes()
	return self.Keyframes
end

function KEYFRAME_SEQUENCE:GetAffected()
	return self.Keyframes[self.NextFrameIndex]:GetPoses()
end

return KEYFRAME_SEQUENCE
