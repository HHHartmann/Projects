local config = {
    seedList = {'192.168.178.47'},
    roundInterval = 3000,
    comPort = 5000,
    debug = true,
    debugOutput = function(message) print('Gossip says: ', message); end
}

gossip = require ("gossip")
gossip.setConfig(config)
gossip.start()



gossip.updateCallback = function(data)
  print("updated", sjson.encode(data))
  collectgarbage()
end

local counter = 0

tmr.create():alarm(5000, tmr.ALARM_AUTO, function()
    print("gossipping")
    counter = counter + 1
    local data = { counter=counter, chipid=node.chipid()}
    gossip.pushGossip(data)
end)
