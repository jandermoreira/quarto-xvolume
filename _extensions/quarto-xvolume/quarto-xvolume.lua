-- Quarto filter to handle citations in multi-volume books
-- Jander Moreira

local debug = quarto.log.output
local json = require("json")

local function x_volume_error(msg)
  quarto.log.error("[FATAL] xvolume: " .. msg)
end

local function load_references(error_list)
  local path = os.getenv("QUARTO_PROJECT_DIR")
  local base_dir = path:match("^(.*)/[^/]+$")

  local refs_file = io.open(base_dir .. "/crossrefs.json", "r")
  if not refs_file then
    table.insert(error_list, "File 'crossref.json' not found. Make sure you're running the script.")
    return {}
  end

  local content = refs_file:read("*a")
  refs_file:close()
  local refs, _, err = json.decode(content)
  if not refs then
    table.insert(error_list, "File 'crossref.json' seems corrupted.")
    return {}
  end

  return refs, base_dir
end

local function get_info(meta)
  local error_list = {}
  local info = {}

  if meta["book"] and meta["book"]["volume"] then
    info["volume"] = tonumber(pandoc.utils.stringify(meta["book"]["volume"]))
  else
    table.insert(error_list, "No volume information found in metadata. Add 'book: volume: X' to your document's YAML.")
  end

  if meta["quarto-xvolume"] and meta["quarto-xvolume"]["base-url"] then
    info["target"] = pandoc.utils.stringify(meta["quarto-xvolume"]["base-url"])
  else
    table.insert(error_list, "No quarto-xvolume/base-url found in metadata. Edit your document's YAML to add it.")
  end

  if meta["quarto-xvolume"] and meta["quarto-xvolume"]["contribution-text"] then
    info["contribution_text"] = meta["quarto-xvolume"]["contribution-text"]
  else
    info["contribution_text"] = pandoc.Inlines {
      pandoc.Str("Contributed"),
      pandoc.Space(),
      pandoc.Str("to"),
      pandoc.Space(),
      pandoc.Str("chapters:")
    }
  end

  local refs, basedir = load_references(error_list)
  info["refs"] = refs
  info["base_dir"] = basedir

  if #error_list > 0 then
    local error_msg = "Errors found in processing document:\n" .. table.concat(error_list, "\n- ")
    x_volume_error(error_msg)
    return pandoc.read("Failed to process document due to errors. See log for details.", "markdown")
  end

  return info
end

local function citation_filter(info)
  return {
    Cite = function(cite)
      local id = cite.citations[1].id
      if not info["refs"][id] or info["refs"][id]["volume"] == volume or not info["refs"][id]["text"] then
        return cite
      end
      local text = pandoc.read(info["refs"][id]["text"], "markdown").blocks[1].content
      return pandoc.Link(
        text,
        info["target"] .. info["refs"][id]["volume"] .. "/" .. info["refs"][id]["file"] .. "#" .. id,
        "Volume " .. info["refs"][id]["volume"],
        { target = "_blank" }
      )
    end
  }
end

local function generate_author(author)
  local middle = author.middle_name and " " .. author.middle_name or ""
  local full_name = author.name .. middle .. " " .. author.surname

  local has_contribution = author.contribution and #author.contribution > 0
  if has_contribution then
    if author.contribution_text then
      author.contribution_text:extend({ pandoc.Space() })
    else
      author.contribution_text = pandoc.List:new()
    end
    for i = 1, #author.contribution do
      if i == #author.contribution and #author.contribution >= 2 then
        author.contribution_text:extend({ pandoc.Str(" e ") })
      elseif i > 1 then
        author.contribution_text:extend({ pandoc.Str(","), pandoc.Space() })
      end
      author.contribution_text:extend({ table.unpack(author.contribution[i]) })
    end
  end
  author.contribution_text:extend({ pandoc.Str(".") })
  author.description:extend({ pandoc.Space(), table.unpack(author.contribution_text) })
  if quarto.doc.is_format("pdf") then
    return pandoc.Blocks({
      pandoc.Header(2, pandoc.Span {
        pandoc.Str(full_name),
      }, pandoc.Attr("", { "unnumbered" })),
      pandoc.Para(author.description),
      pandoc.Para {
        pandoc.RawInline("latex", "\\noindent "),
        pandoc.Str("Email: "),
        pandoc.Link(pandoc.Code(author.email), "mailto:" .. author.email)
      }
    })
  else
    quarto.doc.add_resource(author.photo)
    return pandoc.Blocks({
      pandoc.Header(
        2, pandoc.Span {
          pandoc.Str(full_name),
          pandoc.Space(),
          pandoc.Link("📨️", "mailto:" .. author.email)
        }, pandoc.Attr(full_name, { "unnumbered" })
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
          pandoc.Div({ pandoc.Para(author.description) }, pandoc.Attr("", { "grid-column" }))
        }, pandoc.Attr(
          "",
          { "grid-container" },
          { style = "display: grid; grid-template-columns: 30% 70%; gap: 1rem;" }
        )
      )
    })
  end
end


local function include_filter(info)
  return {
    CodeBlock = function(block)
      if not block.classes:includes("include") or not block.attributes.author then
        return block
      end

      local f = io.open(info["base_dir"] .. "/authors/" .. block.attributes.author, "r")
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
      author_info.contribution_text = info["contribution_text"]
      if doc_incluido.meta["authoring"]["contribution-text"] then
        author_info.contribution_text = doc_incluido.meta["authoring"]["contribution-text"]
      else
        author_info.contribution_text = info["contribution_text"]
      end
      author_info.contribution = doc_incluido.meta["authoring"]["contribution"]
      -- local contribs = ""
      -- for i = 1, #author_info.contribution do
      --   if i == #author_info.contribution and #author_info.contribution >= 2 then
      --     contribs = contribs .. " e "
      --   elseif i > 1 then
      --     contribs = contribs .. ", "
      --   end
      --   contribs = contribs .. pandoc.utils.stringify(author_info.contribution[i])
      -- end
      -- contribs = contribs .. "."
      -- author_info.contribution = contribs
      author_info.base_dir = info["base_dir"]
      return generate_author(author_info)
    end
  }
end

local function process_document(doc)
  local error_list = {}

  local info = get_info(doc.meta)


  doc = doc:walk(include_filter(info))
  doc = doc:walk(citation_filter(info))
  return doc
end

return {
  { Pandoc = process_document },
}
