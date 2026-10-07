
local function getActiveSprite()
  local sprite = app.sprite
  if not sprite then
    return app.alert("No active sprite found.")
  end
  return sprite
end

function init(plugin)
  print("Aseprite is initializing my plugin")

  -- we can use "plugin.preferences" as a table with fields for
  -- our plugin (these fields are saved between sessions)
  if plugin.preferences.count == nil then
    plugin.preferences.count = 0
  end

  --
  plugin:newCommand{
    id="MyFirstCommand",
    title="My First Command",
    group="cel_popup_properties",
    onclick=function()
      plugin.preferences.count = plugin.preferences.count+1
	    local dlg = Dialog("my new dialog box 2")
        :label{ id="open_count", label="Open Count:", text=tostring(plugin.preferences.count) }
        :canvas{
          id="myCanvas",
          width=200,
          height=200,
          onpaint=function (ev)
            local gc = ev.context
            if app.sprite then
              gc:drawImage(app.image, 0, 0) 
            end
          end
        }
	    dlg:show()
    end
  }
end

function exit(plugin)
  print("Aseprite is closing my plugin, MyFirstCommand was called "
        .. plugin.preferences.count .. " times")
end