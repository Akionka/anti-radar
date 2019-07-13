script_name("AntiRadar")
script_author('akionka')
script_description('Информирует пользователя о приближении к камере')
script_version('1.0')
script_version_number(1)
script_url('vk.me/akionka')
script_moonloader(27)

require 'deps' {
  'fyp:samp-lua',
}

local sampev = require 'lib.samp.events'
local encoding = require 'encoding'
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
  while not isSampAvailable() do wait(100)

  if checkUpdates('https://github.com/Akionka/anti-radar/raw/master/version.json') then update('https://github.com/Akionka/anti-radar/raw/master/anti-radar-mh.lua') end

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
    if isCharInAnyCar(PLAYED_PED) and not isKeyDown(0x77) and nearestCamera.id then
      local distance = math.ceil(getDistanceBetweenCoords2d(x, y, nearestCamera.x, nearestCamera.y))
      if distance < 255 then
        local color = joinARGB(255, 255, distance, distance)
        renderFontDrawText(font, u8:decode('Дистанция до близжайщей камеры: '..distance..' м'), posX, posY, color)
      end
    end
    wait(0)
    end
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

function checkUpdates(json)
  local fpath = os.tmpname()
  if doesFileExist(fpath) then os.remove(fpath) end
  downloadUrlToFile(json, fpath, function(_, status, _, _)
    if status == dlstatus.STATUSEX_ENDDOWNLOAD then
      if doesFileExist(fpath) then
        local f = io.open(fpath, 'r')
        if f then
          local info = decodeJson(f:read('*a'))
          local updateversion = info.version_num
          f:close()
          os.remove(fpath)
          if updateversion > thisScript().version_num then
            return true
          end
        end
      end
    end
  end)
end


function update(url)
  downloadUrlToFile(url, thisScript().path, function(_, status1, _, _)
    if status1 == dlstatus.STATUS_ENDDOWNLOADDATA then
      thisScript():reload()
    end
  end)
end