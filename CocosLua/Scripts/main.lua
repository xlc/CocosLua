require 'LuaScene'

function main() -- entry point of lua script
    CCDirector:sharedDirector():pushScene(LuaScene:init())
    LuaServer:sharedServer():start()
end

