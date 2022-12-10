


local NextChar
local result

local types = {str = 0x0, bool = 0x4, int = 5, uint = 6, list = 7}

-- forwards
local ReadElement


local function Consume(value)
  local read = NextChar()
  if read ~= value then error(string.format("expected %02x found %02x", value, read)) end
end

local function ReadTL()
  local TL = NextChar()
  if TL & 0x80 == 0x80 then
    error("Extended length not implmented")
  else
    return TL >> 4, (TL & 0x0f) -1
  end
end

local function EnsureT(requiredT, givenT)
  if requiredT ~= givenT then
    error("expected different type")
  end
end

local function ReadStrL(L)
  --print("ReadStrL", L)
  local res = ""
  while #res < L do
    res = res .. string.char(NextChar())
  end
  return res
end

local function ReadStr()
  local T,L = ReadTL()
  EnsureT(types.str, T)

  return ReadStrL(L)
end

local function ReadUIntL(L)
  --print("ReadUintL", L)
  local res = 0
  while L > 0 do
    res = res * 256 + NextChar()
    L = L -1
  end
  return res
end

local function ReadUInt()
  local T,L = ReadTL()
  EnsureT(types.uint, T)
  
  return ReadUIntL(L)
end

local function ReadIntL(L)
  --print("ReadintL", L)
  local res = 0
  while L > 0 do
    res = res * 256 + NextChar()
    L = L -1
  end
  return res
end

local function ReadInt()
  local T,L = ReadTL()
  EnsureT(types.int, T)
  
  return ReadIntL(L)
end

local function ReadListL(L)
  L = L + 1
  --print("ReadListL", L)
  local res = {}
  while #res < L do
    table.insert(res, ReadElement())
  end
  return res
end

local function ReadList()
  local T,L = ReadTL()
  EnsureT(types.list, T)
  
  return ReadListL(L)
end

local function ReadEndOfSmlMsg()
  Consume(0x00)
  return 0x00
end

ReadElement = function()
  local T,L = ReadTL()
  if T == types.str then return ReadStrL(L)
  elseif T == types.bool then return ReadBoolL(L)
  elseif T == types.int then return ReadIntL(L)
  elseif T == types.uint then return ReadUIntL(L)
  elseif T == types.list then return ReadListL(L)
  else
    error("unknown type")
  end
end

--[[
SML_Message ::= SEQUENCE
{
  transactionId Octet String,
  groupNo Unsigned8,
  abortOnError Unsigned8,
  messageBody SML_MessageBody,
  crc16 Unsigned16,
  endOfSmlMsg EndOfSmlMsg
}
]]
local function ReadMessage()
  local message = {}
  Consume(0x76)  -- list of 6 elements
  message.TId = ReadStr()  
  message.GroupNo = ReadUInt()
  message.AbortErr = ReadUInt()
  message.Body = ReadList()
  message.CRC = ReadUInt()
  message.endMark = ReadEndOfSmlMsg()
  
  return message
end

local function Prolog()
  Consume(0x1b)
  Consume(0x1b)
  Consume(0x1b)
  Consume(0x1b)
  Consume(0x01)
  Consume(0x01)
  Consume(0x01)
  Consume(0x01)

  local open = ReadMessage()
  --print(sjson.encode(open))
  if open.Body[1] ~= 0x0101 then  -- OpenResponse
    error("Expected OpenResponse Message Body")
  end
end

--[[
SML_GetList.Res ::= SEQUENCE
{
  clientId Octet String OPTIONAL,
  serverId Octet String,
  listName Octet String OPTIONAL,
  actSensorTime SML_Time OPTIONAL,
  valList SML_List,
  listSignature SML_Signature OPTIONAL,
  actGatewayTime SML_Time OPTIONAL
}
]]
local function Data()
  local data = ReadMessage()
  --print(sjson.encode(data))
  while data.Body[1] == 0x0701 do  -- GetListResponse
    local response = data.Body[2]
    print("found", response[1], response[2], response[3], "#values" , #response[5])
    --for i, r in ipairs(response[5]) do
    --  print(r[1], r[6])
    --end
    result = data
    
    data = ReadMessage()
    print(sjson.encode(data))
  end
end

local function Epilog()
end



local function Parse(nextCharFunc)

  result = {}

  NextChar = nextCharFunc
  
  Prolog()
  Data()
  Epilog()
  
  return result

end







return Parse


--[[


local buffer = "1b 1b 1b 1b 01 01 01 01 76 05 01 82 cb 66 62 00 62 00 72 63 01 01 76 01 07 ff ff ff ff ff ff 05 00 80 ee 78 0b 0a 01 45 4d 48 00 00 b5 69 8f 72 62 01 65 00 40 7c 48 62 01 63 16 4c 00 76 05 01 82 cb 67 62 00 62 00 72 63 07 01 77 07 ff ff ff ff ff ff 0b 0a 01 45 4d 48 00 00 b5 69 8f 07 01 00 62 0a ff ff 72 62 01 65 00 40 7c 48 74 77 07 01 00 60 32 01 01 01 01 01 01 04 45 4d 48 01 77 07 01 00 60 01 00 ff 01 01 01 01 0b 0a 01 45 4d 48 00 00 b5 69 8f 01 77 07 01 00 01 08 00 ff 64 1c 01 04 72 62 01 65 00 40 7c 48 62 1e 52 ff 69 00 00 00 00 00 45 6a 73 01 77 07 01 00 10 07 00 ff 01 72 62 01 65 00 40 7c 48 62 1b 52 00 55 00 00 00 b6 01 01 01 63 39 9c 00 76 05 01 82 cb 68 62 00 62 00 72 63 02 01 71 01 63 8e 4c 00 00 00 1b 1b 1b 1b 1a 02 96 50"
local pos = 1

local function nextC()

  local n = buffer:sub(pos,pos+2)
  pos = pos + 3
print(n)
  return tonumber(n,16)
end


res = Parse(nextC)

  print(sjson.encode(res))
  print(sjson.encode(res.Body[2]))
  print(sjson.encode(res.Body[2][5]))
  print(sjson.encode(res.Body[2][5][3]))


print(res.Body[2][5][3][6]/10, "KWh")
print(res.Body[2][5][4][6], "W")

]]