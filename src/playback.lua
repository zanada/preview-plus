local Playback = {}

function Playback:stopPlayback()
  self.playing = false
  if self.aTimer then
    self.aTimer:stop()
    self.aTimer = nil
  end
end

function Playback:startPlayback()
  assert(self.aTimer == nil)
  local delta = 1
  ---@type PlayTag[]
  local activeTags = {}
  ---@type Tag[]
  local seenTags = {}

  ---@param tag Tag
  ---@return boolean
  local function isTagSeen(tag)
    assert(tag)
    for _, seenTag in ipairs(seenTags) do
      if seenTag == tag then
        return true
      end
    end
    return false
  end
  
    local function printSeen()
      local line = "Seen=["
      for _,tag in ipairs(seenTags) do
        line = line .. tag.name .. ", "
      end
      line = line .. "]"
      print(line)
    end

  ---@param playTag PlayTag
  local function removeTagFromSeen(playTag)
    assert(playTag)
    local tag = playTag.tag
    for _,otherTag in pairs(playTag.removeThese) do
      for i, seenTag in ipairs(seenTags) do
        if seenTag == otherTag then
          table.remove(seenTags, i)
          break
        end
      end
    end
    for i, seenTag in ipairs(seenTags) do
      if seenTag == tag then
        table.remove(seenTags, i)
        break
      end
    end
    --printSeen()
  end
  
  local function printStack()
    local line = "Stack=["
    for _, tag in ipairs(activeTags) do
      line = line .. tag.tag.name .. ", "
    end
    line = line .. "]"
    print(line)
  end

  --- initial direction of tag
  ---@param t Tag
  ---@return integer (-1,1)
  local function getTagForward(t)
    return (t.aniDir == AniDir.FORWARD or t.aniDir == AniDir.PING_PONG) and 1 or -1
  end
  
  ---@class PlayTag
  ---@field tag Tag
  ---@field repeats integer|nil nil if infinity
  ---@field rewind boolean
  ---@field forward integer
  ---@field delayedDelete PlayTag|nil
  ---@field removeThese Tag[]
  local PlayTag = {}

  ---@param tag Tag
  ---@param parentForward integer
  ---@return PlayTag
  function PlayTag:new (tag, parentForward)
    local o = {}
    setmetatable(o, self)
    self.__index = self
    
    local r
    if tag.repeats > 0 then
      r = tag.repeats
    else
      if tag.aniDir == AniDir.PING_PONG or tag.aniDir == AniDir.PING_PONG_REVERSE then
        r = 2
      else
        r = 1
      end
    end

    o.tag=tag
    o.forward=parentForward * getTagForward(tag)
    o.repeats=r
    o.rewind=false
    o.delayedDelete=nil
    o.removeThese={}
    return o
  end

  local function addTag(tag, rewind, forward)
    assert(tag)
    local playTag = PlayTag:new(tag, forward)
    --if rewind then print("push "..tag.name.." with rewind") end
    if rewind then
      playTag.rewind = true

      assert(#activeTags > 0)
      local curTag = activeTags[#activeTags]
      local delayed = curTag --[[@as PlayTag]]
      while delayed.delayedDelete do
        delayed = delayed.delayedDelete --[[@as PlayTag]]
      end
      delayed.delayedDelete = playTag
      for _, otherTag in ipairs(delayed.removeThese) do
        table.insert(playTag.removeThese, otherTag)
      end
      table.insert(playTag.removeThese, delayed.tag)
      delayed.removeThese = {}

      local i = #activeTags
      while i > 1 do
        if activeTags[i].tag == delayed.tag then
          break
        end
        i = i - 1
      end
      
      table.insert(activeTags, i, playTag)
      --printStack()
    else
      table.insert(activeTags, playTag)
      --printStack()
    end
    table.insert(seenTags,tag)
    --printSeen()
  end

  ---@param t Tag
  ---@param f Frame
  ---@return boolean
  local function tagContainsFrame(t, f)
    assert(t)
    assert(f)
    return f.frameNumber >= t.fromFrame.frameNumber and
           f.frameNumber <= t.toFrame.frameNumber
  end


  ---returns true if t1 is a proper parent of t2
  ---@param t1 Tag
  ---@param t2 Tag
  ---@return boolean
  local function tagContainsTag(t1, t2)
    assert(t1)
    assert(t2)
    return not (t1.fromFrame.frameNumber > t2.fromFrame.frameNumber or
                t1.toFrame.frameNumber < t2.toFrame.frameNumber)
  end

  local function getValidtags()
    ---@type Tag[]
    local tags = {}
    for _, tag in ipairs(self.sprite.tags) do
      if (not self.scopeTag or (tag ~=self.scopeTag and tagContainsTag(self.scopeTag, tag))) and
         tagContainsFrame(tag, self.frame) and not isTagSeen(tag) then
        table.insert(tags, tag)
      end
    end
    return tags
  end

  local function getParentForward()
    if #activeTags == 0 then
      return delta
    end
    return activeTags[#activeTags].forward
  end

  ---@param playTag PlayTag
  ---@return Frame
  local function firstTagFrame(playTag)
    assert(playTag)
    return playTag.forward < 0 and playTag.tag.toFrame or playTag.tag.fromFrame
  end

  ---@param playTag PlayTag
  ---@return Frame
  local function lastTagFrame(playTag)
    assert(playTag)
    return playTag.forward > 0 and  playTag.tag.toFrame or playTag.tag.fromFrame
  end

  ---@type function
  local handleExitFrame
    ---@type function
  local nextFrame

  ---@param step integer
  ---@param firstTime boolean
  local function handleEnterFrame(step, firstTime)
    --print("Entering Frame: "..tostring(self.frame.frameNumber))
    self.dialog:modify({id="anim_slider", value=self.frame.frameNumber})
    self:repaint()

    local initialFrame = self.frame
    local forward = getParentForward()
    for _, t in ipairs(getValidtags()) do
      local currentTag = activeTags[#activeTags]
      if currentTag == nil or tagContainsTag(currentTag.tag, t) then
        addTag(t, false, forward)
        if not firstTime then
          self.frame = getParentForward() < 0 and t.toFrame or t.fromFrame
          if (initialFrame ~= self.frame) then
            handleEnterFrame(step, false)
            return
          end
        end
      else
        -- Cascade
        addTag(t, true, forward)
      end
    end

    self.aTimer = Timer{
      interval=self.frame.duration,
      ontick=function ()
        self.aTimer:stop()
        self.aTimer = nil

        nextFrame(step)
      end
    }
    self.aTimer:start()
  end

  ---@param step integer
  ---@return boolean
  local function decrementRepeat(step)

    while true do
      local continue = false -- flag for emulating continue
      local oldTag = activeTags[#activeTags]
      assert(oldTag)
      if oldTag and (oldTag.repeats == nil or oldTag.repeats > 1) then
        if oldTag.repeats then oldTag.repeats = oldTag.repeats - 1 end
        self.frame = firstTagFrame(oldTag)

        -- tag has only 1 frame, then don't count as move
        return oldTag.tag.frames > 1
      else
        -- remove tag from seen
        if oldTag.delayedDelete == nil then
          removeTagFromSeen(oldTag)
        end
        -- delete and remove playTag
        table.remove(activeTags)
        --printStack()

        -- forward of parent
        local parTag = activeTags[#activeTags]
        local forward = parTag and parTag.forward or delta
        local rewind = parTag and parTag.rewind or false

        -- New frame outside of tag
        ---@type integer
        local newFrameNum
        if rewind and parTag then
          --print("rewind to ".. parTag.tag.name)
          newFrameNum = firstTagFrame(parTag).frameNumber
        else
          newFrameNum = step * forward < 0 and
            oldTag.tag.fromFrame.frameNumber-1 or oldTag.tag.toFrame.frameNumber + 1
        end

        if newFrameNum < 1 or newFrameNum > #self.sprite.frames then
          if newFrameNum < 1 then
            if parTag == nil then
              newFrameNum = #self.sprite.frames
            else
              if parTag.repeats == nil or parTag.repeats > 1 then
                if parTag.tag.aniDir == AniDir.PING_PONG_REVERSE then
                  parTag.forward = -parTag.forward
                  if parTag.repeats then parTag.repeats = parTag.repeats - 1 end
                  newFrameNum = oldTag.tag.toFrame.frameNumber + 1
                end
              else
                continue = true
              end
            end
          elseif newFrameNum > #self.sprite.frames then
            if #activeTags == 0 and oldTag.tag.aniDir == AniDir.PING_PONG_REVERSE and
               oldTag.tag.fromFrame.frameNumber == 1 and 
               oldTag.tag.toFrame.frameNumber == #self.sprite.frames then
              self.frame = self.sprite.frames[#self.sprite.frames]
              handleEnterFrame(step, false)
              if #activeTags > 1 then
                activeTags[#activeTags].forward = -activeTags[#activeTags].forward
                self.frame = firstTagFrame(activeTags[#activeTags])
              end
              return false
            end

            if #activeTags > 0 and oldTag.tag.toFrame == activeTags[#activeTags].tag.toFrame then
              parTag = activeTags[#activeTags]
              if (parTag.repeats and parTag.repeats <= 1) then
                continue = true
              else
                if parTag.tag.aniDir == AniDir.PING_PONG or
                   parTag.tag.aniDir == AniDir.PING_PONG_REVERSE then
                  parTag.forward = -parTag.forward
                  newFrameNum = oldTag.tag.fromFrame.frameNumber - 1
                elseif parTag.tag.aniDir == AniDir.FORWARD then
                  if parTag.repeats then parTag.repeats = parTag.repeats - 1 end
                  newFrameNum = parTag.tag.fromFrame.frameNumber
                else
                  newFrameNum = 1
                end
              end
            else
              newFrameNum = 1
            end
          end
        end

        if not continue then
          self.frame = self.sprite.frames[newFrameNum]
          local newTag = activeTags[#activeTags]
          if newTag then
            if tagContainsFrame(newTag.tag, self.frame) then
              return false
            end
          else
            if #activeTags == 0 and 
              (oldTag.tag.aniDir == AniDir.PING_PONG or oldTag.tag.aniDir == AniDir.PING_PONG_REVERSE) and
              oldTag.tag.fromFrame.frameNumber == 1 and oldTag.tag.toFrame.frameNumber == #self.sprite.frames then
              addTag(oldTag, false, getParentForward())
              return false
            else
              return false
            end
          end
        end
      end
    end
  end

  local function handleScopeCrossing(previousFrameNumber)
    if not self.scopeTag then return false end

    local scopeFrom = self.scopeTag.fromFrame.frameNumber
    local scopeTo = self.scopeTag.toFrame.frameNumber
    local frameNumber
    local boundary
    if not self.frame then
      if previousFrameNumber == scopeFrom then
        boundary = scopeFrom
      elseif previousFrameNumber == scopeTo then
        boundary = scopeTo
      else
        return false
      end
    else
      frameNumber = self.frame.frameNumber
      if frameNumber < scopeFrom then
        boundary = scopeFrom
      elseif frameNumber > scopeTo then
        boundary = scopeTo
      else
        return false
      end
    end

    if self.scopeTag.aniDir == AniDir.PING_PONG or
       self.scopeTag.aniDir == AniDir.PING_PONG_REVERSE then
      delta = -delta
      frameNumber = math.max(math.min(boundary + delta, scopeTo), scopeFrom)
    elseif delta > 0 then
      frameNumber = scopeFrom
    else
      frameNumber = scopeTo
    end

    self.frame = self.sprite.frames[frameNumber]
    return true
  end

  ---@param step integer
  ---@return boolean
  handleExitFrame = function (step)
    local curTag = activeTags[#activeTags]
    if curTag and tagContainsFrame(curTag.tag,self.frame) then
      local tag = curTag.tag
      if (tag.aniDir == AniDir.FORWARD or tag.aniDir == AniDir.REVERSE) and
         (step > 0 and self.frame == lastTagFrame(curTag)) then
        local previousFrameNumber = self.frame.frameNumber
        decrementRepeat(step)
        handleScopeCrossing(previousFrameNumber)
        return false
      elseif (tag.aniDir == AniDir.PING_PONG or tag.aniDir == AniDir.PING_PONG_REVERSE) and
             self.frame == lastTagFrame(curTag) then
        curTag.forward = -curTag.forward
        local previousFrameNumber = self.frame.frameNumber
        local move = decrementRepeat(step)
        if handleScopeCrossing(previousFrameNumber) then return false end
        return move
      elseif step < 0 and self.frame == firstTagFrame(curTag) then
        self.frame = lastTagFrame(curTag)
        return false
      end
    end

    
    if self.scopeTag then
      if (self.scopeTag.aniDir == AniDir.FORWARD or self.scopeTag.aniDir == AniDir.REVERSE) then
        if (delta > 0 and self.frame == self.scopeTag.toFrame) then
          self.frame = self.scopeTag.fromFrame
          return false
        elseif (delta < 0 and self.frame == self.scopeTag.fromFrame) then
          self.frame = self.scopeTag.toFrame
          return false
        end
      elseif (self.scopeTag.aniDir == AniDir.PING_PONG or self.scopeTag.aniDir == AniDir.PING_PONG_REVERSE) and
             ((delta > 0 and self.frame == self.scopeTag.toFrame) or (delta < 0 and self.frame == self.scopeTag.fromFrame)) then
        delta = -delta
        local frameNum = math.max(
          math.min(self.frame.frameNumber + delta, self.scopeTag.toFrame.frameNumber),
          self.scopeTag.fromFrame.frameNumber
        )
        self.frame = self.sprite.frames[frameNum]
        return false
      end
    elseif delta > 0 and self.frame.frameNumber == #self.sprite.frames then
      self.frame = self.sprite.frames[1]
      return false
    elseif delta < 0 and self.frame.frameNumber == 1 then
      self.frame = self.sprite.frames[#self.sprite.frames]
      return false
    end

    return true
  end

  ---@param step integer
  local function handleMoveFrame(step)
    self.frame = self.sprite.frames[self.frame.frameNumber + step * getParentForward()]
  end

  ---@param step integer
  nextFrame = function (step)
    local move = handleExitFrame(step)
    --print("Exit frame to : "..tostring(self.frame.frameNumber))
    if move then
      handleMoveFrame(step)
      --print("Moved frame to: "..tostring(self.frame.frameNumber))
    end
    handleEnterFrame(step, false)
  end

  --print("Playback start ----------------------------------")
  -- move frame to within scope tag
  if self.scopeTag then
    delta = delta * getTagForward(self.scopeTag)
    if not tagContainsFrame(self.scopeTag, self.frame) then
      self.frame = delta > 0 and self.scopeTag.fromFrame or self.scopeTag.toFrame
    end
  end
  
  handleEnterFrame(delta, true)
end

return Playback
