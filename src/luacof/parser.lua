-- Copyright 2026 SoTeen Studio
-- Parses LuaCof tokens into declarations, expressions, types, and interfaces.

local diagnostics = require("luacof.diagnostics")
local M = {}

-- Parse a complete token stream into an unresolved document.
function M.parse(tokens)
    local index = 1
    local function current() return tokens[index] end
    local function fail(message, token) diagnostics.raise("parse", message, token or current()) end
    local function accept(value)
        if current().val == value then local token = current(); index = index + 1; return token end
    end
    local function expect(value, message)
        local token = accept(value); if not token then fail(message or ("expected '" .. value .. "'")) end; return token
    end
    local function identifier(message)
        local token = current(); if token.type ~= "IDENT" then fail(message or "identifier expected", token) end
        index = index + 1; return token
    end
    local function typeMemberSeparator(kind, name)
        -- Type members prefer Lua-style "=" while retaining legacy ":" support.
        if not accept("=") and not accept(":") then
            fail("expected '=' or ':' after " .. kind .. " field " .. name.val)
        end
    end

    local parseType
    parseType = function()
        local loc = current()
        local result
        if accept("{") then
            local fields = {}
            while not accept("}") do
                local name = identifier("object type field expected")
                local optional = accept("?") ~= nil
                typeMemberSeparator("object type", name)
                fields[name.val] = { type = parseType(), optional = optional, location = name }
                accept(",")
            end
            result = { kind = "object", fields = fields, location = loc }
        else
            local name = identifier("type expected")
            if name.val == "string" or name.val == "number" or name.val == "boolean" then
                result = { kind = name.val, location = name }
            else result = { kind = "reference", name = name.val, location = name } end
        end
        while accept("[") do expect("]"); result = { kind = "array", element = result, location = loc } end
        return result
    end

    local parseExpression
    local function atom()
        local token = current()
        if accept("@") then return atom() end
        if accept("(") then local value = parseExpression(); expect(")"); return value end
        if accept("[") then
            local values = {}
            if not accept("]") then
                repeat values[#values + 1] = parseExpression() until not accept(",")
                expect("]")
            end
            return { kind = "array", values = values, location = token }
        end
        if token.type == "STRING" or token.type == "NUMBER" or token.type == "BOOL" then
            index = index + 1; return { kind = "literal", value = token.val, location = token }
        end
        if token.type == "ENV" or token.type == "VAR" then
            index = index + 1; return { kind = token.type:lower(), name = token.val, location = token }
        end
        fail("value expected", token)
    end
    local function binary(nextParser, operator, matcher)
        local value = nextParser()
        while matcher(current(), operator) do
            local op = current(); index = index + 1
            value = { kind = "binary", operator = op.val, left = value, right = nextParser(), location = op }
        end
        return value
    end
    -- Precedence from tightest to loosest is atom, +, ??, then Lua-style or.
    local function concatenation() return binary(atom, "+", function(t, op) return t.val == op end) end
    local function fallback() return binary(concatenation, "??", function(t, op) return t.val == op end) end
    parseExpression = function() return binary(fallback, "or", function(t, op) return t.type == "IDENT" and t.val == op end) end

    local function fields()
        local result = {}
        while current().val ~= "}" do
            if current().type == "EOF" then fail("expected '}' at end of input") end
            local default = accept("default") ~= nil
            local name = identifier("field name expected")
            local typeSpec
            if accept(":") then typeSpec = parseType() end
            local entry = { name = name.val, default = default, type = typeSpec, location = name }
            if accept("=") then entry.value = parseExpression()
            elseif accept("{") then entry.fields = fields(); expect("}")
            else fail("expected '=' or '{' after " .. name.val) end
            result[#result + 1] = entry
        end
        return result
    end

    local document = { declarations = {}, interfaces = {} }
    while current().type ~= "EOF" do
        local keyword = identifier("declaration expected")
        if keyword.val == "interface" then
            local name = identifier("interface name expected")
            if document.interfaces[name.val] then fail("duplicate interface: " .. name.val, name) end
            expect("{"); local members = {}
            while not accept("}") do
                local field = identifier("interface field expected")
                local optional = accept("?") ~= nil
                typeMemberSeparator("interface", field)
                if members[field.val] then fail("duplicate interface field: " .. field.val, field) end
                members[field.val] = { type = parseType(), optional = optional, location = field }
                accept(",")
            end
            document.interfaces[name.val] = { name = name.val, fields = members, location = name }
        elseif keyword.val == "local" or keyword.val == "env" then
            local name = identifier(keyword.val .. " name expected")
            local typeSpec; if accept(":") then typeSpec = parseType() end
            expect("=", "expected '=' after " .. name.val)
            document.declarations[#document.declarations + 1] = { kind = keyword.val, name = name.val, type = typeSpec, value = parseExpression(), location = name }
        elseif keyword.val == "defaults" or keyword.val == "block" then
            local name = identifier(keyword.val .. " name expected")
            local interface; if accept(":") then interface = identifier("interface name expected").val end
            local parent; if accept("extends") then parent = identifier("profile name expected after extends").val end
            expect("{", "expected '{' after " .. name.val)
            local content = fields(); expect("}")
            document.declarations[#document.declarations + 1] = { kind = keyword.val, name = name.val, interface = interface, parent = parent, fields = content, location = name }
        else fail("expected local, env, interface, defaults, or block; got " .. keyword.val, keyword) end
    end
    return document
end

return M
