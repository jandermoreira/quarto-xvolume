-- Quarto filter to handle citations in multi-volume books
-- Jander Moreira

local debug = quarto.log.output
local json = require("json")

local function get_volume(meta)
  local volume = meta["book"] and meta["book"]["volume"]
  if not volume then
    return nil
  end
  return tonumber(pandoc.utils.stringify(volume))
end

local function get_target(meta)
  local target = meta["quarto-xvolume"] and meta["quarto-xvolume"]["base-url"]
  return pandoc.utils.stringify(target)
end

local function citation_filter(volume, refs, target)
  return {
    Cite = function(cite)
      local id = cite.citations[1].id
      if not refs[id] or refs[id]["volume"] == volume or not refs[id]["text"] then
        return cite
      end
      return pandoc.Link(
        refs[id]["text"],
        target .. refs[id]["volume"] .. "/" .. refs[id]["file"] .. "#" .. id,
        "Volume " .. refs[id]["volume"],
        {target = "_blank"}
      )
    end
  }
end

local function load_references()
  local path = os.getenv("QUARTO_PROJECT_DIR")
  local parent_dir = path:match("^(.*)/[^/]+$")
  local refs_file = io.open(parent_dir .. "/crossrefs.json", "r")
  if not refs_file then
    debug("No main references file yet....")
    return {}
  end
  local content = refs_file:read("*a")
  refs_file:close()
  local refs, _, err = json.decode(content)
  if not refs then
    debug("Error decoding references file:", err)
    return {}
  end
  return refs
end

local function process_document(doc)
  local volume = get_volume(doc.meta)
  if not volume then
    debug("No volume information found in metadata.")
    return doc
  end

  local target = get_target(doc.meta)
  if not target then
    debug("No quarto-xvolume/base-url found in metadata.")
    return doc
  end

  local refs = load_references()
  return doc:walk(citation_filter(volume, refs, target))
end

return {
  { Pandoc = process_document },
}
