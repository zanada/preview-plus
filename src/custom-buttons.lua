----------------------------------------------------------------------
-- Adapted from https://github.com/aseprite/Aseprite-Script-Examples/blob/68ed42647ef9990d6a27c4244277f83d6de8a69b/Custom%20Widgets.lua
---------------------------------------------------------------------
local CustomWidgets = {}

local mouse = { position = Point(0, 0), leftClick = false }
local focusedWidget = nil
local mouseOverWidget = nil
local pressedWidget = nil

local IconButton = {
  width = 16,
  height = 16,
  bounds = Rectangle(0, 0, 16, 16),
  state = {
    normal = {
      part = "buttonset_item_normal",
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
      part = "buttonset_item_focused",
      color = "button_normal_text"
    },
    hotFocused = {
      part = "buttonset_item_hot_focused",
      color = "button_hot_text"
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

        if widget == focusedWidget then
          state = widget.state.focused
        end

        local isMouseOver = mouseOverWidget == widget --widget.bounds:contains(mouse.position)

        if isMouseOver then
          if state == widget.state.focused then
            state = widget.state.hotFocused or state
          else
            state = widget.state.hot or state
          end

          if mouse.leftClick then
            state = widget.state.selected
            pressedWidget = widget
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
            widget.onclick()

            -- Last clicked widget has focus on it
            focusedWidget = widget
            mouseOverWidget = nil
          end
        end
      end

      -- Update information about left mouse button being released
      mouse.leftClick = false

      dlg:repaint()
    end,
    onkeydown = function(ev)
      print(ev.key)
      print(ev.spaceKey)
      if ev.spaceKey then
        for _, widget in ipairs(widgets) do
          if widget == focusedWidget then
            widget.onclick()
            break
          end
        end
      end
    end
  }
end

return CustomWidgets
