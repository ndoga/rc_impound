local ESX = nil

TriggerEvent('esx:getSharedObject', function(obj) ESX = obj end)

ESX.RegisterServerCallback('rc_impound:retrieveImpoundVehicles', function(source, cb, impoundName)
    MySQL.Async.fetchAll(
    'SELECT * FROM impound_vehicles WHERE impoundName = @impoundName',
    {
      ['@impoundName'] = impoundName,
    },
      function(vehicles)
        cb(vehicles)
      end
    )
end)

ESX.RegisterServerCallback('rc_impound:retrieveOwnedImpoundedVehicles', function(source, cb, impoundName)
  local xPlayer = ESX.GetPlayerFromId(source)

  MySQL.Async.fetchAll(
    'SELECT * FROM impound_vehicles WHERE owner = @owner AND impoundName = @impoundName',
    {
      ['@owner'] = xPlayer.identifier,
      ['@impoundName'] = impoundName,
    },
      function(vehicles)
        cb(vehicles)
      end
    )
end)

ESX.RegisterServerCallback('rc_impound:decodeProps', function(source, cb, vehProps)
    local decodedProps = json.decode(vehProps)
    cb(decodedProps)
end)

ESX.RegisterServerCallback('rc_impound:impound', function(source, cb, vehicleProps, fees, reason)
    local xPlayer = ESX.GetPlayerFromId(source)
    local dateString = os.date("%x")

    local xPlayer = ESX.GetPlayerFromId(playerId)

    if xPlayer then
        local allowed = false
        
        print("JOBS NOT ALLOWED")

        for i=1, #Config.AllowedJobs, 1 do
            local job = Config.AllowedJobs[i]

            print("Job name:" , xPlayer.job.name)

            if xPlayer.job.name == job then
                allowed = true
                print("JOBS ALLOWED", job)
                break
            end
        end

        if allowed then

            MySQL.Async.fetchAll('SELECT * FROM `owned_vehicles` WHERE `plate` = @plate', {['@plate'] = vehicleProps.plate}, function(result)
                if #result > 0 then
                    local vehicleData = json.decode(result[1].vehicle)

                    print("Vehicle owner:", xPlayer.identifier)
                    print("Vehicle plate:", vehicleProps.plate)

                    local ownerIdentifier = result[1].owner
                    GetCharName(ownerIdentifier, function(ownerCharname)

                        local vehicleProps = result[1].vehicle
                        GetCharName(officerPlayer.identifier, function(officerCharname)
                            local typeResult, jobResult

                            if Config.useESXAdvancedGarage then
                                typeResult = result[1].type
                                jobResult = result[1].job

                                print("Check job", jobResult )

                            end

                            MySQL.Async.execute(
                                'INSERT INTO impound_vehicles (timeStamp, impoundName, owner, ownerCharname, vehicleModel, vehiclePlate, vehicleProps, officer, officerCharname, cautionAllowed, caution, vehicleType, vehicleJob) VALUES (@timeStamp, @impoundName, @owner, @ownerCharname, @vehicleModel, @vehiclePlate, @vehicleProps, @officer, @officerCharname, @cautionAllowed, @caution, @type, @job)', {
                                ['@timeStamp'] = dateString, 
                                ['@impoundName'] = impoundName, 
                                ['@owner'] = ownerIdentifier, 
                                ['@ownerCharname'] = ownerCharname, 
                                ['@vehicleModel'] = model, 
                                ['@vehiclePlate'] = vehicleProps.plate,
                                ['@vehicleProps'] = vehicleProps, 
                                ['@officer'] = officerPlayer.identifier, 
                                ['@officerCharname'] = officerCharname, 
                                ['@cautionAllowed'] = cautionAllowed, 
                                ['@caution'] = caution, 
                                ['@type'] = typeResult, 
                                ['@job'] = jobResult, 
                            }, function(rowsChanged)
                                if rowsChanged > 0 then
                                    MySQL.Async.execute(
                                        'DELETE FROM owned_vehicles WHERE `plate` = @plate', {
                                            ['@plate'] = string.upper(tostring(plate))
                                    }, function(rowsDeleted)
                                        if rowsDeleted > 0 then
                                            -- Send confirmation to officer and player 
                                            TriggerClientEvent('rc_impound:picturemsg', source, 'CHAR_PROPERTY_TOWING_IMPOUND', Translation[Config.Locale]['vehicle_impounded'] .. plate .. Translation[Config.Locale]['vehicle_impounded2'], Translation[Config.Locale]['impound'], '')
                                            cb(true)
                                        else
                                            cb(false)
                                        end
                                    end)
                                else
                                    cb(false)
                                end
                            end)
                        end)
                    end)
                else
                    cb(false)
                end
            end)
        else
            -- ...
        end
    end
end)

ESX.RegisterServerCallback('rc_impound:checkCanPayCaution', function(source, cb, price)
    local xPlayer = ESX.GetPlayerFromId(source)

    if xPlayer.getMoney() >= price then
        xPlayer.removeMoney(price)

        if Config.giveCautionToSociety then
            TriggerEvent('esx_addonaccount:getSharedAccount', Config.society, function(account)
              account.addMoney(price)
            end)
        end

        cb(true)
    else
        cb(false)
    end

end)

RegisterServerEvent('rc_impound:releaseVehicle')
AddEventHandler('rc_impound:releaseVehicle', function(owner, plate, vehicleProps, vehicleType, vehicleJob)

    if Config.useESXAdvancedGarage then
        MySQL.Async.execute('INSERT INTO owned_vehicles (owner, plate, vehicle, type, job) VALUES (@owner, @plate, @vehicle, @type, @job)', {
            ['@owner']   = owner,
            ['@plate']   = plate,
            ['@vehicle'] = vehicleProps,
            ['@type'] = vehicleType,
            ['@job'] = vehicleJob,
        }, function(res)
        end)
    else
        MySQL.Async.execute('INSERT INTO owned_vehicles (owner, plate, vehicle) VALUES (@owner, @plate, @vehicle)', {
            ['@owner']   = owner,
            ['@plate']   = plate,
            ['@vehicle'] = vehicleProps
        }, function(res)
        end)
    end

    

    MySQL.Async.execute('DELETE FROM impound_vehicles WHERE owner = @owner AND vehiclePlate = @vehiclePlate', {
        ['@owner'] = owner,
        ['@vehiclePlate'] = plate,
    })

end)

RegisterServerEvent('rc_impound:changeCaution')
AddEventHandler('rc_impound:changeCaution', function(owner, plate, newcaution)

    MySQL.Async.execute('UPDATE impound_vehicles SET caution = @newcaution WHERE owner = @owner AND vehiclePlate = @vehiclePlate', {
        ['@newcaution']   = newcaution,
        ['@owner']   = owner,
        ['@vehiclePlate'] = plate
    }, function(res)
    end)

end)

RegisterServerEvent('rc_impound:changeCautionAllowed')
AddEventHandler('rc_impound:changeCautionAllowed', function(owner, plate, newcautionallowed)

    MySQL.Async.execute('UPDATE impound_vehicles SET cautionAllowed = @cautionAllowed WHERE owner = @owner AND vehiclePlate = @vehiclePlate', {
        ['@cautionAllowed']   = newcautionallowed,
        ['@owner']   = owner,
        ['@vehiclePlate'] = plate
    }, function(res)
    end)

end)

function GetCharName(identifier, cb)
  MySQL.Async.fetchAll(
      'SELECT firstname, lastname FROM users WHERE identifier = @identifier',
      {['@identifier'] = identifier},
      function(result)
          if result[1] then
              local firstname = result[1].firstname or 'Unknown'
              local lastname = result[1].lastname or 'Unknown'
              cb(firstname .. ' ' .. lastname)
          else
              cb('Unknown Unknown')
          end
      end
  )
end