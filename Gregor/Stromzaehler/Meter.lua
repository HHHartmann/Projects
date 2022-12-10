LINQ = dofile("LINQ.lua")

local localData = {}

local globalData = {meter = {}}

local signalPin = config.signalPin

local status, err

local status = "Unbekannt"

gpio.mode(signalPin, gpio.OUTPUT)

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


localData.meter = {}


local parse = dofile('SMLParser.lua')
local msgEnd = tmr.create()


local buffer = ""
local pos = 1

local function NextChar()
  if pos > #buffer then error("No more Input (EOF)") end
  local n = buffer:byte(pos)
  pos = pos + 1
  return n
end

local function ProcessFile()
  print("Parsing chars:", #buffer)
  collectgarbage()
  local success, result = pcall(function() return parse(NextChar) end)
  buffer = ""
  pos = 1
  
  msgEnd:unregister()
  msgEnd = tmr.create()
  msgEnd:register(5, tmr.ALARM_SEMI, ProcessFile)

  if success then
    status = "ok"

    -- TODO get values by OBIS-Kennzahlen and scale by scale
    local KWh, W = result.Body[2][5][3][6]/10, result.Body[2][5][4][6]

    print(KWh, "KWh")
    print(W, "W")

    localData.meter = { {KWh = KWh, W = W} }
  else
    status = result
    print("error parsing:", result)

    localData.meter = {}
  end    
    
  result = nil
  collectgarbage()


  --gossip.pushGossip(localData)


end

msgEnd:register(5, tmr.ALARM_SEMI, ProcessFile)


local function CollectData(data)
  buffer = buffer .. data
  msgEnd:start(true)
  collectgarbage()
--  for i = 1, #data do
--    local c = data:byte(i)
--      print(string.format("%02x", c) )
--  end
end


local debug = false


if not debug then
  print("Setting UART to 9600 N 8 1")
  uart.setup(0, 9600, 8, uart.PARITY_NONE, uart.STOPBITS_1, 0)
uart.on("data", 0, CollectData, 0)

else

  -- valid
  local bu1 = "1b 1b 1b 1b 01 01 01 01 76 05 01 82 cb 66 62 00 62 00 72 63 01 01 76 01 07 ff ff ff ff ff ff 05 00 80 ee 78 0b 0a 01 45 4d 48 00 00 b5 69 8f 72 62 01 65 00 40 7c 48 62 01 63 16 4c 00 76 05 01 82 cb 67 62 00 62 00 72 63 07 01 77 07 ff ff ff ff ff ff 0b 0a 01 45 4d 48 00 00 b5 69 8f 07 01 00 62 0a ff ff 72 62 01 65 00 40 7c 48 74 77 07 01 00 60 32 01 01 01 01 01 01 04 45 4d 48 01 77 07 01 00 60 01 00 ff 01 01 01 01 0b 0a 01 45 4d 48 00 00 b5 69 8f 01 77 07 01 00 01 08 00 ff 64 1c 01 04 72 62 01 65 00 40 7c 48 62 1e 52 ff 69 00 00 00 00 00 45 6a 73 01 77 07 01 00 10 07 00 ff 01 72 62 01 65 00 40 7c 48 62 1b 52 00 55 00 00 00 b6 01 01 01 63 39 9c 00 76 05 01 82 cb 68 62 00 62 00 72 63 02 01 71 01 63 8e 4c 00 00 00 1b 1b 1b 1b 1a 02 96 50"

  -- invalid
  local bu2 = "1b 1b 1b 1b 01 01 01 01 76 05 01 82 cb 66 62 00 62  cb 67 62 00 62 00 72 63 07 01 77 07 ff ff ff ff ff ff 0b 0a 01 45 4d 48 00 00 b5 69 8f 07 01 00 62 0a ff ff 72 62 01 65 00 40 7c 48 74 77 07 01 00 60 32 01 01 01 01 01 01 04 45 4d 48 01 77 07 01 00 60 01 00 ff 01 01 01 01 0b 0a 01 45 4d 48 00 00 b5 69 8f 01 77 07 01 00 01 08 00 ff 64 1c 01 04 72 62 01 65 00 40 7c 48 62 1e 52 ff 69 00 00 00 00 00 45 6a 73 01 77 07 01 00 10 07 00 ff 01 72 62 01 65 00 40 7c 48 62 1b 52 00 55 00 00 00 b6 01 01 01 63 39 9c 00 76 05 01 82 cb 68 62 00 62 00 72 63 02 01 71 01 63 8e 4c 00 00 00 1b 1b 1b 1b 1a 02 96 50"
  
  local function Input(bu)
    local p = 1

    while p < #bu do
      local n = bu:sub(p,p+2)
      p = p + 3
      buffer = buffer .. string.char(tonumber(n,16))
    end
    CollectData("")
  end

  
  tmr.create():alarm( 100,tmr.ALARM_SINGLE,function() Input(bu1) end)
  tmr.create():alarm( 300,tmr.ALARM_SINGLE,function() Input(bu1) end)
  tmr.create():alarm( 900,tmr.ALARM_SINGLE,function() Input(bu1) end)
  
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


WebServer.route("/status", function(req, res)
    collectgarbage()
    res:send(nil, 200)
    res:send_header("Connection", "close")
    res:send_header("Content-Type", "application/json")
    res:send_header("Access-Control-Allow-Origin", "*")
  
    local status = {meter = localData.meter, status = status, name = config.name, rssi = wifi.sta.getrssi() }
    status = sjson.encode(status)
    print(status)
    res:send(status)
    status = nil
    res:finish()
    collectgarbage()
end)

WebServer.staticRoute("www_meter")

