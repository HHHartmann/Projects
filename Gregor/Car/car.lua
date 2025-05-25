local function main(framework)

  local UDP

  local motors = dofile("hw_motor.lua")
  local left = motors.new({speed=2, direction=1})
  local right = motors.new({speed=4, direction=3})
--  local left = motors.new({pin1=2, pin2=1})
--  local right = motors.new({pin1=4, pin2=3})

  local speed, heading = 0.0, 0.0

  local IP
  
  local function UDPsend(msg)
    if IP then
      UDP.send(1234, IP, msg)
    end
  end
  
  local function sendFound(cmd, arg)
    IP = arg
    UDPsend("found")
  end

  local function setTilt(cmd, arg) 
    print(speed, arg)
    tilt = tonumber(arg)
  end

local function Wenden()
  local i = 0
  while i < 2 do
    left.setSpeed(100)
    right.setSpeed(50)
    framework.wait(1500)
    left.setSpeed(-50)
    right.setSpeed(-100)
    framework.wait(1500)
    i = i + 1
  end
  left.setSpeed(100)
  right.setSpeed(-100)
  framework.wait(1500)
  left.setSpeed(-100)
  right.setSpeed(100)
  framework.wait(1500)
  left.setSpeed(0)
  right.setSpeed(0)
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
  if arg == "C" then Wenden() end
end





  --[[
  left.setSpeed(50)
  right.setSpeed(50)
  framework.wait(1500)
  left.setSpeed(0)
  right.setSpeed(0)
]]
  
  local function setMotors(cmd, arg) 
    left.setSpeed(speed - heading)
    right.setSpeed(speed + heading)
  end


  local function setSpeed(cmd, arg)
    speed = tonumber(arg)
    setMotors()
  end


  local function setHeading(cmd, arg)
    heading = tonumber(arg)
    setMotors()
  end

  setSpeed(nil, "0")
  setHeading(nil, "0")

  UDP = dofile("UDP.lua")

  UDP.init(1234, framework)

  UDP.register("discover", sendFound)
  UDP.register("tilt", setTilt)
  UDP.register("speed", setSpeed)
  UDP.register("heading", setHeading)
  UDP.register("button", handleButton)


  require("sr04")
  local trig, echo = 5, 6  
  sr04.init(trig,echo)
  while 1 do
    if sr04.measure() < 10 then
      left.setSpeed(100)
      right.setSpeed(-100)
      framework.wait(1500)
      left.setSpeed(0)
      right.setSpeed(0)
    end
    framework.wait(1000)
  end


--[[
  local id = 0
  local sda = 7
  local scl = 8
print("before i2c.setup")
  i2c.setup(id, sda, scl, i2c.SLOW)
print("before scanner")
  for i=0,127 do
    i2c.start(id)
    resCode = i2c.address(id, i, i2c.TRANSMITTER)
    i2c.stop(id)
    if resCode == true then print("We have a device on address 0x" .. string.format("%02x", i) .. " (" .. i ..")") end
  end
print("after scanner")
  
  l3g4200d.setup()
  while 1 do
    framework.wait(500)
    local x,y,z = l3g4200d.read()
    print(x,y,z)
    UDPsend(x+" "+y+" "+z)
  end
]]

--[[
  print("1")
  framework.wait(1500)
  print("2")
  framework.wait(1500)
  print("3")
  framework.wait(1500)
  print("4")
  framework.wait(1500)
  print("5")
  framework.wait(1500)
]]
  

end


local framework = dofile("SynchronousFramework.lua")
framework.start(main, framework)
