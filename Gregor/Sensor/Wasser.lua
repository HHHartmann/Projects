LINQ = dofile("LINQ.lua")

local sensor

local localData = {}

local globalData = {wasser = {}, alarm = {}}

if config.type == "SEN" then
  if adc.force_init_mode(adc.INIT_ADC) then
    print("reconfigured adc. Need to restart.")
    node.restart()
  end

  sensor = config.sensors[1]
  gpio.mode(sensor.pinLow, gpio.OPENDRAIN)
  gpio.mode(sensor.pinHigh, gpio.OPENDRAIN)
end

local signalPin = config.signalPin

local status, err

local status = "Unbekannt"

gpio.mode(signalPin, gpio.OUTPUT)
gpio.write(signalPin, gpio.HIGH)  -- turn light off

local lastStatus
local function alarm(status)

  print("statuspin value",gpio.read(4))
  if (lastStatus == status) then return end
  
  print("-------------setting status to", status)
  lastStatus = status
  if status == 0 then
    pwm.setduty(signalPin, 1023)
    pwm.close(signalPin)
    gpio.mode(signalPin, gpio.OUTPUT)
    gpio.write(signalPin, gpio.HIGH)  -- turn light off
  elseif status == 1 then
    pwm.setup(signalPin, 1, 700)
    pwm.start(signalPin)
  elseif status == 2 then
    pwm.setup(signalPin, 4, 700)
    pwm.start(signalPin)
  else
    pwm.setduty(signalPin, 0)
    pwm.close(signalPin)
    gpio.mode(signalPin, gpio.OUTPUT)
    gpio.write(signalPin, gpio.LOW)  -- turn light on
  end
  print("statuspin value",gpio.read(4))
end


local function calculateGlobalState()

  local function isValidData(k,v)
    return v.state < 4 --[[ remove ]] and v.data
  end

  local function isWasser(k,v)
    return v.data.wasser
  end

  local function isAlarm(k,v)
    return v.data.alarm
  end

  local function getSensors(k,v)
    if v.data.sensordata then
      -- return {a=v.data.sensordata[1], b=v.data.sensordata[2]}
      return {a=v.data.sensordata[1]}
    else
      return {}
    end
  end

  -- TODO: remove "where v.data.sensordata" after LINQ bug with empty selectMany is fixed
  print("networkState:", sjson.encode(gossip.networkState))
  local _, wasser = LINQ(gossip.networkState):where(isValidData):where(isWasser):select(function(k,v) return k, v.data.wasser end):first();
  collectgarbage()

  print("wasser:", wasser and sjson.encode(wasser) or "nil")
  
  globalData.wasser = wasser

  local _, alarm = LINQ(gossip.networkState):where(isValidData):where(isAlarm):select(function(k,v) return k, v.data.alarm end):first()
  alarm = alarm or {statusText = "Keine Daten zum Alarm verfügbar", status = 0}
  print("alarm:", sjson.encode(alarm))
  collectgarbage()

  globalData.alarm = alarm
end

local function calculatePartialAlarmState(wasser)

  local statusText
  local status
  
  local levelLow, levelHigh

  if globalData.wasser then
    levelLow = {globalData.wasser.levelLow}
    levelHigh = {globalData.wasser.levelHigh}
  else
    levelLow = {}
    levelHigh = {}
  end

  if #levelLow < 1 or #levelHigh < 1 then 
    statusText = "Keine Sensordaten"
    status = 1
  elseif levelHigh[1] > 0 then
    statusText = "Level high aktiviert. ALARM!"
    status = 2
  elseif levelLow[1] > 0 then
    statusText = "Level low aktiviert"
    status = 1
  else
    statusText = "Alles trocken"
    status = 0
  end

  print("returning", statusText, status)
  return statusText, status
end

local function calculateAlarmState()

  local statusText
  local status

  statusText,status = calculatePartialAlarmState(globalData.wasser)
  local t2,s2 = "", 0
  if localData.remote.wasser then
    print("analyse remote data")
    t2,s2 = calculatePartialAlarmState(localData.remote.wasser)
    if status == 0 and s2 > 0 then
      statusText = "Remote "..t2
      status = s2
    elseif status > 0 and s2 > 0 then
      statusText = statusText.." und remote "..t2
      status = math.max(status,s2)
    end
  end
  alarm(status)
  collectgarbage()

  if (globalData.alarm and globalData.alarm.status == status and globalData.alarm.statusText == statusText) then
    print("water unchanged. Not pushing.")
    return
  end
  
  localData.alarm = {status=status, statusText=statusText}
  print("pushing", sjson.encode(localData))
  gossip.pushGossip(localData)
end

if config.type == "SEN" then  -- SEN = sensors

  local function calcLevel(rawValue)
    print(rawValue)
    if rawValue > 400 then
      return 1
    else
      return 0
    end
  end
  
  localData.wasser = {}

  local function readSensors()

    gpio.write(signalPin, gpio.LOW);  -- turn light on
    collectgarbage()
    gpio.mode(sensor.pinLow, gpio.OUTPUT)
    gpio.write(sensor.pinLow, gpio.HIGH);
    localData.wasser.levelLow = calcLevel(adc.read(0))
    gpio.mode(sensor.pinLow, gpio.OPENDRAIN)

    gpio.mode(sensor.pinHigh, gpio.OUTPUT)
    gpio.write(sensor.pinHigh, gpio.HIGH);
    localData.wasser.levelHigh = calcLevel(adc.read(0))
    gpio.mode(sensor.pinHigh, gpio.OPENDRAIN)
    
    gossip.pushGossip(localData)
    gpio.write(signalPin, gpio.HIGH);  -- turn light off
    calculateGlobalState()
  end

  readSensors()
  tmr.create():alarm(4900, tmr.ALARM_AUTO, readSensors)

elseif config.type == "ALRM" then  -- ALRM = Alarm

  localData.alarm = {}
  localData.remote = {}
  calculateAlarmState()
  calculateGlobalState()


  local function readRemoteSensors()
--[[    url = "http://unya840zxudxnekw.myfritz.net:8080/status"
    print(body)
    http.post(url, "", "", function(code, data)
      if (code < 0) then
        print("HTTP request failed")
        localData.remote = {}
      elseif code == 200 then
        localData.remote = sjson.decode(data)
      else
        localData.remote = {}
      end
      print(code, data)
    end)
    collectgarbage() ]]
  end
  
  readRemoteSensors()
  tmr.create():alarm(4900, tmr.ALARM_AUTO, function() readRemoteSensors() calculateAlarmState() calculateGlobalState() end)

  gossip.updateCallback = function()
    node.task.post(function() calculateGlobalState() calculateAlarmState() calculateGlobalState() end, node.task.LOW_PRIORITY)
    collectgarbage()
  end

end

WebServer.route("/status", function(req, res)
    collectgarbage()
    res:send(nil, 200)
    res:send_header("Connection", "close")
    res:send_header("Content-Type", "application/json")
    res:send_header("Access-Control-Allow-Origin", "*")
  
    local status = {wasser = globalData.wasser, status = globalData.alarm.statusText, name = config.name, rssi = wifi.sta.getrssi() }
    status = sjson.encode(status)
    print(status)
    res:send(status)
    status = nil
    res:finish()
    collectgarbage()
end)

WebServer.staticRoute("www_wasser")


