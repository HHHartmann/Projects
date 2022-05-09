  local getBMP = dofile("decode_BMP.lua")

      bmp = getBMP("Wasser1.bmp")
      print(bmp.Size())
    lineBuf = pixbuf.newBuffer(bmp.Size(),3)
      
      
      
    local buf = bmp.GetLine(1)
    lineBuf:replace(buf)
    print(lineBuf)
    local buf = bmp.GetLine(2)
    lineBuf:replace(buf)
    print(lineBuf)
    local buf = bmp.GetLine(3)
    lineBuf:replace(buf)
    print(lineBuf)


