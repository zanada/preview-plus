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
	    local dlg = Dialog("my new dialog box 2"):entry{ id="user_value", label="User Value:", text="Default User".. plugin.preferences.count }
	    dlg:show()
    end
  }
end

function exit(plugin)
  print("Aseprite is closing my plugin, MyFirstCommand was called "
        .. plugin.preferences.count .. " times")
end