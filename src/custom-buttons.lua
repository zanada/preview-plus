----------------------------------------------------------------------
-- Adapted from https://github.com/aseprite/Aseprite-Script-Examples/blob/68ed42647ef9990d6a27c4244277f83d6de8a69b/Custom%20Widgets.lua
---------------------------------------------------------------------
local CustomWidgets = {}

local mouse = { position = Point(0, 0), leftClick = false }
local mouseOverWidget = nil
local pressedWidget = nil

local IconButton = {
  width = 16,
  height = 16,
  bounds = Rectangle(0, 0, 16, 16),
  togglable= false,
  selected = false,
  state = {
    normal = {
      part = "buttonset_item_normal",
      partSelected = "buttonset_item_active",
      color = "button_normal_text",
      colorSel = "button_selected_text"
    },
    hot = {
      part = "toolbutton_hot",
      partSelected = "buttonset_item_pushed",
      color = "button_hot_text",
      colorSel = "button_selected_text"
    },
    selected = {
      part = "toolbutton_pushed",
      color = "button_normal_text",
      colorSel = "button_selected_text"
    },
  },
  icon = nil,
  iconSel = nil,
  iconSelWidth = nil,
  iconSelHeight = nil,
  iconWidth = 16,
  iconHeight = 16,
  recolor=false,
  onclick = function() print("Unassigned") end
}
IconButton.__index = IconButton

function IconButton:new(o)
  o = o or {}
  setmetatable(o, self)
  o.bounds = Rectangle(0,0,o.width,o.height)
  return o
end

function CustomWidgets:buttonRow(options)
  local dlg = options.dlg
  local gap = options.gap or 3
  local widgetParams = options.widgetParams
  -- need margin for some mouse over edge cases
  local margin = options.margin or 1
  assert(dlg)

  local minHeight = 5
  local widgets = {}
  for _, param in ipairs(widgetParams) do
    local widget = IconButton:new(param)
    table.insert(widgets, widget)
    minHeight = math.max(minHeight, widget.bounds.h)
  end
  minHeight = minHeight + margin*2

  dlg:canvas {
    id = "canvas",
    width = 10,
    height = minHeight,
    vexpand= false,
    onpaint = function(ev)
      local ctx = ev.context ---@type GraphicsContext

      -- Draw each custom widget
      local pos = Point(margin,margin)
      for _, widget in ipairs(widgets) do
        local state = widget.state.normal
        widget.bounds = Rectangle(pos.x, pos.y, widget.bounds.w, widget.bounds.h)

        local isMouseOver = mouseOverWidget == widget --widget.bounds:contains(mouse.position)

        if isMouseOver then
          state = widget.state.hot or state
          if mouse.leftClick then
            state = widget.state.selected
            pressedWidget = widget
          end
        end

        ctx:drawThemeRect(widget.selected and state.partSelected or state.part, 
          widget.bounds
        )

        local center = Point(widget.bounds.x + widget.bounds.width / 2,
          widget.bounds.y + widget.bounds.height / 2)

        if widget.icon then
          local size = Rectangle(0,0,
            widget.selected and widget.iconSelWidth or  widget.iconWidth,
            widget.selected and widget.iconSelHeight or widget.iconHeight)
          if widget.recolor then
            local col = app.theme.color[widget.selected and state.colorSel or state.color]
            local img = Image(widget.bounds.w, widget.bounds.h)
            img.context:drawThemeImage(widget.selected and widget.iconSel or widget.icon,
              center.x - widget.bounds.x - size.width / 2,
              center.y - widget.bounds.y - size.height / 2)
            for i = 0,img.width-1 do
              for j = 0,img.height-1 do
                if app.pixelColor.rgbaA(img:getPixel(i,j)) ~= 0 then
                  img:drawPixel(i,j, col.rgbaPixel)
                end
              end
            end
            ctx:drawImage(img, widget.bounds.x, widget.bounds.y)
          else
            ctx:drawThemeImage(widget.selected and widget.iconSel or widget.icon,
              center.x - size.width / 2,
              center.y - size.height / 2)
          end
        elseif widget.text then
          local size = ctx:measureText(widget.text)

          ctx.color = app.theme.color[state.color]
          ctx:fillText(widget.text, center.x - size.width / 2,
            center.y - size.height / 2)
        end
        pos.x = pos.x + widget.bounds.w + gap
      end
    end,
    onmousemove = function(ev)
      -- Update the mouse position
      local isOverWidget = false
      for _,widget in ipairs(widgets) do
        if widget.bounds:contains(Point(ev.x,ev.y)) then
          mouseOverWidget = widget
          isOverWidget = true
          break
        end
      end
      if not isOverWidget then mouseOverWidget = nil end
      mouse.position = Point(ev.x, ev.y)

      dlg:repaint()
    end,
    onmousedown = function(ev)
      -- Update information about left mouse button being pressed
      mouse.leftClick = ev.button == MouseButton.LEFT

      dlg:repaint()
    end,
    onmouseup = function(ev)
      -- When releasing left mouse button over a widget, call `onclick` method
      if mouse.leftClick then
        for _, widget in ipairs(widgets) do
          local isMouseOver = widget.bounds:contains(mouse.position)

          if isMouseOver and widget == pressedWidget then
            if widget.togglable then widget.selected = not widget.selected end
            widget.onclick()

            -- Last clicked widget has focus on it
            mouseOverWidget = nil
          end
        end
      end

      -- Update information about left mouse button being released
      mouse.leftClick = false

      dlg:repaint()
    end,
  }
end

return CustomWidgets
