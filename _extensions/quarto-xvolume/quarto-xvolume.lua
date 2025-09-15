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
        { target = "_blank" }
      )
    end
  }
end

local function generate_author(author, parent_dir)
  local middle = author.middle_name and " " .. author.middle_name or ""
  local full_name = author.name .. middle .. " " .. author.surname

  local contribution_doc = pandoc.read(author.contribution, "markdown")
  local contribution_blocks = contribution_doc.blocks or {}

  if quarto.doc.is_format("pdf") then
    return pandoc.Blocks({
      pandoc.Header(2, pandoc.Span {
        pandoc.Str(full_name),
      }, pandoc.Attr("", { "unnumbered" })),
      pandoc.Para { pandoc.Link(pandoc.Code(author.email), "mailto:" .. author.email) },
      pandoc.Para(author.description),
      table.unpack(contribution_blocks)
    })
  else
    quarto.doc.add_resource(author.photo)
    return pandoc.Blocks({
      pandoc.Header(
        2, pandoc.Span {
          pandoc.Str(full_name),
          pandoc.Space(),
          pandoc.Link("📨️", "mailto:" .. author.email)
        }, pandoc.Attr("", { "unnumbered" })
      ),
      pandoc.Div(
        {
          pandoc.Div(
            pandoc.Para {
              pandoc.Image(
                "",
                author.photo,
                full_name,
                { width = "100%" }
              )
            },
            pandoc.Attr("", { "grid-column" })
          ),
          pandoc.Div(
            {
              pandoc.Para(author.description),
              table.unpack(contribution_blocks)
            },
            pandoc.Attr("", { "grid-column" })
          )
        }, pandoc.Attr(
          "",
          { "grid-container" },
          { style = "display: grid; grid-template-columns: 30% 70%; gap: 1rem;" }
        )
      )
    })
  end
end


local function include_filter(parent_dir)
  return {
    CodeBlock = function(block)
      if not block.classes:includes("include") or not block.attributes.author then
        return block
      end

      local f = io.open(parent_dir .. "/authors/" .. block.attributes.author, "r")
      if not f then
        io.stderr:write("Cannot open file ", block.attributes.author, "\n")
        return { pandoc.Para("Fail: " .. block.attributes.author .. " not found.") }
      end
      local content = f:read("*all")
      f:close()
      local doc_incluido = pandoc.read(content, "markdown")

      local author_info = {}
      author_info.name = pandoc.utils.stringify(doc_incluido.meta["authoring"]["name"])
      author_info.middle_name = pandoc.utils.stringify(doc_incluido.meta["authoring"]["middle-name"])
      author_info.surname = pandoc.utils.stringify(doc_incluido.meta["authoring"]["surname"])
      author_info.description = doc_incluido.meta["authoring"]["description"]
      author_info.type = pandoc.utils.stringify(doc_incluido.meta["authoring"]["type"])
      author_info.photo = pandoc.utils.stringify(doc_incluido.meta["authoring"]["photo"])
      author_info.email = pandoc.utils.stringify(doc_incluido.meta["authoring"]["email"])
      author_info.contribution = doc_incluido.meta["authoring"]["contribution"]
      local contribs = ""
      for i = 1, #author_info.contribution do
        contribs = contribs .. (i > 1 and ", " or "") .. pandoc.utils.stringify(author_info.contribution[i])
      end
      author_info.contribution = contribs

      return generate_author(author_info, parent_dir)
    end
  }
end

local function load_references(parent_dir)
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

  local path = os.getenv("QUARTO_PROJECT_DIR")
  local parent_dir = path:match("^(.*)/[^/]+$")
  local refs = load_references(parent_dir)
  if not refs then
    debug("File 'crossref.json' not found.")
    return doc
  end

  doc = doc:walk(include_filter(parent_dir))
  doc = doc:walk(citation_filter(volume, refs, target))
  return doc
end

return {
  { Pandoc = process_document },
}
