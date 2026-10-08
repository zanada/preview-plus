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

---Return the point restricted to the bounds of the rectangle (inclusive)
---@param point Point
---@param rect Rectangle
---@return Point
local function clampPoint(point, rect)
    return Point(
      math.min(math.max(point.x, rect.x), rect.width),
      math.min(math.max(point.y, rect.y), rect.height)
    )
end


---@class Preview
---@field dialog Dialog | nil dialog object
---@field sprite Sprite | nil reference to sprite it displays
---@field spriteListener integer | nil
---@field visible boolean true if currently visible
---@field open boolean true if toggled on, whether or not currently visible
---@field spritePos Point Position of the origin of sprite within the preview window
local Preview = {
  dialog=nil,
  sprite=nil,
  visible=false,
  open=false,
  siteListener=nil,
  spritePos=Point(0,0)
}

--- Returns a point in sprite space converted to canvas space
--- Image space is defined by it's current position relative to the canvas
--- @protected
--- @param point Point
--- @return Point
function Preview:spriteToCanvasCoord(point)
  return addPoints(point, self.spritePos)
end

--- Returns a point in canvas space converted to sprite space
--- Sprite space is defined by it's current position relative to the canvas
--- @protected
--- @param point Point
--- @return Point
function Preview:CanvasToSpriteCoord(point)
  return subPoints(point, self.spritePos)
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
    text="but",
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
        -- rectangle available to draw to (canvas excluding border)
        local body = Rectangle(3, 3, gc.width - 2*3, gc.height - 2*3)

        gc.color = app.theme.color.editor_face
        gc:fillRect(0,0,gc.width,gc.height)
        
        -- get section of image that fits in canvas according to its position
        local imagePoint0 = clampPoint(self:CanvasToSpriteCoord(Point(body.x,body.y)), self.sprite.bounds)
        local imagePoint1 = clampPoint(self:CanvasToSpriteCoord(Point(body.width-1, body.height-1)), self.sprite.bounds)

        local rendered = Image(self.sprite,
          Rectangle(
            imagePoint0.x, imagePoint0.y,
            imagePoint1.x-imagePoint0.x + 1,
            imagePoint1.y-imagePoint0.y + 1
          )
        )

        if rendered == nil then return end
        -- draw section of image to canvas
        gc:drawImage(rendered, math.max(0, self.spritePos.x), math.max(0, self.spritePos.y))
        
        local spriteCoord = self:spriteToCanvasCoord(Point(0,0))
        local spriteEndCoord = self:spriteToCanvasCoord(Point(self.sprite.width-1, self.sprite.height-1))

        -- draw border around image
        gc.color = app.theme.color.editor_sprite_border
        gc:strokeRect(spriteCoord.x-1, spriteCoord.y-1,
          spriteEndCoord.x-spriteCoord.x+3,
          spriteEndCoord.y-spriteCoord.y+3
        )

        -- draw line below border
        gc.color = app.theme.color.editor_sprite_bottom_border
        gc:beginPath()
        gc:moveTo(spriteCoord.x-1, spriteEndCoord.y+2)
        gc:lineTo(spriteEndCoord.x+1, spriteEndCoord.y+2)

        -- draw border around the preview
        gc:drawThemeRect('editor_selected', Rectangle(0,0,gc.width,gc.height))
      end
    end
  }
  self.dialog = dialog
end

--- @return Preview
function Preview:new()
  local o = {}   -- create object if user does not provide one
  setmetatable(o, self)
  self.__index = self

  o.spritePos = Point(10,10)
  o.sprite = app.sprite
  o.visible = false
  o.open = false
  o:createDialog()
  o.spriteListener = o.sprite.events:on('change', function(ev) 
    o.dialog:repaint() 
    end)
  return o
end

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
  self.sprite.events:off(self.spriteListener)
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