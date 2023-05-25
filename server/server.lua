
local authoriseID = ''

QBCore                          = nil
local JobNPC                    = 0
local JobCooldown               = {}
local NPCspawned                = false

TriggerEvent('QBCore:GetObject', function(obj) QBCore = obj end)


Citizen.CreateThread(function()
    while true do
    Citizen.Wait(1000)
    while not NPCspawned do
        JobNPC = math.random(1,#Config.JobNPC)
        TriggerClientEvent("pip_carthief:spawnNPC",-1,Config.JobNPC[JobNPC])
        NPCspawned = true
    end
end
end)

-- thread for syncing the cooldown timer
Citizen.CreateThread(function()
    while true do
        Citizen.Wait(1000)
        for k,v in pairs(JobCooldown) do
            if v.time <= 0 then
                ResetJobCooldown(v.PlyIdentifier)
            else
                v.time = v.time - 1000
            end
        end
end
end)

-- Server Event for selecting risk grade:
RegisterServerEvent("pip_carthief:GetRiskGrade")
AddEventHandler("pip_carthief:GetRiskGrade", function(Grade, BuyPrice, MinCops, carArray)
    local xPlayer = QBCore.Functions.GetPlayer(source)
    print(carArray)
    -- local itemLabel = ESX.GetItemLabel(itemName)
    local paidForJob = false
    local JobVeh = nil

    -- Cops Check:
    local Players = QBCore.Functions.GetPlayers()
    local cops = 0
    for i = 1, #Players do
        local xPlayer = QBCore.Functions.GetPlayer(Players[i])
        if xPlayer.PlayerData.job.label == Config.PoliceJobName then
            cops = cops + 1
        end
    end

    if cops >= MinCops then
        -- Payment Check:
        local moneyCash = xPlayer.PlayerData.money['cash']
        if moneyCash >= BuyPrice then
            xPlayer.Functions.RemoveMoney("cash",BuyPrice)
            paidForJob = true
        end
        if not paidForJob then
            TriggerClientEvent("QBCore:Notify",source,'You do not have enough money')
        end
    else
        TriggerClientEvent("QBCore:Notify",source,'Not enough police in the city')
    end

    local car = math.random(1,#carArray)
    JobVeh = carArray[car]

    if paidForJob then
        if Grade == 1 then
            label = "Low"
        elseif Grade == 2 then
            label = "Medium"
        elseif Grade == 3 then
            label = "High"
        end
        TriggerClientEvent("pip_carthief:BrowseAvailableJobs", source, 0, Grade, JobVeh)
        TriggerClientEvent("QBCore:Notify",source,string.format('You paid %s for a %s risk job', BuyPrice, label))
    end
end)

-- Server Event for Job Reward:
RegisterServerEvent("pip_carthief:JobComplete")
AddEventHandler("pip_carthief:JobComplete",function(reward,percent)
    local xPlayer = QBCore.Functions.GetPlayer(source)
    local JobReward = math.floor(reward*(percent/100))
    xPlayer.Functions.AddMoney('cash',JobReward)
    TriggerClientEvent("QBCore:Notify",source,string.format('You received %s in cash for the car', JobReward))
end)


-- Callback to get cooldown timer:
QBCore.Functions.CreateCallback("pip_carthief:getJobCooldown",function(source,cb)
    local _source = source
    local xPlayer = QBCore.Functions.GetPlayer(_source)
    if not CheckJobCooldown(QBCore.Functions.GetIdentifer(source)) then
        cb(false)
    else
        TriggerClientEvent("QBCore:Notify",source,string.format(_U('cooldown_msg', GetJobCooldown(QBCore.Functions.GetIdentifer(source)))))
        cb(true)
    end
end)

-- Outlaw Notify

--

RegisterServerEvent("pip_carthief:syncJobsData")
AddEventHandler("pip_carthief:syncJobsData",function(data)
    TriggerClientEvent("pip_carthief:syncJobsData",-1,data)
end)

-- Functions for Job Cooldown:
function ResetJobCooldown(source)
    for k,v in pairs(JobCooldown) do
        if v.PlyIdentifier == source then
            table.remove(JobCooldown,k)
        end
    end
end
function GetJobCooldown(source)
    for k,v in pairs(JobCooldown) do
        if v.PlyIdentifier == source then
            return math.ceil(v.time/60000)
        end
    end
end
function CheckJobCooldown(source)
    for k,v in pairs(JobCooldown) do
        if v.PlyIdentifier == source then
            return true
        end
    end
    return false
end

QBCore.Commands.Add("carthief", "Car Thief job starter", {}, false, function(source)
    TriggerClientEvent('pip_carthief:client:GetJobFromNPC',source)
end, "admin")