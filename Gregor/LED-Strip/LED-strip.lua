  local speed = 50
  local delay = 10
  local brightness = 255
  local effect = "static"
  local replay
  local strip_buffer
  
  local getBMP = dofile("decode_BMP.lua")
  local bmp, lineNr, timer, lineBuf = nil, 1, tmr.create()

 local function saveSetting(arg)
    local s = {speed = speed, delay = delay, brightness = brightness, color = color, effect = effect}
    local json = sjson.create
  end
  
  local function loadSetting(arg)
  end

  local function setLED()
    print(speed, delay, brightness)
    ws2812_effects.set_speed(speed)
    ws2812_effects.set_delay(delay)
    ws2812_effects.set_brightness(brightness)
    --ws2812_effects.set_mode(effect)
    if (timer:state()) then
      timer:interval(delay+2)
      timer:stop()
      timer:start()
    end
  end

  local function setSpeed(arg)
    speed = math.floor(tonumber(arg))
    speed = math.max(speed,0)
    speed = math.min(speed,255)
    setLED()
  end

  local function setDelay(arg)
    delay = math.floor(tonumber(arg))
    delay = math.max(delay,0)
    setLED()
  end

  local function mapChannels(r,g,b)
    if config.channels == 4 then
      local w = math.min(math.min(r,g),b)
      local w2 = r < b and r or b
      local w3 = w2 < g and w2 or g
      print("raw2",g,r,b,w == w3,w,w3,w2)
      if xxx == 1 then
        xxx = 0
        print("color",g,r,b,0)
        return g,r,b,0
      else
        --xxx = 1
        print("white",g-w,r-w,b-w,w)
        w = w3
        return g-w,r-w,b-w,w
      end
    else
      return g,r,b
    end
  end

  local function stopBMPPlayer()
    timer:stop()
    timer:unregister()
    lineBuf = nil
  end

  local function BMPPlay()
    local buf = bmp.GetLine(lineNr)
    lineBuf:replace(buf)
    lineBuf:map(function(b,g,r,w) return r,g,b,w end)
--    print(#buf, "%q"%buf)
    lineBuf:map(mapChannels, nil, nil, nil, buf)
    buf=nil
    collectgarbage()
--    print(lineBuf)
    ws2812.write(lineBuf)
    lineNr = lineNr+1
    local w,h = bmp.Size()
    if lineNr > h then 
      print(replay)
      if not replay or replay > 1 then
        lineNr = 1
        if replay then
          replay = replay - 1
        end
      else
        stopBMPPlayer()
      end
    end
  end
  
  local function startBMPPlayer(_replay)
    replay = _replay
    lineNr = 1
    lineBuf = pixbuf.newBuffer(bmp.Size(),config.channels)
    BMPPlay()
    timer:register(delay+2, tmr.ALARM_AUTO, BMPPlay) 
    timer:start()
  end

  local function setBrightness(arg)
    brightness = math.floor(tonumber(arg))
    brightness = math.max(brightness,0)
    brightness = math.min(brightness,255)
    setLED()
  end

  local function setEffect(arg, replay)
    effect = arg
    if file.exists(effect) then
      ws2812_effects.stop()
      bmp = getBMP(effect)
      print(bmp.Size())
      startBMPPlayer(replay)
    else
      stopBMPPlayer()
      ws2812_effects.start()
      ws2812_effects.set_mode(effect)
    end
  end

  local function setColor(arg)
    local t={}
    local str
    for str in string.gmatch(arg, "([^;]+)") do
      table.insert(t, str)
    end

    local r,g,b = unpack(t)
    print(r,g,b)
    strip_buffer:fill(mapChannels(r,g,b))
    ws2812.write(strip_buffer)
    ws2812_effects.set_color(mapChannels(r,g,b))
  end 

  ws2812.init(ws2812.MODE_SINGLE)
  strip_buffer = pixbuf.newBuffer(config.leds, config.channels)
  ws2812_effects.init(strip_buffer)
  ws2812_effects.set_color(mapChannels(255,255,255))
  setLED()
  setEffect("static")
  --setEffect("start.bmp", 1)

return { setEffect=setEffect, setColor=setColor, setSpeed=setSpeed, setDelay=setDelay, setBrightness=setBrightness}
