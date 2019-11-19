script_name("anti-radar")
script_author('akionka')
script_description('Информирует пользователя о приближении к камере')
script_version('1.0.5')
script_version_number(6)
script_url('vk.me/akionka')
script_moonloader(27)

require 'deps' {
  'fyp:samp-lua',
  'Akionka:lua-semver',
}

local sampev   = require 'lib.samp.events'
local encoding = require 'encoding'
local v        = require 'semver'

encoding.default = 'cp1251'
local u8 = encoding.UTF8

local nearestCamera = {}
local cameras = {}
local font = renderCreateFont('Arial', 10, 5)
local posX, posY = convertGameScreenCoordsToWindowScreenCoords(495, 365)


function sampev.onCreateObject(id, object)
  --[[
    Обработчик создания нового объекта. Если модель равна 18880, то
    добавляем ее в общий стек камер и ставим в качество близжайщей,
    если она таковой является.
   ]]

  if object.modelId == 18880 then
    table.insert(cameras, {
      id = id,
      x = object.position.x, y = object.position.y, z = object.position.z,
    })
    local x, y = getCoordinates()
    if nearestCamera or getDistanceBetweenCoords2d(x, y, nearestCamera.x, nearestCamera.y) > getDistanceBetweenCoords2d(x, y, object.position.x, object.position.y) then
      nearestCamera = {
        id = id,
        x = object.position.x, y = object.position.y,
      }
    end
  end
end


function sampev.onDestroyObject(id)
  --[[
    Обработчик удаление объекта. Если это — близжайщая камера, то
    зануляем её и удаляем из общего стека.
   ]]

  if not nearestCamera and nearestCamera.id == id then nearestCamera = {} end
  for i, v in ipairs(cameras) do if v['id'] == id then table.remove(cameras, i) break end end
end


function main()
  if not isSampLoaded() or not isSampfuncsLoaded() then return end
  while not isSampAvailable() do wait(100) end

  local result, tag = checkUpdates()
  if result then
    update(tag)
  end

  while true do
    --[[
      В бесконечном цикле обрабатываем список камер. Если одна из них
      ближе, чем текущая близжайщая, то устаналиваем ее в качестве
      близжайщей.

      Если близжайщая вообще существует, то рендерим над спидомертом
      текст о том, сколько до близжайщей камеры метров. Но только если
      игрок находится в машине, ну и не нажата клавиша F8, чтобы не
      палиться на скриншотах, а то мало-ли :)
     ]]


    local x, y, z = getCoordinates()
    for i, v in ipairs(cameras) do
      if getDistanceBetweenCoords2d(x, y, nearestCamera.x, nearestCamera.y) > getDistanceBetweenCoords2d(x, y, v.x, v.y) then
        nearestCamera = v
        break
      end
    end

    if isCharInAnyCar(PLAYER_PED) and not isKeyDown(0x77) and nearestCamera.id then
      local distance = math.ceil(getDistanceBetweenCoords2d(x, y, nearestCamera.x, nearestCamera.y))
      if distance < 255 then
        local color = joinARGB(255, 255, distance, distance)
        renderFontDrawText(font, u8:decode('Дистанция до близжайщей камеры: '..distance..' м'), posX, posY, color)
      end
    end
    wait(0)
  end
end


function getCoordinates()
  --[[
    Функция для получения координат.
   ]]

  if isCharInAnyCar(playerPed) then
    local car = storeCarCharIsInNoSave(playerPed)
    return getCarCoordinates(car)
  else
    return getCharCoordinates(playerPed)
  end
end

function joinARGB(a, r, g, b)
  --[[
    Функция, соединяющая Alpha, Red, Green, Blue каналы в один цвет.
    Автор: FYP.
   ]]

  local argb = b
  argb = bit.bor(argb, bit.lshift(g, 8))
  argb = bit.bor(argb, bit.lshift(r, 16))
  argb = bit.bor(argb, bit.lshift(a, 24))
  return argb
end

function checkUpdates()
  local fpath = os.tmpname()
  if doesFileExist(fpath) then os.remove(fpath) end
  downloadUrlToFile('https://api.github.com/repos/akionka/'..thisScript()['name']..'/releases', fpath, function(_, status, _, _)
    if status == 58 then
      if doesFileExist(fpath) then
        local f = io.open(fpath, 'r')
        if f then
          local info = decodeJson(f:read('*a'))
          f:close()
          os.remove(fpath)
          if v(info[1]['tag_name']) > v(thisScript()['version']) then
            return true, info[1]['tag_name']
          end
        end
      end
    end
  end)
end


function update(tag)
  downloadUrlToFile('https://github.com/akionka/'..thisScript()['name']..'/releases/download/'..tag..'/anti-radar-mh.lua', thisScript()['path'], function(_, status, _, _)
    if status == 6 then
      thisScript():reload()
    end
  end)
end