


local function getScriptPath()
    local str = debug.getinfo(2, "S").source:sub(2)
    return str:match("(.*/)")
end





local gmem = {}

local mapping = {
[1]=1, 
[2]=2,
[3]=3,
[4]=4, 
[5]=5,
[6]=6,
[7]=7, 
[8]=8,
[9]=9
}


local handle = io.popen("cd \""..getScriptPath().."\" && python3 main.py", "w")


function setup()
  reaper.gmem_attach("marini_light_show")
  if reaper.gmem_read(0) == 0 then return false end
  if not handle then reaper.ShowMessageBox("Problem with the python usb serial script, cannot proceede", "Error", 0) return false end
  
  for i=1, 128 do
    gmem[i] = reaper.gmem_read(i)
  end
   
  return true
  
end

function main()
  for i=1, 128 do
    if gmem[i] ~= reaper.gmem_read(i) then 
      --run script
      if mapping[i] then
        gmem[i] = reaper.gmem_read(i)
        handle:write("{"..mapping[i]..","..math.tointeger(gmem[i]).."}".."\n")
        --reaper.ShowConsoleMsg(gmem[i])
        handle:flush()
      end
    end
  end
  reaper.defer(main)
end


local found_gmem = setup()

if not found_gmem then
  reaper.ShowMessageBox("You must put Marini_lightshow jsfx in at least one track", "Error", 0)
else
  main()
end


function cleanup()
    handle:write("-1\n")
    handle:flush()
end

reaper.atexit(cleanup)
