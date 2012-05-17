require 'cocos2d'
require 'LuaScene'

-- also search scripts in document directory
package.path = package.path .. NSDocumentDirectory .. "/Scripts/?.lua;" .. NSDocumentDirectory .. "/Scripts/?/init.lua"

print('loaded')