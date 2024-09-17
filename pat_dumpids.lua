local firstMetaMaterialId = 65000
local engineMetaMaterials = {
  [65500] = "metamaterial:objectsolid",
  [65501] = "metamaterial:objectplatform",
  [65526] = "metamaterial:boundary",
  [65527] = "metamaterial:biome",
  [65528] = "metamaterial:biome1",
  [65529] = "metamaterial:biome2",
  [65530] = "metamaterial:biome3",
  [65531] = "metamaterial:biome4",
  [65532] = "metamaterial:biome5",
  [65533] = "metamaterial:structure",
  [65534] = "metamaterial:null",
  [65535] = "metamaterial:empty",
}

local fmt = string.format
local len = string.len

local function dump(extension, idKey, nameKey)
  local ids = {}
  local files = root.assetsByExtension(extension)

  for _, file in ipairs(files) do
    local data = root.assetJson(file)
    local name = data[nameKey]
    local origin = root.assetOrigin(file)
    ids[#ids + 1] = {data[idKey], name, file, origin}
  end
  
  -- metamaterials
  local doMetaMaterials = extension == "material"
  if doMetaMaterials then
    local metaMaterials = root.assetJson("/metamaterials.config")
    for i, metaMaterial in pairs(metaMaterials) do
      ids[#ids + 1] = {metaMaterial.materialId, "metamaterial:" .. metaMaterial.name, "/metamaterials.config:" .. i, "" }
    end
    for id, name in pairs(engineMetaMaterials) do
      ids[#ids + 1] = {id, name, "", "internal"}
    end
  end
  
  -- get column lengths
  local maxNameLen, maxFileLen, maxOrigLen = 0, 0, 0
  for _, h in ipairs(ids) do
    local nameLen, fileLen, origLen = len(h[2]), len(h[3]), len(h[4])
    if nameLen > maxNameLen then maxNameLen = nameLen end
    if fileLen > maxFileLen then maxFileLen = fileLen end
    if origLen > maxOrigLen then maxOrigLen = origLen end
  end
  local nameFmt = "%-" .. maxNameLen .. "s"
  local fileFmt = "%-" .. maxFileLen .. "s"
  local origFmt = "%-" .. maxOrigLen .. "s"

  table.sort(ids, function(a, b) return a[1] < b[1] end)

  -- dump ids
  local line = string.rep("=", (maxNameLen + maxFileLen + maxOrigLen) // 2 - 2)
  local output = fmt("\n%s DUMPING .%s IDS %s\n", line, extension:upper(), line)

  local metaLine = doMetaMaterials

  for _, h in ipairs(ids) do
    if metaLine and h[1] >= firstMetaMaterialId then
      output = output .. fmt("%s     METAMATERIALS     %s\n", line, line)
      metaLine = false
    end
    
    local name = fmt(nameFmt, h[2])
    local file = fmt(fileFmt, h[3])
    local orig = fmt(origFmt, h[4])
    output = output .. fmt(" %6d | %s | %s | %s |\n", h[1], name, file, orig)
  end

  -- dump metamaterials.config patches
  if doMetaMaterials then
    local patches
    if root.assetPatches then
      patches = root.assetPatches("/metamaterials.config") -- OSB
    else
      local _; _, patches = root.assetOrigin("/metamaterials.config", true) -- SE
    end

    if patches and #patches > 0 then
      local sources = {}
      for _, patch in ipairs(patches) do
        sources[#sources + 1] = patch[1]
      end
      output = output .. fmt("Sources patching /metamaterials.config: '%s'\n", table.concat(sources, "', '"))
    end
  end

  output = output .. fmt("%s   END .%s IDS   %s\n", line, extension:upper(), line)
  sb.logInfo(output)

  return fmt("^#FFC6E9;dumped %s %s ids to storage/starbound.log^reset;", #ids, extension)
end

local function dumpMaterials()
  return dump("material", "materialId", "materialName")
end

local function dumpLiquids()
  return dump("liquid", "liquidId", "name")
end

local function dumpMatmods()
  return dump("matmod", "modId", "modName")
end

local function dumpAll()
  return string.format("%s\n%s\n%s", dumpMaterials(), dumpLiquids(), dumpMatmods())
end

local function localHandler(func)
  return function(_, isLocal, ...)
    if isLocal then return func(...) end
  end
end

function init()
  if not root.assetsByExtension or not root.assetOrigin then return end

  message.setHandler("/dumpmaterials", localHandler(dumpMaterials))
  message.setHandler("/dumpliquids", localHandler(dumpLiquids))
  message.setHandler("/dumpmatmods", localHandler(dumpMatmods))
  message.setHandler("/dumpids", localHandler(dumpAll))
end
