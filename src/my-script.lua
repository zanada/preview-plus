local previews = {}
local previewCount = 0

--- @param sprite Sprite
--- @param onclose_ function
--- @return Dialog
local function PreviewDialog(sprite, onclose_)
  local dialog = Dialog{
    title="Preview Plus",
    notitlebar=false,
    onclose=onclose_
  }

  dialog
  :button{ 
    id="center",
    label="",
    text="but",
    selected=false,
    focus=false,
    onclick=function () return end
  }
  :canvas{
    id="myCanvas",
    width=200,
    height=200,
    onpaint=function (ev)
      local gc = ev.context
      if sprite then
        local rendered = Image(sprite)
        gc:drawImage(rendered, 0, 0)
      end
    end
  }
  return dialog
end

---@class Preview
---@field dialog Dialog | nil
---@field sprite Sprite | nil
---@field spriteListener integer | nil
---@field siteListener integer | nil
---@field visible boolean
local Preview = {
  dialog=nil,
  sprite=nil,
  visible=false,
  spriteListener=nil,
  siteListener=nil
}

--- @return Preview
function Preview:new()
  local o = {}   -- create object if user does not provide one
  setmetatable(o, self)
  self.__index = self

  o.sprite = app.sprite
  o.visible = false
  o.dialog = PreviewDialog(o.sprite, function() o.visible = false end)
  o.spriteListener = o.sprite.events:on('change', function(ev) o.dialog:repaint() end)
  o.siteListener = app.events:on('sitechange', function() o:updateVisibility() end)
  return o
end

--- @return nil
function Preview:show()
  self.dialog:show{wait=false}
  self.visible = true
end

--- @return nil
function Preview:updateVisibility()
  if app.sprite == self.sprite and not self.visible then
    self:show()
    return
  end
  if app.sprite ~= self.sprite and self.visible then
    self.dialog:close()
  end
end

--- @return nil
function Preview:disconnect()
  self.sprite.events:off(self.spriteListener)
  app.events:off(self.siteListener)
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


function init(plugin)
  if not app.isUIAvailable then return end

  if plugin.preferences.count == nil then
    plugin.preferences.count = 0
  end
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
  for _, preview in previews do
    preview:disconnect()
  end
  print("Aseprite is closing my plugin, MyFirstCommand was called "
        .. plugin.preferences.count .. " times")
end