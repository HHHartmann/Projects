LEDRTCSlot = 10  -- uses 5 memory slots

local function main(framework)

  local UDP

  local IP

  local function UDPsend(msg)
    if IP then
      UDP.send(1234, IP, msg)
    end
  end

  local function calculateEffects()
    local filesList = file.list(".+%.[bB][mM][pP]")
    Effects = {"static","blink","gradient","gradient_rgb","random_color","rainbow","rainbow_cycle","flicker","fire","fire_soft","fire_intense","halloween","circus_combustus","larson_scanner","cycle","color_wipe","random_dot"}
    for k,v in pairs(filesList) do
      Effects[#Effects + 1] = k
    end
  end
  
  local function sendFound(cmd, arg)
    IP = arg
    UDPsend("found")
    UDPsend(table.concat(Effects,","))
  end
  
  local function handleButton(cmd, arg) 
    if arg == "A" then node.restart() end
    if arg == "B" then 
      local ok,res = pcall(function() dofile("luatest.lua") end)
      if not ok then
        print(type(res))
        print("error:", res)
      end
    end
    if arg == "C" then end
  end

  local function saveSetting(cmd, arg)
    local s = {speed = speed, delay = delay, brightness = brightness, color = color, effect = effect}
    local json = sjson.create
  end
  
  local function loadSetting(cmd, arg)
  end
  
  local function deleteSetting(cmd, arg)
  end
  
  local function listSettings(cmd, arg)
  end

  calculateEffects()

  LED_strip = require("LED-strip")

  UDP = dofile("UDP.lua")

  UDP.init(1234, framework)

  UDP.register("discover", sendFound)

  local function cb(f)
    return function(cmd,val) f(val) end
  end

  UDP.register("effect", cb(LED_strip.setEffect))
  UDP.register("color", cb(LED_strip.setColor))
  UDP.register("speed", cb(LED_strip.setSpeed))
  UDP.register("delay", cb(LED_strip.setDelay))
  UDP.register("brightness", cb(LED_strip.setBrightness))
  -- presets
  UDP.register("save", saveSetting)
  UDP.register("load", loadSetting)
  UDP.register("delete", deleteSetting)
  UDP.register("list", listSettings)

  UDP.register("button", handleButton)
end

-- set leds as soon as possible
node.startup({command="if (rtcmem.read32(10) ~= 0815) then ws2812.init(ws2812.MODE_SINGLE) ws2812.write(string.rep(string.char(0, 0, 0, 255),76)) end dofile('init.lua')"})

local framework = dofile("SynchronousFramework.lua")
framework.start(main, framework)
--node.startup({command="ws2812.init(ws2812.MODE_SINGLE) ws2812.write(string.rep(string.char(255, 255, 255, 255),10)..string.rep(string.char(255, 255, 255, 0),10)..string.rep(string.char(0, 0, 0, 255),26)) dofile('init.lua')"})
