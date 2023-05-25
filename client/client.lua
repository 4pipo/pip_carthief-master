QBCore = nil

-- Main Job:
local SelectedID                        = nil
local JobVehicle                        = nil
local Goons                             = {}
local blip                              = nil
local isCarLockpicked                   = false
local nr                                = 0
local Deliver1                          = nil
local Deliver2                          = nil
local carIsDelivered                    = false
local endBlip                           = nil
local endBlipCreated                    = false
local DeliveryInProgress                = false
local JobInProgress                     = false

-- NPC Mission spawn event:
local JobPED = nil
RegisterNetEvent("pip_carthief:spawnNPC")
AddEventHandler("pip_carthief:spawnNPC",function(NPC)
    local JobPedPos = NPC.Pos
    local JobPedHeading = NPC.Heading
    RequestModel(GetHashKey(NPC.Ped))
    while not HasModelLoaded(GetHashKey(NPC.Ped)) do
        Citizen.Wait(100)
    end
    JobPED = CreatePed(7,GetHashKey(NPC.Ped),JobPedPos[1],JobPedPos[2],JobPedPos[3],JobPedHeading,0,true,true)
    FreezeEntityPosition(JobPED,true)
    SetBlockingOfNonTemporaryEvents(JobPED, true)
    TaskStartScenarioInPlace(JobPED, "WORLD_HUMAN_AA_SMOKE", 0, false)
    SetEntityInvincible(JobPED,true)
    print(JobPED)
end)

local interacting
-- Job NPC Thread Function:
Citizen.CreateThread(function()
    TriggerEvent('QBCore:GetObject', function(obj) QBCore = obj end)
    print("CreateThread: %s", JobPED)
    while true do
        Citizen.Wait(3)
        local pedCoords = GetEntityCoords(JobPED)
        local plyCoords = GetEntityCoords(PlayerPedId())
        local distance = Vdist2(pedCoords[1], pedCoords[2], pedCoords[3], plyCoords.x, plyCoords.y, plyCoords.z)
        if distance <= 1.5 and not interacting then
            DrawText3Ds(pedCoords[1], pedCoords[2], pedCoords[3], "[E] Car Thief")
            if IsControlJustPressed(0, Config.KeyToTalk) then
                GetJobFromNPC()
                Citizen.Wait(250)
            end
        end
    end
end)

-- Requests the mission from NPC function:
function GetJobFromNPC()
    interacting = true
    local player = PlayerPedId()
    local anim_lib = "missheistdockssetup1ig_5@base"
    local anim_dict = "workers_talking_base_dockworker1"

    RequestAnimDict(anim_lib)
    while not HasAnimDictLoaded(anim_lib) do
        Citizen.Wait(0)
    end
                FreezeEntityPosition(player,true)
                TaskPlayAnim(player,anim_lib,anim_dict,1.0,0.5,-1,31,1.0,0,0)
                --exports['progressBars']:startUI((4 * 1000), _U('progbar_talking'))
                --Citizen.Wait((4 * 1000))
                ClearPedTasks(player)
                ClearPedSecondaryTask(player)

                ChooseRiskGrade()
    Citizen.Wait(500)
end

function ChooseRiskGrade()
    local player = PlayerPedId()
    elements = {}

    for k,v in pairs(Config.RiskGrades) do
        if v.Enabled == true then
            table.insert(elements,{label = v.Label .. " | "..('<span style="color:green;">%s</span>'):format("$"..v.BuyPrice..""), value = v.Grade, Enabled = v.Enabled, BuyPrice = v.BuyPrice, MinCops = v.MinCops, Cars = v.Cars})
        end
    end
    table.insert(elements,{label = 'Cancel', value = "cancel_interaction_with_npc"})

    local randomVal = math.random(1,3)
    TriggerServerEvent("pip_carthief:GetRiskGrade", randomVal, elements[randomVal].BuyPrice, elements[randomVal].MinCops, elements[randomVal].Cars)
    Citizen.Wait(100)
    ClearPedTasks(player)
    FreezeEntityPosition(player, false)
    interacting = false
end

RegisterNetEvent("pip_carthief:BrowseAvailableJobs")
AddEventHandler("pip_carthief:BrowseAvailableJobs",function(spot,grade,car)
    local id = math.random(1, #Config.CarJobs)
    local currentID = spot
    while Config.CarJobs[id].InProgress and currentID < 100 do
        currentID = currentID + 1
        id = math.random(1, #Config.CarJobs)
    end
    if currentID == 100 then
        QBCore.Functions.Notify('No jobs are currently available, please try again later!')
    else
        SelectedID = id
        TriggerEvent("pip_carthief:StartTheJob", id, grade, car)
    end
end)

-- Event to browse through available locations:
RegisterNetEvent("pip_carthief:StartTheJob")
AddEventHandler("pip_carthief:StartTheJob",function(id,grade,car)
    local VehName = car.Name
    local VehHash = car.Hash
    local VehPrice = car.Reward
    QBCore.Functions.Notify('Follow your GPS and steal the: %s', VehName)

    local Goons = {}
    local CurrentJob = Config.CarJobs[id]
    CurrentJob.InProgress = true
    TriggerServerEvent("pip_carthief:syncJobsData",Config.CarJobs)
    Citizen.Wait(500)
    local playerPed = GetPlayerPed(-1)
    local JobCompleted = false
    local blip = CreateMissionBlip(CurrentJob)

    while not JobCompleted do
        Citizen.Wait(0)

        if Config.CarJobs[id].InProgress == true then

            local coords = GetEntityCoords(playerPed)

            if (GetDistanceBetweenCoords(coords, CurrentJob.Spot[1], CurrentJob.Spot[2], CurrentJob.Spot[3], true) < 150) and not CurrentJob.CarSpawned then
                ClearAreaOfVehicles(CurrentJob.Spot[1], CurrentJob.Spot[2], CurrentJob.Spot[3], 15.0, false, false, false, false, false)
                local VehCoords = {CurrentJob.Spot[1], CurrentJob.Spot[2], CurrentJob.Spot[3]}
                while QBCore == nil do
                    Citizen.Wait(1)
                end
                print('QBCore not nil')
                QBCore.Functions.SpawnVehicle(VehName, function(veh)
                    JobVehicle = veh
                    SetEntityCoordsNoOffset(JobVehicle, CurrentJob.Spot[1], CurrentJob.Spot[2], CurrentJob.Spot[3])
                    SetEntityHeading(JobVehicle,CurrentJob.Heading)
                    FreezeEntityPosition(JobVehicle, true)
                    SetVehicleOnGroundProperly(JobVehicle)
                    FreezeEntityPosition(JobVehicle, false)
                    SetEntityAsMissionEntity(JobVehicle, true, true)
                    SetVehicleDoorsLockedForAllPlayers(JobVehicle, true)
                    print('Vehicle Spawned')
                end, VehCoords, true)
                CurrentJob.CarSpawned = true
                TriggerServerEvent("pip_carthief:syncJobsData",Config.CarJobs)
            end
            if grade == 2 or grade == 3 then
                if (GetDistanceBetweenCoords(coords, CurrentJob.Spot[1], CurrentJob.Spot[2], CurrentJob.Spot[3], true) < 150) and CurrentJob.CarSpawned and not CurrentJob.GoonsSpawned then
                    ClearAreaOfPeds(CurrentJob.Spot[1], CurrentJob.Spot[2], CurrentJob.Spot[3], 50, 1)
                    CurrentJob.GoonsSpawned = true
                    TriggerServerEvent("pip_carthief:syncJobsData",Config.CarJobs)
                    SetPedRelationshipGroupHash(playerPed, GetHashKey("PLAYER"))
                    AddRelationshipGroup('JobNPCs')
                    local i = 0
                    for k,v in pairs(CurrentJob.Goons) do
                        RequestModel(GetHashKey(v.ped))
                        while not HasModelLoaded(GetHashKey(v.ped)) do
                            Wait(1)
                        end
                        Goons[i] = CreatePed(4, GetHashKey(v.ped), v.Pos[1], v.Pos[2], v.Pos[3], v.h, false, true)
                        NetworkRegisterEntityAsNetworked(Goons[i])
                        SetNetworkIdCanMigrate(NetworkGetNetworkIdFromEntity(Goons[i]), true)
                        SetNetworkIdExistsOnAllMachines(NetworkGetNetworkIdFromEntity(Goons[i]), true)
                        SetPedCanSwitchWeapon(Goons[i], true)
                        SetPedArmour(Goons[i], v.armour)
                        SetPedAccuracy(Goons[i], v.accuracy)
                        SetEntityInvincible(Goons[i], false)
                        SetEntityVisible(Goons[i], true)
                        SetEntityAsMissionEntity(Goons[i])
                        RequestAnimDict(v.animDict)
                        while not HasAnimDictLoaded(v.animDict) do
                            Citizen.Wait(0)
                        end
                        TaskPlayAnim(Goons[i], v.animDict, v.animLib, 8.0, -8, -1, 49, 0, 0, 0, 0)
                        if grade == 2 then
                            GiveWeaponToPed(Goons[i], GetHashKey(v.weapon2), 1, false, false)
                        elseif grade == 3 then
                            GiveWeaponToPed(Goons[i], GetHashKey(v.weapon3), 255, false, false)
                        end
                        SetPedDropsWeaponsWhenDead(Goons[i], false)
                        SetPedCombatAttributes(Goons[i], false)
                        if Config.EnableHeadshotKills == false then
                            SetPedSuffersCriticalHits(Goons[i], false)
                        end
                        SetPedFleeAttributes(Goons[i], 0, false)
                        SetPedCombatAttributes(Goons[i], 16, true)
                        SetPedCombatAttributes(Goons[i], 46, true)
                        SetPedCombatAttributes(Goons[i], 26, true)
                        SetPedSeeingRange(Goons[i], 75.0)
                        SetPedHearingRange(Goons[i], 50.0)
                        SetPedEnableWeaponBlocking(Goons[i], true)
                        SetPedRelationshipGroupHash(Goons[i], GetHashKey("JobNPCs"))
                        TaskGuardCurrentPosition(Goons[i], 15.0, 15.0, 1)
                        i = i +1
                    end
                end
            end

            if (GetDistanceBetweenCoords(coords, CurrentJob.Spot[1], CurrentJob.Spot[2], CurrentJob.Spot[3], true) < 60) and not CurrentJob.JobPlayer then
                CurrentJob.JobPlayer = true
                TriggerServerEvent("pip_carthief:syncJobsData",Config.CarJobs)
                Citizen.Wait(500)
                SetPedRelationshipGroupHash(playerPed, GetHashKey("PLAYER"))
                AddRelationshipGroup('JobNPCs')
                local i = 0
                for k,v in pairs(CurrentJob.Goons) do
                    ClearPedTasksImmediately(Goons[i])
                    TaskCombatPed(Goons[i],playerPed, 0, 16)
                    SetPedCombatAttributes(Goons[i], false)
                    if Config.EnableHeadshotKills == false then
                        SetPedSuffersCriticalHits(Goons[i], false)
                    end
                    SetPedFleeAttributes(Goons[i], 0, false)
                    SetPedCombatAttributes(Goons[i], 16, true)
                    SetPedCombatAttributes(Goons[i], 46, true)
                    SetPedCombatAttributes(Goons[i], 26, true)
                    SetPedSeeingRange(Goons[i], 75.0)
                    SetPedHearingRange(Goons[i], 50.0)
                    SetPedEnableWeaponBlocking(Goons[i], true)
                    i = i +1
                end
                SetRelationshipBetweenGroups(0, GetHashKey("JobNPCs"), GetHashKey("JobNPCs"))
                SetRelationshipBetweenGroups(5, GetHashKey("JobNPCs"), GetHashKey("PLAYER"))
                SetRelationshipBetweenGroups(5, GetHashKey("PLAYER"), GetHashKey("JobNPCs"))
            end

            local CarPosition = GetEntityCoords(JobVehicle)

            if (GetDistanceBetweenCoords(coords, CarPosition[1], CarPosition[2], CarPosition[3], true) <= 2) and isCarLockpicked == false then
                DrawText3Ds(CarPosition[1], CarPosition[2], CarPosition[3], 'Press ~g~[G]~s~ to ~y~Lockpick~s~')
                if IsControlJustPressed(1, Config.KeyToLockpick) then
                    LockpickCar(CurrentJob)
                    DrawVehHealth(JobVehicle)
                    Citizen.Wait(500)
                end
            end

            if IsPedInAnyVehicle(playerPed, true) and isCarLockpicked == true then
                if GetDistanceBetweenCoords(coords, CurrentJob.Spot[1], CurrentJob.Spot[2], CurrentJob.Spot[3], true) < 5 then
                    local lockpickedVehicle = GetVehiclePedIsIn(playerPed, false)
                    if GetEntityModel(lockpickedVehicle) == VehHash then
                        RemoveBlip(blip)
                        if endBlipCreated == false then
                            nr = math.random(1,#Config.DeliverySpot)
                            Deliver1 = Config.DeliverySpot[nr]
                            -- new MSG for player:
                            QBCore.Functions.Notify('Deliver the car at the new GPS i have sent to you.')
                            endBlipCreated = true
                            endBlip = AddBlipForCoord(Deliver1.Pos[1], Deliver1.Pos[2], Deliver1.Pos[3])
                            SetBlipSprite(endBlip, Deliver1.BlipSprite)
                            SetBlipColour(endBlip,Deliver1.BlipColor)
                            BeginTextCommandSetBlipName("STRING")
                            AddTextComponentString(Deliver1.BlipName)
                            EndTextCommandSetBlipName(endBlip)
                            SetBlipScale(endBlip,Deliver1.BlipScale)
                            if Deliver1.EnableBlipRoute then
                                SetBlipRoute(endBlip, true)
                                SetBlipRouteColour(endBlip, Deliver1.BlipColor)
                            end
                        end
                        DeliveryInProgress = true
                    end
                end
            end

            if DeliveryInProgress and not carIsDelivered then

                local lockpickedVehicle = GetVehiclePedIsIn(playerPed, false)
                Deliver2 = Config.DeliverySpot[nr]
                if GetEntityModel(lockpickedVehicle) == VehHash then
                    if(GetDistanceBetweenCoords(coords, Deliver2.Pos[1], Deliver2.Pos[2], Deliver2.Pos[3], true) < Deliver2.DrawDist) then
                        DrawMarker(Deliver2.MarkerType, Deliver2.Pos[1], Deliver2.Pos[2], Deliver2.Pos[3]-0.97, 0.0, 0.0, 0.0, 180.0, 0.0, 0.0, Deliver2.MarkerScale.x, Deliver2.MarkerScale.y, Deliver2.MarkerScale.z, Deliver2.MarkerColor.r, Deliver2.MarkerColor.g, Deliver2.MarkerColor.b, Deliver2.MarkerColor.a, false, true, 2, false, false, false, false)
                    end
                    if (GetDistanceBetweenCoords(coords, Deliver2.Pos[1], Deliver2.Pos[2], Deliver2.Pos[3], true) < 2.0) and not carIsDelivered then
                        DrawText3Ds(Deliver2.Pos[1], Deliver2.Pos[2], Deliver2.Pos[3], 'Press ~g~[E]~s~ to ~y~Delivery~s~')
                        if IsControlJustPressed(0, Config.KeyToDeliver) then
                            local JobCarHealth = (GetEntityHealth(lockpickedVehicle)/10)
                            local RoundHealth = round(JobCarHealth, 0)
                            RemoveBlip(endBlip)
                            carIsDelivered = true
                            SetVehicleForwardSpeed(JobVehicle, 0)
                            SetVehicleEngineOn(JobVehicle, false, false, true)
                            if IsPedInAnyVehicle(playerPed, true) then
                                TaskLeaveVehicle(playerPed, JobVehicle, 4160)
                                SetVehicleDoorsLockedForAllPlayers(JobVehicle, true)
                            end
                            Citizen.Wait(500)
                            FreezeEntityPosition(JobVehicle, true)
                            TriggerServerEvent("pip_carthief:JobComplete",VehPrice,RoundHealth)

                            QBCore.Functions.Notify('Good job! Come see me again if you want to earn more cash')
                            

                            StopTheJob = true
                        end
                    end
                end
            end

            if JobVehicle ~= nil then
                if CurrentJob.CarSpawned == true then
                    if not DoesEntityExist(JobVehicle) then
                        StopTheJob = true
                        QBCore.Functions.Notify('The car was taken by someone, maybe the police?')
                    end
                end
                if isCarLockpicked then
                    local VehPos = GetEntityCoords(JobVehicle)
                    if DoesEntityExist(JobVehicle) then
                        if (GetDistanceBetweenCoords(coords, VehPos[1], VehPos[2], VehPos[3], true) >= 50.0) then
                            StopTheJob = true
                            QBCore.Functions.Notify('You went too far away from the vehicle, maybe someone stole it?')
                        end
                    end
                end
            end

            if StopTheJob == true then

                Config.CarJobs[id].InProgress = false
                Config.CarJobs[id].CarSpawned = false
                Config.CarJobs[id].GoonsSpawned = false
                Config.CarJobs[id].JobPlayer = false
                TriggerServerEvent("pip_carthief:syncJobsData",Config.CarJobs)
                Citizen.Wait(2000)
                QBCore.Functions.DeleteVehicle(JobVehicle)

                if DeliveryInProgress == true then
                    RemoveBlip(endBlip)
                else
                    RemoveBlip(blip)
                end

                local i = 0
                for k,v in pairs(CurrentJob.Goons) do
                    if DoesEntityExist(Goons[i]) then
                        DeleteEntity(Goons[i])
                    end
                    i = i +1
                end

                JobCompleted            = true
                StopTheJob              = false
                SelectedID              = nil
                JobVehicle              = nil
                Goons                   = {}
                blip                    = nil
                isCarLockpicked         = false
                carIsDelivered          = false
                endBlip                 = nil
                endBlipCreated          = false
                DeliveryInProgress      = false
                Deliver1                = nil
                Deliver2                = nil
                nr                       = 0
                JobInProgress           = false

                break

            end
        end
    end
end)

-- Function for lockpicking the van door:
function LockpickCar(CurrentJob)

    local playerPed = GetPlayerPed(-1)
    local animDict = "anim@amb@clubhouse@tutorial@bkr_tut_ig3@"
    local animName = "machinic_loop_mechandplayer"

    RequestAnimDict(animDict)
    while not HasAnimDictLoaded(animDict) do
        Citizen.Wait(50)
    end

    if Config.PoliceAlerts then
        AlertPoliceFunction()
    end

    SetCurrentPedWeapon(playerPed, GetHashKey("WEAPON_UNARMED"),true)
    Citizen.Wait(500)
    FreezeEntityPosition(playerPed, true)
    TaskPlayAnim(playerPed, animDict, animName, 3.0, 1.0, -1, 31, 0, 0, 0)
    -- Car Alarm:
    if Config.EnableThiefAlarm then
        SetVehicleAlarm(JobVehicle, true)
        SetVehicleAlarmTimeLeft(JobVehicle, (Config.CarAlarmTime * 1000))
        StartVehicleAlarm(JobVehicle)
    end
    -- Progbar:
    exports['progressBars']:startUI((Config.LockpickTime * 1000), 'LOCKPICKING')
    Citizen.Wait(Config.LockpickTime * 1000)
    -- Hot Wire:
    SetVehicleNeedsToBeHotwired(JobVehicle, true)
    IsVehicleNeedsToBeHotwired(JobVehicle)
    -- End:
    ClearPedTasks(playerPed)
    FreezeEntityPosition(playerPed, false)
    isCarLockpicked = true
    SetVehicleDoorsLockedForAllPlayers(JobVehicle, false)
end

function DrawVehHealth(JobVehicle)
    Citizen.CreateThread(function()
        JobInProgress = true
        while JobInProgress do
            Citizen.Wait(0)
            local vehTest = JobVehicle
            local vehHealth = (GetEntityHealth(vehTest)/10)
            DrawVehHealthUtils(vehHealth)
        end
    end)
end

-- Blip on Map for NPC:
Citizen.CreateThread(function()
    for k,v in pairs(Config.JobNPC) do
        if v.EnableBlip then
            local blip = AddBlipForCoord(v.Pos[1], v.Pos[2], v.Pos[3])
            SetBlipSprite (blip, v.blipSprite)
            SetBlipDisplay(blip, 4)
            SetBlipScale  (blip, v.blipScale)
            SetBlipColour (blip, v.blipColor)
            SetBlipAsShortRange(blip, true)
            BeginTextCommandSetBlipName("STRING")
            AddTextComponentString(v.blipName)
            EndTextCommandSetBlipName(blip)
        end
    end
end)

-- Function for job blip in progress:
function CreateMissionBlip(Job)
    local blip = AddBlipForCoord(Job.Spot[1],Job.Spot[2],Job.Spot[3])
    SetBlipSprite(blip, Job.BlipSprite)
    SetBlipColour(blip, Job.BlipColor)
    AddTextEntry('MYBLIP', Job.BlipName)
    BeginTextCommandSetBlipName('MYBLIP')
    AddTextComponentSubstringPlayerName(name)
    EndTextCommandSetBlipName(blip)
    SetBlipScale(blip, Job.BlipScale)
    SetBlipAsShortRange(blip, true)
    if Job.EnableBlipRoute then
        SetBlipRoute(blip, true)
        SetBlipRouteColour(blip, Job.BlipColor)
    end
    return blip
end

AddEventHandler('QBCore:Client:OnPlayerUnload', function(data)
    StopTheJob = true
    TriggerServerEvent("pip_carthief:syncJobsData",Config.CarJobs)
    Citizen.Wait(5000)
    StopTheJob = false
end)

AddEventHandler('playerSpawned', function(spawn)
    isDead = false
end)

RegisterNetEvent("pip_carthief:syncJobsData")
AddEventHandler("pip_carthief:syncJobsData",function(data)
    Config.CarJobs = data
end)
