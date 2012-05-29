require 'cocos2d'

-- search scripts in document directory first
package.path = NSDocumentDirectory .. "/Scripts/?.lua;" .. NSDocumentDirectory .. "/Scripts/?/init.lua;" .. package.path

function class(name, base)
    local c = {}    -- a new class instance
	if base == nil then
		base = object
	end
	c.super = base
	c.name = name
	
    -- the class will be the metatable for all its objects,
    -- and they will look up their methods in it.
    c.__index = function (obj, field)
		local cls = rawget(obj, 'class')
		while cls do
			local f = rawget(cls, field)
			if f then
				return f
			end
			cls = rawget(cls, 'super')
		end
		return	-- cannot find field
    end

    -- expose a constructor which can be called by <classname>(<args>)
    local mt = {}
    mt.__call = function(class_tbl, ...)
        local obj = {}
        setmetatable(obj,c)
        
        obj.class = c
        
        if class_tbl.init then
            class_tbl.init(obj,...)
        else 
            -- make sure that any stuff from the base class is initialized!
            if base and base.init then
                base.init(obj, ...)
            end
        end
        
        return obj
    end

    c.is_a = function(self, klass)
        local m = getmetatable(self)
        while m do 
            if m == klass then return true end
            m = m.super
        end
        return false
    end

    setmetatable(c, mt)
    _ENV[name] = c
    return c
end

class("object")	-- create base class
object.super = nil	-- base class does not have super

function object:tostring()
	print("<class " .. self.class.name .. "> " .. tostring(self))
end

print('loaded')