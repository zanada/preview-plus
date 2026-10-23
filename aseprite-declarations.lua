---@class ThemeColor
---@field editor_face Color
---@field editor_sprite_border Color
---@field editor_sprite_bottom_border Color

---@class GraphicsContext
---@field fillRect fun(graphicsContext: GraphicsContext, x: number, y: number, width: number, height: number) | fun(graphicsContext: GraphicsContext, rectangle: Rectangle)
---@field strokeRect fun(graphicsContext: GraphicsContext, x: number, y: number, width: number, height: number) | fun(graphicsContext: GraphicsContext, rectangle: Rectangle)

---@class Dialog
---@field sizeHint Size

---@class Rectangle
---@field contains fun(rectangle: Rectangle, otherRectangle: Rectangle) | fun(rectangle:Rectangle, point:Point)