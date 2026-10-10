--- @type table<integer, Preview>
local previews = {}

--- @type integer
local previewCount = 0

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

---Return the point restricted to the bounds of the rectangle (inclusive)
---@param point Point
---@param rect Rectangle
---@return Point
local function clampPoint(point, rect)
    return Point(
      math.min(math.max(point.x, rect.x), rect.x + rect.width-1),
      math.min(math.max(point.y, rect.y), rect.y + rect.height-1)
    )
end

---convert point to integer point by flooring
---@param point any
local function floorPoint(point)
  return   Point(math.floor(point.x), math.floor(point.y))
end


---@class Preview
---@field dialog Dialog | nil dialog object
---@field sprite Sprite | nil reference to sprite it displays
---@field listeners integer[] list of sprite listener ids
---@field visible boolean true if currently visible
---@field open boolean true if toggled on, whether or not currently visible
---@field spritePos Point Position of the origin of sprite within the preview window
---@field zoom number Zoom level
---@field mouseDragging boolean True if being panned by mouse
---@field dragPos Point Last position of mouse while dragging
local Preview = {
  dialog=nil,
  sprite=nil,
  visible=false,
  open=false,
  listeners={},
  spritePos=Point(0,0),
  zoom=1.0,
  mouseDragging=false,
  dragPos=Point(0,0)
}

--- Returns a point in sprite space converted to canvas space
--- Image space is defined by it's current position relative to the canvas
--- @protected
--- @param point Point
--- @return Point
function Preview:spriteToCanvasCoord(point)
  return addPoints(mulVect(point, self.zoom), self.spritePos)
end

--- Converts the size from sprite space to canvas space according to the zoom level
--- @protected
--- @param size Point a point representing the size of a rectangle
--- @return Point
function Preview:spriteToCanvasSize(size)
  return Point(size.x * self.zoom, size.y * self.zoom)
end

--- Returns the size of the sprite 
--- Sprite space is defined by it's current position relative to the canvas
--- @protected
--- @param point Point
--- @return Point
function Preview:CanvasToSpriteCoord(point)
  return mulVect(subPoints(point, self.spritePos), 1/self.zoom)
end

--- @protected
--- @return nil
function Preview:createDialog()
  local dialog = Dialog{
    title="Preview Plus",
    notitlebar=false,
    onclose=function()
      self.visible = false
      self.open = false
    end
  }

  dialog
  :button{
    id="center",
    label="",
    text=self.mou,
    selected=false,
    focus=false
  }
  :canvas{
    id="myCanvas",
    width=200,
    height=200,
    onpaint=function (ev)
      --- @type GraphicsContext
      local gc = ev.context
      if self.sprite then
        -- TODO: Option ot Isolate active layer
        local spriteImage = Image(self.sprite) --[[@as Image]]

        -- overlay the full sprite over a checkerboard pattern for transparent values
        local fullImage = Image(spriteImage.width, spriteImage.height)
        local squareSize = 16
        local cxt = fullImage.context
        -- draw checkerboard
        for i = 0, (fullImage.width // 16) do
          for j = 0, (fullImage.width // 16) do
            if (i + j) % 2 == 0 then
              cxt.color = Color{ gray=128, alpha=255 }
            else
              cxt.color = Color{ gray=192, alpha=255 }
            end
            cxt:fillRect(i*squareSize, j*squareSize, squareSize, squareSize)
          end
        end
        -- compose
        fullImage:drawImage(spriteImage)

        -- TODO: Choose area to crop from
        local imagePos = self.spritePos
        local offset = subPoints(self.spritePos, imagePos)
        local croppedImage = fullImage

        -- body of canvas that is being drawn to (canvas excluding border)
        local b_width = 3
        local body = Rectangle(b_width, b_width, gc.width - 2*b_width, gc.height - 2*b_width)

        -- bound cropped position such that it doesn't leave the screen
        -- with a max bound of half the width/height
        -- (a bit weird to put it here but I need the graphics context)
        local cropSize = floorPoint(Point(croppedImage.width * self.zoom, croppedImage.height*self.zoom))
        local h_bound = math.min(body.width/2, cropSize.x)
        local v_bound = math.min(body.height/2, cropSize.y)

        imagePos.x = math.min(imagePos.x, body.x+body.width-h_bound)
        imagePos.x = math.max(imagePos.x, body.x+h_bound-cropSize.x)
        imagePos.y = math.min(imagePos.y, body.y+body.height-v_bound)
        imagePos.y = math.max(imagePos.y, body.y+v_bound-cropSize.y)

        -- update sprite pos to match
        self.spritePos = addPoints(imagePos, offset)

        -- integer rectangle of image on canvas
        local imageRect = Rectangle(math.floor(imagePos.x), math.floor(imagePos.y), cropSize.x, cropSize.y)

        -- fill background
        gc.color = app.theme.color.editor_face
        gc:fillRect(0,0,gc.width,gc.height)

        
        -- draw image onto background
        gc:drawImage(croppedImage, croppedImage.bounds, imageRect)
        
        -- draw border around image
        gc.color = app.theme.color.editor_sprite_border
        gc:strokeRect(imageRect.x-1, imageRect.y-1, imageRect.width+2, imageRect.height+2)

        -- draw line below border
        gc.color = app.theme.color.editor_sprite_bottom_border
        gc:beginPath()
        gc:moveTo(imageRect.x-1, imageRect.y + imageRect.height+1)
        gc:lineTo(imageRect.x + imageRect.width, imageRect.y + imageRect.height+1)
        gc:stroke()

        -- draw border around the preview
        gc:drawThemeRect('editor_selected', Rectangle(0,0,gc.width,gc.height))

        -- debug text
        -- gc.color = Color{gray=255,alpha=100}
        -- gc:fillRect{0,gc.height-50,150,50}
        -- gc.color = Color{r=0,g=0,b=0,a=255}
        -- gc:fillText("gc size: (" .. tostring(gc.width) .. ", " .. tostring(gc.height) .. ")", 5, gc.height - 40)
        -- gc:fillText("Sprite Pos: (" .. tostring(self.spritePos.x) .. ", " .. tostring(self.spritePos.y) .. ")", 5, gc.height - 30)
        -- gc:fillText("ImagPos0: (" .. tostring(imagePoint0.x) .. ", " .. tostring(imagePoint0.y) .. ")", 5, gc.height - 20)
        -- gc:fillText("ImagPos1: (" .. tostring(imagePoint1.x) .. ", " .. tostring(imagePoint1.y) .. ")", 5, gc.height - 10)
      end
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

      local direction = ev.deltaY > 0 and -1 or 1
      local zoomLevel
      if self.zoom >= 1 then zoomLevel = math.floor(self.zoom)
      else zoomLevel = -math.floor(1/self.zoom) end
      local z = self.zoom
      
      if zoomLevel > 1 then self.zoom = zoomLevel + direction
      elseif zoomLevel == 1 then
        if direction > 0 then self.zoom = 2
        else self.zoom = 1/2 end
      else self.zoom = 1/(math.abs(zoomLevel) - direction) end

      --print(ev.deltaY, z .. " => " .. self.zoom)

      self:repaint()
    end
  }
  dialog:modify{ id="myCanvas", mousecursor=MouseCursor.MOVE }
  self.dialog = dialog
end

--- @return Preview
function Preview:new()
  local o = {}   -- create object if user does not provide one
  setmetatable(o, self)
  self.__index = self

  o.spritePos = Point(10,10)
  o.zoom = 1.0
  o.sprite = app.sprite
  o.visible = false
  o.open = false
  o.mouseDragging = false
  o:createDialog()
  o.listeners = {}
  table.insert(o.listeners, o.sprite.events:on('change', function(ev) o:repaint(ev) end))
  table.insert(o.listeners, o.sprite.events:on('layeropacity', function(ev) o:repaint(ev) end))
  table.insert(o.listeners, o.sprite.events:on('layervisibility', function(ev) o:repaint(ev) end))
  return o
end

-- 128, 192

--- @return nil
function Preview:show()
  self.dialog:show{wait=false}
  self.visible = true
  self.open = true
end

--- @return nil
function Preview:updateVisibility()
  if app.sprite == self.sprite and not self.visible and self.open then
    self:show()
    return
  end
  -- still open but hide when other sprite
  if app.sprite ~= self.sprite and self.visible then
    self.dialog:close()
    -- open is set to false by default but it is actuall still open
    -- flip open back to true
    self.open = true
  end
end

--- @param ev any
--- @return nil
function Preview:repaint(ev)
  self.dialog:repaint()
end

--- @return nil
function Preview:disconnect()
  for _, listener in pairs(self.listeners) do
    self.sprite.events:off(listener)
  end
end


---@return Preview | nil
local function GetCurrentPreview()
  if app.sprite == nil then return nil end
  return previews[app.sprite.id]
end

---@return boolean
local function CurrentPreviewOpen()
  local preview = GetCurrentPreview()
  
  if preview ~= nil then
    return preview.visible
  end

  return false
end

--- @param sprite Sprite
--- @return nil
local function TogglePreview(sprite)

  local preview = GetCurrentPreview()
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
  previewCount = previewCount + 1
  previews[sprite.id] = preview

  preview:show()
end

--- @return nil
local function ToggleCurrentPreview()
  local sprite = app.sprite
  if sprite == nil then 
    app.alert("No active sprite") 
    return
  end

  TogglePreview(sprite)
end

local siteListener
---@return nil
local function appSiteChanged()
  for _, preview in pairs(previews) do
    if preview then
      preview:updateVisibility()
      preview:repaint()
    end
  end
end


function init(plugin)
  if not app.isUIAvailable then return end

  if plugin.preferences.count == nil then
    plugin.preferences.count = 0
  end

  siteListener = app.events:on('sitechange', appSiteChanged)
  --
  plugin:newCommand{
    id="preview-plus",
    title="Preview Plus",
    group="view_controls", --"view_new",
    onclick=function()
      plugin.preferences.count = plugin.preferences.count+1
      ToggleCurrentPreview()
    end,
    onenabled=function() return app.sprite ~= nil end,
    onchecked=function()
      return CurrentPreviewOpen()
    end
  }
end

function exit(plugin)
  app.events:off(siteListener)
  for _, preview in previews do
    preview:disconnect()
  end
  print("Aseprite is closing my plugin, MyFirstCommand was called "
        .. plugin.preferences.count .. " times")
end