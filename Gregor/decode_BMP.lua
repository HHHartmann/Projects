local function GetBMP(filename)

  local BMP = {}
  BMP.filename = filename
  local readfile, f, buf
  if io then
    f = io.open(filename, "rb")
    local buf = f:read("*all")
    f:close()
    readfile = function(start,len) return buf:sub(start, start+len-1) end
  else
    f = file.open(filename, "r")
    readfile = function(start,len) 
      --print("read", start, len)
      f:seek("set", start) 
      --print("pos", f:seek())
      return f:read(len) end
  end
  
  local Width, Height, offset, lineLength

  BMP.Size = function() return Width, Height end

  BMP.GetLine = function(n)
    return readfile(offset+lineLength*(Height-n),Width*3)
  end

  do
    local header = readfile(0, 46)
    local markerB,markerM,size,_, HeaderSize, Planes, BitCount, Compression
    markerB,markerM,size,_,offset, HeaderSize, Width, Height, Planes, BitCount, Compression = struct.unpack("cc<I4I4I4  I4i4i4I2I2I4", header)

    if markerB ~= "B" or markerM ~= "M" then
      error("No BMP")
    end
    if BitCount ~= 24 or Compression ~= 0 then
      error("only 24 bit uncompressed images suported")
    end
  end  
  
  lineLength = math.floor((Width*3+3)/4)*4   -- lines are stored in a multiple of 4 bytes, remaining bytes are zero
  print("lineLength", lineLength)
  return BMP
end

return GetBMP
