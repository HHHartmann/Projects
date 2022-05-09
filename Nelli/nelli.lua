local framework
local UDP

local motors = dofile("hw_motor.lua")
--  local left = motors.new({speed=2, direction=1})
--  local right = motors.new({speed=4, direction=3})
local left = motors.new({pin1=2, pin2=1})
local right = motors.new({pin1=4, pin2=3})

local speed, heading = 0.0, 0.0


local function sendFound(cmd, arg) 
    UDP.send(1234,arg,"found")
end

local function setTilt(cmd, arg) 
  print(speed, arg)
  tilt = tonumber(arg)
end

local function Wenden()
  left.setSpeed(80)
  right.setSpeed(0)
  framework.wait(1500)
  left.setSpeed(0)
  right.setSpeed(-80)
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

  
local function main(framework)
  setSpeed(nil, "0")
  setHeading(nil, "0")


  UDP = dofile("UDP.lua")

  UDP.init(1234, framework)

  UDP.register("discover", sendFound)
  UDP.register("tilt", setTilt)
  UDP.register("speed", setSpeed)
  UDP.register("heading", setHeading)
  UDP.register("button", handleButton)  

Wenden()

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

framework = dofile("SynchronousFramework.lua")
framework.start(main, framework)
