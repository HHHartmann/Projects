local c1,c2

LINQ = dofile("LINQ.lua")

local localData = {}

local globalData = {sensordata = {}, venting = {}}

if config.type == "SEN" then
  c1 = config.sensors[1]
  c2 = config.sensors[2]
end
local signalPin = config.signalPin
local relaisPin = config.relaisPin

local dewpointThreshold = 5
local minHumidity = 50

local status, err
local s1,s2

local function setupI2c(config)
    print("i2c.setup")
    status, err = pcall(function() i2c.setup(config.id, config.sda, config.scl, i2c.SLOW) end)
    print(status, err)
end

if config.type == "SEN" then
    local bme280 = node.LFS.bme280() -- needed to hide legacy bme280 module
    setupI2c(c1)
    print("bme280.setup")
    status, err = pcall(function() s1 = bme280.setup(c1.id, c1.addr, nil, nil, nil, 0) end) -- initialize to sleep mode
    if c2 ~= nil then
      setupI2c(c2)
      print("bme280.setup")
      status, err = pcall(function() s2 = bme280.setup(c2.id, c2.addr, nil, nil, nil, 0) end) -- initialize to sleep mode
    end
    print("done")
end

local status = "Unbekannt"

gpio.mode(signalPin, gpio.OUTPUT)
if relaisPin then gpio.mode(relaisPin, gpio.OUTPUT) end


local function off()
  gpio.write(signalPin, gpio.HIGH)  -- turn light off
  if relaisPin then gpio.write(relaisPin, gpio.HIGH) end  -- turn off
end

local function on()
  gpio.write(signalPin, gpio.LOW)  -- turn light on
  if relaisPin then gpio.write(relaisPin, gpio.LOW) end  -- turn on
end

local nextData
local sending
local function sendData(data)
  --[[ don't send for now
  if sending then
    nextData = data
    print("Defering sendData")
    return
  end
  sending = true
  local url = "http://industrial.api.ubidots.com/api/v1.6/devices/MyHome/"
  local body = sjson.encode(data)
  http.post(url, "X-Auth-Token: BBFF-g0qMTBSw6uDleQdFNoWJRNRZniWouS\r\nContent-Type: application/json\r\n", body, function(code, data)
    if (code < 0) then
      print("HTTP request failed")
    end
    print(code, data)
    sending = false
    if nextData then
      local localData = nextData
      nextData = nil
      print("Executing defered sendData")
      return sendData(localData)   -- tailcall
    end
  end)
  ]]
end


local function validate(s, T, P, H)
    if s and T and P and H then
      local D = s:dewpoint(H, T)
      print(("T=%.2f°C, pressure=%.3f HPa, humidity=%.3f%%, dewpoint=%.2f°C"):format(T, P, H, D))
      return {T=T, P=P, H=H, D=D}
    else
      print(s, T, P, H)
      return nil
    end
end

local function calculateGlobalState()

  local function isValidData(k,v)
    return v.state < 4 --[[ remove ]] and v.data
  end

  local function isSensor(k,v)
    return v.data.sensordata
  end

  local function isVenting(k,v)
    return v.data.venting
  end

  local function getSensors(k,v)
    if v.data.sensordata then
      -- return {a=v.data.sensordata[1], b=v.data.sensordata[2]}
      return {a=v.data.sensordata[1]}
    else
      return {}
    end
  end

  collectgarbage()
  -- TODO: remove "where v.data.sensordata" after LINQ bug with empty selectMany is fixed
  print("networkState:", sjson.encode(gossip.networkState))
  local sensors = LINQ(gossip.networkState):where(isValidData):where(isSensor):selectMany(getSensors):toListValue()
  collectgarbage()

  print("sensordaten:", sjson.encode(sensors))

  local indoor = LINQ(sensors):where(function(k,v) return v.location == "Indoor" end):toListValue()
  local outdoor = LINQ(sensors):where(function(k,v) return v.location == "Outdoor" end):toListValue()
  sensors = nil
  
  print("indoor:", sjson.encode(indoor))
  print("outdoor:", sjson.encode(outdoor))

  globalData.sensors = {indoor=indoor,outdoor=outdoor }

  local _, venting = LINQ(gossip.networkState):where(isValidData):where(isVenting):select(function(k,v) return k, v.data.venting end):first()
  venting = venting or {statusText = "Keine Daten zur Lüftung verfügbar"}
  print("venting:", sjson.encode(venting))
  collectgarbage()

  globalData.venting = venting
end



local function calculateVentingState()

  local indoor = {}
  local outdoor = {}
  local statusText
  local status

  if globalData.sensors then
    indoor = globalData.sensors.indoor
    outdoor = globalData.sensors.outdoor
  end
  
  if #indoor < 1 or #outdoor < 1 then 
    statusText = "Lüftung aus, keine Sensordaten"
    status = "off"
    off()
  elseif indoor[1].H < minHumidity then
    statusText = "Lüftung aus, Nicht feucht genug zum lüften"
    status = "off"
    off()
  elseif outdoor[1].D + dewpointThreshold < indoor[1].D then
    statusText = "Lüftung läuft"
    status = "on"
    on()
  else
    statusText = "Lüftung aus, Feuchtigkeit außen zu hoch"
    status = "off"
    off()
  end
  collectgarbage()
  
  local function vval(val) if val == "on" then return 1 else return 0 end end
  local data = {}
  data.venting = {{value=vval(status), context={status=statusText}}}
  vval = nil
  sendData(data)

  if (globalData.venting and globalData.venting.status == status and globalData.venting.statusText == statusText) then
    print("venting unchanged. Not pushing.")
    return
  end
  
  localData.venting = {status=status, statusText=statusText}
  print("pushing", sjson.encode(localData))
  gossip.pushGossip(localData)
end

local function sendSensorData(sensordata)
  local data = {}
  data[sensordata.location.."_Temp"] = sensordata.T
  data[sensordata.location.."_Press"] = sensordata.P
  data[sensordata.location.."_Hum"] = sensordata.H
  data[sensordata.location.."_Dewp"] = sensordata.D
  return sendData(data)  -- tailcall
end

if config.type == "SEN" then  -- SEN = sensors

  localData.sensordata = {}

  tmr.create():alarm(10600, tmr.ALARM_AUTO, function()
      collectgarbage()
      if s1 ~= nil then 
        setupI2c(c1)
        s1:startreadout(function(T, P, H)
            print(1,T,P,H)
            if not T or not P or not H then return end
            localData.sensordata[1] = validate(s1, T, P, H)
            localData.sensordata[1].location = c1.location
            sendSensorData(localData.sensordata[1])
            if s2 ~= nil then 
              node.task.post(function()
                  setupI2c(c2)
                  s2:startreadout(function(T, P, H)
                      print(2,T,P,H)
                      localData.sensordata[2] = validate(s2, T, P, H)
                      localData.sensordata[2].location = c2.location
                      sendSensorData(localData.sensordata[2])
                      gossip.pushGossip(localData)
                      calculateGlobalState()
                  end)
                end, node.task.LOW_PRIORITY)
            else
              gossip.pushGossip(localData)
              calculateGlobalState()
            end
        end)
      end
  end)

  gossip.updateCallback = function()
    node.task.post(calculateGlobalState, node.task.LOW_PRIORITY)
    collectgarbage()
  end


--[[
  WebServer.route("/sensor", function(req, res)
      collectgarbage()
      res:send(nil, 200)
      res:send_header("Connection", "close")
      res:send_header("Content-Type", "text/plain")
      res:send_header("Access-Control-Allow-Origin", "*")
      res:send(function(res)
          collectgarbage()
          local sensordata = localData.sensordata[1]
          res:send(("T=%.2f°C, pressure=%.3f HPa, humidity=%.3f%%, dewpoint=%.2f°C"):format(sensordata.T, sensordata.P, sensordata.H, sensordata.D))
          res:send("\r\n")
          local sensordata = localData.sensordata[2]
          res:send(("T=%.2f°C, pressure=%.3f HPa, humidity=%.3f%%, dewpoint=%.2f°C"):format(sensordata.T, sensordata.P, sensordata.H, sensordata.D))
          res:finish()
          collectgarbage()
      end)
  end)
]]

elseif config.type == "VEN" then  -- VEN = venting

  localData.venting = {}
  calculateVentingState()
  calculateGlobalState()

  gossip.updateCallback = function()
    node.task.post(function() calculateGlobalState() calculateVentingState() calculateGlobalState() end, node.task.LOW_PRIORITY)
    collectgarbage()
  end

end

WebServer.route("/status", function(req, res)
    collectgarbage()
    res:send(nil, 200)
    res:send_header("Connection", "close")
    res:send_header("Content-Type", "application/json")
    res:send_header("Access-Control-Allow-Origin", "*")
  
    local status = {sensors = globalData.sensors, status = globalData.venting.statusText, name = config.name, rssi = wifi.sta.getrssi() }
    status = sjson.encode(status)
    print(status)
    res:send(status)
    status = nil
    res:finish()
    collectgarbage()
end)

file.remove("www_index.htm")
WebServer.staticRoute("www_sensor")

