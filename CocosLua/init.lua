require 'cocos2d'

-- search scripts in document directory first
package.path = NSDocumentDirectory .. "/Scripts/?.lua;" .. NSDocumentDirectory .. "/Scripts/?/init.lua;" .. package.path

print('loaded')