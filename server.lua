ESX = nil
TriggerEvent('esx:getSharedObject', function(obj) ESX = obj end)

ESX.RegisterServerCallback('myImpound:retrieveImpoundVehicles', function(source, cb, impoundName)
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

ESX.RegisterServerCallback('myImpound:retrieveOwnedImpoundedVehicles', function(source, cb, impoundName)
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

ESX.RegisterServerCallback('myImpound:decodeProps', function(source, cb, vehProps)
    local decodedProps = json.decode(vehProps)
    cb(decodedProps)
end)

ESX.RegisterServerCallback('myImpound:impoundVehicle', function(source, cb, impoundName, plate, model, cautionAllowed, caution)
  local officerPlayer = ESX.GetPlayerFromId(source)
  local dateString = os.date("%x")

  MySQL.Async.fetchAll('SELECT * FROM owned_vehicles WHERE `plate` = @plate', {['@plate'] = plate}, function(result)
      if #result > 0 then
          local vehicleData = json.decode(result[1].vehicle)

          if vehicleData.model == model then
              -- vehicle is owned and can be impounded

              local ownerIdentifier = result[1].owner
              GetCharName(ownerIdentifier, function(ownerCharname)
                  local vehicleProps = result[1].vehicle
                  GetCharName(officerPlayer.identifier, function(officerCharname)
                      local typeResult, jobResult

                      if Config.useESXAdvancedGarage then
                          typeResult = result[1].type
                          jobResult = result[1].job
                      end

                      MySQL.Async.execute(
                          'INSERT INTO impound_vehicles (timeStamp, impoundName, owner, ownerCharname, vehicleModel, vehiclePlate, vehicleProps, officer, officerCharname, cautionAllowed, caution, vehicleType, vehicleJob) VALUES (@timeStamp, @impoundName, @owner, @ownerCharname, @vehicleModel, @vehiclePlate, @vehicleProps, @officer, @officerCharname, @cautionAllowed, @caution, @type, @job)', {
                          ['@timeStamp'] = dateString, 
                          ['@impoundName'] = impoundName, 
                          ['@owner'] = ownerIdentifier, 
                          ['@ownerCharname'] = ownerCharname, 
                          ['@vehicleModel'] = model, 
                          ['@vehiclePlate'] = plate, 
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
                                  'DELETE FROM owned_vehicles WHERE `plate` = @plate AND `owner` = @owner', {
                                  ['@plate'] = plate, 
                                  ['@owner'] = ownerIdentifier, 
                              }, function(rowsDeleted)
                                  if rowsDeleted > 0 then
                                      -- Send confirmation to officer and player 
                                      TriggerClientEvent('myImpound:picturemsg', source, 'CHAR_PROPERTY_TOWING_IMPOUND', Translation[Config.Locale]['vehicle_impounded'] .. plate .. Translation[Config.Locale]['vehicle_impounded2'], Translation[Config.Locale]['impound'], '')
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
      else
          cb(false)
      end
  end)
end)

ESX.RegisterServerCallback('myImpound:checkCanPayCaution', function(source, cb, price)
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

RegisterServerEvent('myImpound:releaseVehicle')
AddEventHandler('myImpound:releaseVehicle', function(owner, plate, vehicleProps, vehicleType, vehicleJob)

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

RegisterServerEvent('myImpound:changeCaution')
AddEventHandler('myImpound:changeCaution', function(owner, plate, newcaution)

    MySQL.Async.execute('UPDATE impound_vehicles SET caution = @newcaution WHERE owner = @owner AND vehiclePlate = @vehiclePlate', {
        ['@newcaution']   = newcaution,
        ['@owner']   = owner,
        ['@vehiclePlate'] = plate
    }, function(res)
    end)

end)

RegisterServerEvent('myImpound:changeCautionAllowed')
AddEventHandler('myImpound:changeCautionAllowed', function(owner, plate, newcautionallowed)

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