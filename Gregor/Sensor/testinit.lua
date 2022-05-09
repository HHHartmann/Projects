dofile('_init.lua')    
node.LFS.WifiStarter().start(function() dofile('Gossip_Test.lua')  end)

