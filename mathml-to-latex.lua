kpse.set_program_name "luatex"
local domobject = require "luaxml-domobject"

-- we need to define different actions for XML elements. The default action is
-- to just process child elements and return the result
local function default_action(element)
  return process_children(element)
end

-- use template string to place the processed children
local function simple_content(s)
  return function(element)
    local content = process_children(element)
    return string.format(s, content)
  end
end

local function math_action(element)
  local content = process_children(element)
  local display = element:get_attribute("display") or "inline"
  local template = "$%s$" 
  if display == "block" then template = "\n\\[\n%s\n\\]\n" end
  return string.format(template, content)
end

local mathvariant_templates = {
  normal = "\\mathrm{%s}",
  identifier = "\\operatorname{%s}" -- this needs amsmath package
  -- there are lot more, see https://developer.mozilla.org/en-US/docs/Web/MathML/Element/mi
}

local function mi_action(element)
  local content = process_children(element)
  -- how should be <mi> rendered is based on the length.
  -- one character should be rendered in italic, two and more characters
  -- act like identifier like \sin
  local implicit_mathvariant = utf8.len(content) > 1 and "identifier" or "italic"
  -- the rendering can be also based on the mathvariant attribute
  local mathvariant = element:get_attribute("mathvariant") or implicit_mathvariant
  local template = mathvariant_templates[mathvariant] or "%s"
  return string.format(template, content)

end

local function get_child_element(element, count)
  -- return specified child element 
  local i = 0
  for _, el in ipairs(element:get_children()) do
    -- count elements 
    if el:is_element() then
      -- return the desired numbered element
      i = i + 1
      if i == count then return el end
    end
  end
end

local function frac_action(element)
  -- <mfrac> should have two children, we need to process them separatelly
  local numerator = process_children(get_child_element(element, 1))
  local denominator = process_children(get_child_element(element, 2))
  return string.format("\\frac{%s}{%s}", numerator, denominator)
end

-- actions for particular elements
local actions = {
  title = simple_content("\\section{%s}\n"),
  para = simple_content("%s\n\\par"),
  math = math_action,
  mi = mi_action,
  mfrac = frac_action, -- example of element that needs to process the children separatelly
  -- here you can add more elements, like <mo> etc.
}

-- convert Unicode characters to TeX sequences
local unicodes = {
   [960] = "\\pi{}"
}

local function process_text(text)
  local t = {}
  -- process all Unicode characters and find if they should be replaced
  for _, char in utf8.codes(text) do
    -- construct new string with replacements or original char
    t[#t+1] = unicodes[char] or utf8.char(char)
  end
  return table.concat(t)
end

function process_children(element)
  -- accumulate text from children elements
  local t = {}
  -- sometimes we may get text node
  if type(element) ~= "table" then return element end
  for i, elem in ipairs(element:get_children()) do
    if elem:is_text() then
      -- concat text
      t[#t+1] = process_text(elem:get_text())
    elseif elem:is_element() then
      -- recursivelly process child elements
      t[#t+1] = process_tree(elem)
    end
  end
  return table.concat(t)
end


function process_tree(element)
  -- find specific action for the element, or use the default action
  local element_name = element:get_element_name()
  local action = actions[element_name] or default_action
  return action(element)
end

function parse_xml(content)
  -- parse XML string and process it
  local dom = domobject.parse(content)
  -- start processing of DOM from the root element
  -- return string with TeX content
  return process_tree(dom:root_node())
end


function print_tex(content)
  -- we need to replace "\n" characters with calls to tex.sprint
  for s in content:gmatch("([^\n]*)") do
    tex.sprint(s)
  end
end

local M = {
  parse_xml = parse_xml,
  print_tex = print_tex
}

return M