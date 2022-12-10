print("starting", config.startup)
if config.startup then
  return dofile(config.startup)  -- tail call
else
  print("no startup configured")
end
