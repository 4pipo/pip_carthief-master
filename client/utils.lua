

QBCore 						= nil
local PlayerData            = {}


-- Outlaw Notify:
local timing, isPlayerWhitelisted = math.ceil(1 * 60000), false
local streetName
local _

Citizen.CreateThread(function()
	while QBCore == nil do
		TriggerEvent('QBCore:GetObject', function(obj) QBCore = obj end)
		Citizen.Wait(0)
	end
	while QBCore.Functions.GetPlayerData().job == nil do
		Citizen.Wait(10)
	end
	PlayerData = QBCore.Functions.GetPlayerData()
	isPlayerWhitelisted = refreshPlayerWhitelisted()
end)

RegisterNetEvent('QBCore:Client:OnPlayerLoaded')
AddEventHandler('QBCore:Client:OnPlayerLoaded', function(xPlayer)
	PlayerData = xPlayer
end)

RegisterNetEvent('QBCore:Client:OnJobUptade')
AddEventHandler('QBCore:Client:OnJobUptade', function(job)
	QBCore.Player.PlayerData.job = job
	isPlayerWhitelisted = refreshPlayerWhitelisted()
end)

function DrawVehHealthUtils(vehHealth)
	-- Background Settings:
	drawRct(0.905, 0.95, 0.0630, 0.020, 0, 0, 0, 80)
	-- Health Bar Settings:
	drawRct(0.905, 0.95, 0.0630*(vehHealth*0.01), 0.019, 255, 30, 0, 125)
	-- Text Settings:
	SetTextScale(0.34, 0.34)
	SetTextFont(4)
	SetTextProportional(1)
	SetTextColour(255, 255, 255, 255)
	SetTextEdge(2, 0, 0, 0, 150)
	SetTextEntry("STRING")
	SetTextCentre(1)
	AddTextComponentString('HEALTH:'..round(vehHealth, 1)..'%')
	DrawText(0.938,0.9480)
end

function drawRct(x, y, width, height, r, g, b, a)
	DrawRect(x + width/2, y + height/2, width, height, r, g, b, a)
end

function round(num, numDecimalPlaces)
  local mult = 10^(numDecimalPlaces or 0)
  return math.floor(num * mult + 0.5) / mult
end

-- Function for 3D text:
function DrawText3Ds(x,y,z, text)
    local onScreen,_x,_y=World3dToScreen2d(x,y,z)
    local px,py,pz=table.unpack(GetGameplayCamCoords())

    SetTextScale(0.32, 0.32)
    SetTextFont(4)
    SetTextProportional(1)
    SetTextColour(255, 255, 255, 255)
    SetTextEntry("STRING")
    SetTextCentre(1)
    AddTextComponentString(text)
    DrawText(_x,_y)
    local factor = (string.len(text)) / 500
    DrawRect(_x,_y+0.0125, 0.015+ factor, 0.03, 0, 0, 0, 80)
end

function refreshPlayerWhitelisted()	
	if not PlayerData then
		return false
	end
	if not PlayerData.job then
		return false
	end
	if Config.PoliceJobName == PlayerData.job.label then
		return true
	end
	return false
end
