----------------------------------------------------------------------
-- Adapted from https://github.com/aseprite/Aseprite-Script-Examples/blob/68ed42647ef9990d6a27c4244277f83d6de8a69b/Custom%20Widgets.lua
---------------------------------------------------------------------
local CustomWidgets = {}

local mouse = { position = Point(0, 0), leftClick = false }
local focusedWidget = nil

local IconButton = {
  width = 16,
  height = 16,
  bounds = Rectangle(0, 0, 16, 16),
  state = {
    normal = {
      part = "toolbutton_normal",
      color = "button_normal_text"
    },
    hot = {
      part = "toolbutton_hot",
      color = "button_hot_text"
    },
    selected = {
      part = "toolbutton_pushed",
      color = "button_selected_text"
    },
    focused = {
      part = "toolbutton_last",
      color = "button_normal_text"
    }
  },
  icon = "tool_zoom",
  iconWidth = 16,
  iconHeight = 16,
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
  assert(dlg)

  local minHeight = 5
  local widgets = {}
  for _, param in ipairs(widgetParams) do
    local widget = IconButton:new(param)
    table.insert(widgets, widget)
    minHeight = math.max(minHeight, widget.bounds.h)
  end

  dlg:canvas {
    id = "canvas",
    width = 10,
    height = minHeight,
    vexpand= false,
    onpaint = function(ev)
      local ctx = ev.context ---@type GraphicsContext

      -- Draw each custom widget
      local pos = Point(0,0)
      for _, widget in ipairs(widgets) do
        local state = widget.state.normal
        widget.bounds = Rectangle(pos.x, pos.y, widget.bounds.w, widget.bounds.h)

        if widget == focusedWidget then
          state = widget.state.focused
        end

        local isMouseOver = widget.bounds:contains(mouse.position)

        if isMouseOver then
          state = widget.state.hot or state

          if mouse.leftClick then
            state = widget.state.selected
          end
        end

        ctx:drawThemeRect(state.part, widget.bounds)

        local center = Point(widget.bounds.x + widget.bounds.width / 2,
          widget.bounds.y + widget.bounds.height / 2)

        if widget.icon then
          -- Assuming default icon size of 16x16 pixels
          local size = Rectangle(0,0,widget.iconWidth,widget.iconHeight)

          ctx:drawThemeImage(widget.icon, center.x - size.width / 2,
            center.y - size.height / 2)
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

          if isMouseOver then
            widget.onclick()

            -- Last clicked widget has focus on it
            focusedWidget = widget
          end
        end
      end

      -- Update information about left mouse button being released
      mouse.leftClick = false

      dlg:repaint()
    end
  }
end

return CustomWidgets
