local Playback = dofile("./playback.lua")

--- @type table<integer, Preview>
local previews = {}

-- Tile modes
local Tiled = {
  None = 1,
  Both = 2,
  X = 3,
  Y = 4
}

--- Scales for zooming represnted by numerator and denominator
---@type integer[][]
local zoomScales = {
  { 1,  64 },
  { 1,  48 },
  { 1,  32 },
  { 1,  24 },
  { 1,  16 },
  { 1,  12 },
  { 1,  8  },
  { 1,  6  },
  { 1,  5  },
  { 1,  4  },
  { 1,  3  },
  { 1,  2  },
  { 2,  3  }, -- 60%
  { 4,  5  }, -- 80%
  { 1,  1  }, -- 100%
  { 3,  2  }, -- 150%
  { 2,  1  },
  { 3,  1  },
  { 4,  1  },
  { 5,  1  },
  { 6,  1  },
  { 8,  1  },
  { 12, 1  },
  { 16, 1  },
  { 24, 1  },
  { 32, 1  },
  { 48, 1  },
  { 64, 1  },
}
local scalesSize = #zoomScales

---return scale from index in zoomScales
---@param l integer
---@return number
local function scaleFromZoomLevel(l)
  return zoomScales[l][1] / zoomScales[l][2]
end

---@param scale number
---@return integer
local function findClosestZoomLevel(scale)
  local left = 1
  local right = scalesSize
  local mid

  while left <= right do
    mid = (left + right) // 2

    local testScale = scaleFromZoomLevel(mid)
    if testScale == scale then
      return mid 
    end
    if testScale > scale then
      right = mid - 1
    else
      left = mid + 1
    end
  end
  return mid
end

local defaultZoomLevel= findClosestZoomLevel(1.0)

-----------------------------------------------------------------------
-- API related helper functions
-----------------------------------------------------------------------

---Add two point parameters and return a new point object
---@param a Point
---@param b Point
---@return Point
local function addPoints(a, b)
    return Point(a.x + b.x, a.y + b.y)
end

---Add two point parameters and return a new point object
---@param a Point
---@param b Point
---@return Point
local function subPoints(a, b)
    return Point(a.x - b.x, a.y - b.y)
end

---Multiply point vector by a scalar
---@param vect Point
---@param scalar number
---@return Point
local function mulVect(vect, scalar)
    return Point(vect.x*scalar, vect.y*scalar)
end

---Modify dialog widgets without losing the user's current window size or position
---@param dialog Dialog
---@param modifications table[]
local function modifyDialogKeepBounds(dialog, modifications)
  local bounds = dialog.bounds
  for _, modification in ipairs(modifications) do
    dialog:modify(modification)
  end

  dialog.bounds = Rectangle(bounds.x, bounds.y, bounds.width, bounds.height)
end

-----------------------------------------------------------------------
-- Helpers
-----------------------------------------------------------------------

---@param t any
---@return table
local function getKeys(t)
  local keys = {}
  for key, value in pairs(t) do
    table.insert(keys, key)
  end
  return keys
end

---Draw the flattened image of all layers in the group onto the image
---@param image Image Image being drawn to
---@param layer Layer Root layer
---@param frameNum integer 
---@param offset Point
---@return nil
local function combineLayers(image, layer, frameNum, offset)
  if not layer.isVisible then return end

  local cel = layer:cel(frameNum)
  if not layer.isGroup then
    if cel then
      image:drawImage(
        cel.image,
        addPoints(cel.position, offset),
        math.floor((cel.opacity/255) * layer.opacity),
        layer.blendMode)
    end
    return
  end
  -- combine child layers, starting from lowest
  for _, l in ipairs(layer.layers) do
    combineLayers(image, l, frameNum, offset)
  end
end


-----------------------------------------------------------------------
-- Preview Plus object
-----------------------------------------------------------------------

---@class Preview
---@field dialog Dialog | nil   dialog object
---@field sprite Sprite | nil   reference to sprite it displays
---@field listeners integer[]   list of sprite listener ids
---@field visible boolean       true if currently visible
---@field open boolean          true if toggled on, whether or not currently visible
---@field spritePos Point       Position of the origin of sprite within the canvas
---@field zoomLevel integer     index on the zoom_scales array
---@field mouseDragging boolean True if being panned by mouse
---@field dragPos Point         Last position of mouse while dragging
---@field lastCanvasSize Point  Last recorded size of preview canvas
---@field isolateLayer boolean  true if showing just the active layer
---@field area Rectangle        area of sprite currently shown
---@field tileMode integer
---@field playing boolean       if currently playing animation
---@field frame Frame current   frame being displayed
---@field aTimer Timer|nil      animation timer
---@field scopeTag Tag|nil      Current scope for playback, nil means all frames
---@field ignoreTags boolean    Ignore all tags (except scope tag)
local Preview = {}

Preview.stopPlayback = Playback.stopPlayback
Preview.startPlayback = Playback.startPlayback

--- @return Preview
function Preview:new()
  -- create preview object
  local o = {}
  setmetatable(o, self)
  self.__index = self

  o.spritePos = Point(10,10)
  o.zoomLevel = defaultZoomLevel
  o.sprite = app.sprite
  o.visible = false
  o.open = false
  o.mouseDragging = false
  o.lastCanvasSize = Point(180,200)
  o.tileMode = Tiled.None
  o.playing = false
  o.frame = app.frame
  o.aTimer = nil
  o.scopeTag = nil
  o.ignoreTags = false
  o.listeners = {}

  o:setArea(app.sprite.bounds)
  o:createDialog()

  table.insert(o.listeners, o.sprite.events:on('change', function(ev) o:repaint(ev) end))
  table.insert(o.listeners, o.sprite.events:on('layeropacity', function(ev) o:repaint(ev) end))
  table.insert(o.listeners, o.sprite.events:on('layervisibility', function(ev) o:repaint(ev) end))
  return o
end

--- @return nil
function Preview:show()
  self.dialog:show{wait=false}
  self.visible = true
  self.open = true
  self:repaint()
end

--- @return nil
function Preview:updateVisibility()
  if app.sprite == self.sprite and not self.visible and self.open then
    self:show()
    return
  end
  -- still open but hide when other sprite is open
  if app.sprite ~= self.sprite and self.visible and not self.pinned then
    self.dialog:close()
    -- open is set to false by default but it is actually still open
    -- flip open back to true
    self.open = true
  end
end

--- @return nil
function Preview:updateFrame()
  if app.sprite ~= self.sprite then
    return
  end
  if not self.playing then
    self.frame = app.frame
    self.dialog:modify({id="anim_slider", max=#self.sprite.frames, value=self.frame.frameNumber})
    return
  end
  self.dialog:modify({id="anim_slider", max=#self.sprite.frames})
end

--- @return nil
function Preview:repaint()
  self.dialog:repaint()
end

--- @return nil
function Preview:disconnect()
  for _, listener in pairs(self.listeners) do
    self.sprite.events:off(listener)
  end
end

---return the current scale according to zoom
---@return number
function Preview:scale()
  return scaleFromZoomLevel(self.zoomLevel)
end

---update zoom to a given zoom level
---@param level integer new zoom level
---@param ev MouseEvent|nil
---@return boolean return true if zoom updated
function Preview:zoomTo(level, ev)
  assert(1 <= level and level <= scalesSize)
  if level == self.zoomLevel then return false end

  local oldScale = self:scale()
  self.zoomLevel = level
  self.dialog:modify{id="zoom_slider", value = level-defaultZoomLevel}
  
  -- update sprite position so we zoom on mouse position
  local target = Point(0.5*self.lastCanvasSize.x, 0.5*self.lastCanvasSize.y)
  if ev then target = Point(ev.x, ev.y) end
  self.spritePos = target + mulVect(subPoints(self.spritePos, target), self:scale() / oldScale)

  return true
end

---update zoom in or out by one level
---@param zoomIn boolean true if zooming in, false if out
---@param ev MouseEvent|nil
---@return boolean return true if zoom updated
function Preview:zoomStep(zoomIn, ev)
  local direction = zoomIn and 1 or -1
  local newLevel = self.zoomLevel + direction
  if newLevel < 1 or newLevel > scalesSize then return false end

  return self:zoomTo(newLevel, ev)
end

---Set cropped area to view
---@param bounds Rectangle
function Preview:setArea(bounds)
  if self.area == bounds then return end
  
  -- center the view
  local areaCenter = Point(bounds.x+bounds.w/2, bounds.y+bounds.h/2)
  self.spritePos = Point(self.lastCanvasSize.x/2, self.lastCanvasSize.y/2) - mulVect(areaCenter,self:scale())
  self.area = bounds
  if self.dialog then self.dialog:repaint() end
end

----------------------------------------------------------------------------
-- Creates main dialog
---------------------------------------------------------------------------- 

--- @protected
--- @return nil
function Preview:createDialog()
  local dialog
  -------------------------------------------------------------------------
  -- Maintain combobox options
  -------------------------------------------------------------------------
  local areas = {["Canvas"]=self.sprite.bounds} ---@type table<string, Rectangle>
  local tags = {["Canvas"]=0}  ---@type table<string, any>

  -- guard for option update unecessarily resetting selection
  local refreshingAreaOptions = false
  local refreshingTagOptions = false

  local function updateAreas()
    areas = {}
    if self.sprite then
      areas["Canvas"] = self.sprite.bounds
      if self.sprite.selection and not self.sprite.selection.isEmpty then
        areas["Selection"] = self.sprite.selection.bounds
      end
      for i = #self.sprite.slices, 1, -1 do
        local name = self.sprite.slices[i].name
        local count = 1
        -- avoid name collisions
        while areas[name] ~= nil do
          count = count + 1
          name = self.sprite.slices[i].name .. " (#" .. tostring(count) .. ")"
        end
        areas[name] = self.sprite.slices[i].bounds
      end
    end
    local currentArea = dialog.data["area_combo"]
    
    refreshingAreaOptions = true
    local sortedOptions = getKeys(areas)
    table.sort(sortedOptions, function (a, b)
      if a == "Canvas" then return true end
      if a == "Selection" then
        return b ~= "Canvas"
      end
      return a < b
    end)
    dialog:modify{
      id="area_combo",
      options=sortedOptions,
      option=currentArea
    }
    dialog.data["area_combo"] = currentArea
    refreshingAreaOptions = false

    if areas[currentArea] == nil or areas[currentArea] ~= self.area then
      if areas[currentArea] == nil then currentArea = "Canvas" end
      dialog:modify{ id="area_combo", option=currentArea }
      self:setArea(areas[currentArea])
    end
  end

  local function updateTags()
    tags = {}
    if self.sprite then
      tags["All Frames"] = 0

      for _, tag in ipairs(self.sprite.tags) do
        if true then
        -- if self.frame.frameNumber >= tag.fromFrame.frameNumber and
        --   self.frame.frameNumber <= tag.toFrame.frameNumber then
          local name = tag.name
          local count = 1
          -- avoid name collisions
          while tags[name] ~= nil do
            count = count + 1
            name = tag.name .. " (#" .. tostring(count) .. ")"
          end
          tags[name] = tag
        end
      end
    end
    local currentTag = dialog.data["anim_combo"]
    
    refreshingTagOptions = true
    local sortedOptions = getKeys(tags)
    table.sort(sortedOptions, function (a, b)
      if a == "All Frames" then return true end
      if b == "All Frames" then return false end
      return tags[a].fromFrame.frameNumber < tags[b].fromFrame.frameNumber
    end)
    dialog:modify{
      id="anim_combo",
      options=sortedOptions,
      option=currentTag
    }
    refreshingTagOptions = false

    if tags[currentTag] == nil then
      dialog:modify{ id="anim_combo", option="All Frames" }
      self.scopeTag = nil
    end
  end

  -------------------------------------------------------------------------
  -- Dialog Setup
  -------------------------------------------------------------------------
  dialog = Dialog{
    title="Preview+",
    notitlebar=false,
    onclose=function()
      self.visible = false
      self.open = false
    end
  }

  dialog
  :check{ id="expand_check",
    text="Expand",
    selected=false,
    focus=false,
    onclick=function()
      local vis = dialog.data["expand_check"]
      local bounds = dialog.bounds
      local preSizeHint = dialog.sizeHint
      local widgets = {
        "pin_check",
        "layer_check",
        "zoom_separator",
        "zoom_slider",
        "area_separator",
        "area_combo",
        "tile_separator",
        "tile_combo",
        "anim_separator",
        "anim_combo",
        "anim_slider",
        "ignore_check",
      }
      for _, widget in ipairs(widgets) do
        dialog:modify({id=widget, visible=vis})
      end

      dialog.bounds = Rectangle(bounds.x, bounds.y, bounds.width,
        bounds.height + dialog.sizeHint.h - preSizeHint.h
      )
    end
  }
  :check{ id="play_check",
    text="Playing",
    selected=false,
    focus=false,
    onclick=function()
      self.playing = dialog.data["play_check"]
      if self.playing then
        self:startPlayback()
      else
        self:stopPlayback()
      end
    end
  }
  :canvas{ id="myCanvas",
    width=self.lastCanvasSize.x,
    height=self.lastCanvasSize.y,
    visible=true,
    onpaint=function (ev)
      --- @type GraphicsContext
      local gc = ev.context
      self.lastCanvasSize = Point(gc.width, gc.height)

      local themeColor = app.theme.color --[[@as ThemeColor]]
      -- fill background
      gc.color = themeColor.editor_face
      gc:fillRect(0,0,gc.width,gc.height)

      if self.sprite then
        local scale = self:scale()
        local cropTexelBounds = self.area
        if cropTexelBounds.w > 0 and cropTexelBounds.h > 0 then
          
          -- display bounds if tiled
          local x_tile = (self.tileMode == Tiled.Both or self.tileMode == Tiled.X) and 1 or 0
          local y_tile = (self.tileMode == Tiled.Both or self.tileMode == Tiled.Y) and 1 or 0
          local displayTexelBounds = Rectangle(
            cropTexelBounds.origin.x - x_tile * cropTexelBounds.w,
            cropTexelBounds.origin.y - y_tile * cropTexelBounds.h,
            cropTexelBounds.w + x_tile * 2 * cropTexelBounds.w,
            cropTexelBounds.h + y_tile * 2 * cropTexelBounds.h
          )
          local displayOffset = mulVect(displayTexelBounds.origin, scale)
          local displayBounds = Rectangle(
            self.spritePos.x+displayOffset.x, self.spritePos.y+displayOffset.y,
            displayTexelBounds.w*scale, displayTexelBounds.h*scale
          )
          
          -- body of canvas that is being drawn to (canvas excluding border)
          local borderW = 3  -- possibly changes with theme
          local canvasBody = Rectangle(borderW, borderW, gc.width - 2*borderW, gc.height - 2*borderW)
          
          -- bound cropped position such that it doesn't leave the screen
          -- with a max bound of half the width/height
          -- local cropSize = floorPoint(Point(croppedImage.width * scale, croppedImage.height * scale))
          local h_bound = math.min(canvasBody.width/2, displayBounds.w)
          local v_bound = math.min(canvasBody.height/2, displayBounds.h)

          displayBounds.x = math.min(displayBounds.x, canvasBody.x+canvasBody.width-h_bound) -- left bound
          displayBounds.x = math.max(displayBounds.x, canvasBody.x+h_bound-displayBounds.w) -- right bound
          displayBounds.y = math.min(displayBounds.y, canvasBody.y+canvasBody.height-v_bound)-- bottom bound
          displayBounds.y = math.max(displayBounds.y, canvasBody.y+v_bound-displayBounds.h) -- top bound

          -- update sprite pos to match
          self.spritePos = subPoints(displayBounds.origin, displayOffset)

          -- snap to world pixels
          displayBounds = Rectangle(math.floor(displayBounds.x), math.floor(displayBounds.y),
                                math.floor(displayBounds.w), math.floor(displayBounds.h))

          local fullImage = Image(cropTexelBounds.w, cropTexelBounds.h)
          
          -- -- draw checkerboard for transparency
          local s = 16
          local rc = fullImage.context
          -- draw checkerboard
          for i = cropTexelBounds.x // s, (cropTexelBounds.x + cropTexelBounds.w) // s do
            for j = cropTexelBounds.y // s, (cropTexelBounds.y + cropTexelBounds.h) // s do
              if (i + j) % 2 == 0 then
                rc.color = Color{ gray=128, alpha=255 }
              else
                rc.color = Color{ gray=192, alpha=255 }
              end
              rc:fillRect(i*s - cropTexelBounds.x, j*s - cropTexelBounds.y, s, s)
            end
          end

          -- get image depending on isolating layers and frame
          local spriteImage = Image(cropTexelBounds.w, cropTexelBounds.h)
          if self.isolateLayer then
            combineLayers(spriteImage, app.layer, self.frame.frameNumber, Point(-cropTexelBounds.x, -cropTexelBounds.y))
          else
            spriteImage:drawSprite(self.sprite, self.frame.frameNumber,
              Point(-cropTexelBounds.x, -cropTexelBounds.y)
            )
          end
          fullImage:drawImage(spriteImage)

          -- repeat image base on tiling
          local displayImage
          if not x_tile and not y_tile then
            displayImage = fullImage
          else
            displayImage = Image(displayTexelBounds.w, displayTexelBounds.h)
            for i = 0, x_tile*2 do
              for j = 0, y_tile*2 do
                displayImage:drawImage(fullImage, Point(i*fullImage.width, j*fullImage.height))
              end
            end
          end

          if scale % 1 ~= 0 and scale < 2 then
            -- Rasterize at a fixed origin before translating, so panning does not
            -- change the sampling phase used to scale the sprite.
            local scaledImage = Image(displayBounds.w, displayBounds.h)
            scaledImage.context:drawImage(displayImage, displayImage.bounds, scaledImage.bounds)
            
            gc:drawImage(scaledImage, scaledImage.bounds, displayBounds)
          else
            gc:drawImage(displayImage, displayImage.bounds, displayBounds)
          end
          
          -- draw border around image
          gc.color = themeColor.editor_sprite_border
          gc:strokeRect(displayBounds.x-1, displayBounds.y-1, displayBounds.width+2, displayBounds.height+2)

          -- draw line below border
          gc.color = themeColor.editor_sprite_bottom_border
          gc:beginPath()
          gc:moveTo(displayBounds.x-1, displayBounds.y + displayBounds.height+1)
          gc:lineTo(displayBounds.x + displayBounds.width, displayBounds.y + displayBounds.height+1)
          gc:stroke()
        end

        -- debug text
        -- gc.color = Color{gray=255,alpha=100}
        -- gc:fillRect(0,gc.height-50,150,50)
        -- gc.color = Color{r=0,g=0,b=0,a=255}
        -- gc:fillText("Scale  : " .. tostring(scale), 5, gc.height - 50)
      end
      -- draw border around the preview
      gc:drawThemeRect('editor_selected', Rectangle(0,0,gc.width,gc.height))

    end,

    onmousedown=function(ev)
      --dialog:modify{id="center", text="down"}
      self.mouseDragging = true
      self.dragPos = Point(ev.x, ev.y)
      dialog:modify{ id="myCanvas", mousecursor=MouseCursor.GRABBING }
    end,

    onmouseup=function(ev)
      --dialog:modify{id="center", text="up"} -- resets size for some reason
      self.mouseDragging = false
      dialog:modify{ id="myCanvas", mousecursor=MouseCursor.MOVE }
    end,

    onmousemove=function (ev)
      if self.mouseDragging then
        local newDragPos = Point(ev.x, ev.y)
        self.spritePos = addPoints(
          self.spritePos, 
          subPoints(newDragPos, self.dragPos)
        )
        self.dragPos = newDragPos

        self:repaint()
      end
    end,

    onwheel=function(ev)
      if ev.deltaY == 0 then return end
      
      if self:zoomStep(ev.deltaY < 0, ev) then
        self:repaint()
      end
    end
  }
  :check{ id="pin_check",
    text="Pin Window",
    selected=false,
    focus=false,
    visible=false,
    onclick=function() 
      self.pinned = dialog.data["pin_check"]

      -- case where window should disappear when unpinned
      if not self.pinned then
        self:updateVisibility()
      end
    end
  }
  :check{ id="layer_check",
    text="Isolate Layer",
    selected=false,focus=false,
    visible=false,
    onclick=function() 
      self.isolateLayer = dialog.data["layer_check"]
      self:repaint()
    end
  }
  :separator{ id="zoom_separator",
    text="Zoom Level",
    visible=false,
  }
  :slider{ id="zoom_slider",
    visible=false,
    focus=false,
    min=1-defaultZoomLevel,
    max=scalesSize-defaultZoomLevel,
    value=self.zoomLevel-defaultZoomLevel,
    onchange=function ()
      self:zoomTo(dialog.data["zoom_slider"] + defaultZoomLevel)
      self:repaint()
    end,
    onrelease=function () end
  }
  :separator{ id="area_separator",
    text="Area",
    visible=false,
  }
  :combobox{ id="area_combo",
    visible=false,
    option="Canvas",
    options=getKeys(areas),
    onchange=function() 
      if refreshingAreaOptions then return end
      self:setArea(areas[dialog.data["area_combo"]])
    end
  }
  :separator{ id="tile_separator",
    text="Tiled",
    visible=false,
  }
  :combobox{ id="tile_combo",
    visible=false,
    option="None",
    options={"None", "Tiled in Both Axes", "Tiled in X Axis", "Tiled in Y Axis"},
    onchange=function()
      local mode = dialog.data["tile_combo"]
      if mode == "Tiled in Both Axes" then
        self.tileMode = Tiled.Both
      elseif mode == "Tiled in X Axis" then
        self.tileMode = Tiled.X
      elseif mode == "Tiled in Y Axis" then
        self.tileMode = Tiled.Y
      else
        self.tileMode = Tiled.None
      end
      self:repaint()
    end
  }
  :separator{ id="anim_separator",
  text="Animation",
  visible=false,
  }
  :check{ id="ignore_check",
    visible=false,
    text="Ignore Tags",
    selected=self.ignoreTags,
    focus=false,
    onclick=function()
      self.ignoreTags = dialog.data["ignore_check"]
    end
  }
  :slider{ id="anim_slider",
    visible=false,
    focus=false,
    min=1,
    max=#self.sprite.frames,
    value=self.frame.frameNumber,
    onchange=function ()
      if self.playing then
        self:stopPlayback()
      end
      self.frame = self.sprite.frames[dialog.data["anim_slider"]]
      self:repaint()
    end,
    onrelease=function () end
  }
  :combobox{ id="anim_combo",
    visible=false,
    option="All frames",
    options={"All frames"},
    onchange=function()
      if refreshingTagOptions then return end
      if dialog.data["anim_combo"] == "All Frames" then
        self.scopeTag = nil
      else
        self.scopeTag = tags[dialog.data["anim_combo"]]
      end
    end
  }

  dialog:modify{ id="myCanvas", mousecursor=MouseCursor.MOVE }
  self.dialog = dialog

  updateTags()
  updateAreas()
  table.insert(self.listeners, self.sprite.events:on('change', function(ev)
    updateTags()
    updateAreas() end))
end

-----------------------------------------------------------------------
-- Manage Previews
-----------------------------------------------------------------------

---@return Preview | nil
local function GetCurrentPreview()
  if app.sprite == nil then return nil end
  return previews[app.sprite["id"]]
end

---@return boolean
local function CurrentPreviewOpen()
  local preview = GetCurrentPreview()
  if preview ~= nil then
    return preview.visible
  end
  return false
end

--- @return nil
local function ToggleCurrentPreview()
  local sprite = app.sprite
  if sprite == nil then 
    app.alert("No active sprite")
    return
  end

  local preview = GetCurrentPreview()
  -- Toggle existing preview
  if preview then
    if preview.visible then
      preview.dialog:close()
    else
      preview:show()
    end
    return
  end
  -- create preview if none exists
  preview = Preview:new()
  previews[sprite["id"]] = preview

  preview:show()
end

local siteListener
---@return nil
local function appSiteChanged()
  for _, preview in pairs(previews) do
    if preview then
      preview:updateVisibility()
      preview:updateFrame()
      preview:repaint()
    end
  end
end

function init(plugin)
  if not app.isUIAvailable then return end

  siteListener = app.events:on('sitechange', appSiteChanged)
  -- Toggle preview for each sprite
  plugin:newCommand{
    id="preview-plus",
    title="Preview Plus",
    group="view_controls",
    onclick=function() ToggleCurrentPreview() end,
    onenabled=function() return app.sprite ~= nil end,
    onchecked=function() return CurrentPreviewOpen() end
  }
end

function exit(plugin)
  app.events:off(siteListener)
  for _, preview in pairs(previews) do
    preview:stopPlayback()
    preview:disconnect()
    if preview.dialog then
      preview.dialog:close()
    end
  end
end