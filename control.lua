local SENSOR = "metal-train-inventory-reader"
local EVENT_FILTER = {{ filter="name", name=SENSOR }}

local LOCO = "locomotive"
local WAGON = "cargo-wagon"
local WAGONFLUID = "fluid-wagon"
local WAGONARTILLERY = "artillery-wagon"

local SupportedTypes = {
  [LOCO] = false,
  [WAGON] = false,
  [WAGONFLUID] = false,
  [WAGONARTILLERY] = false,
}

local ceil = math.ceil

local UpdateInterval = 10
local ScanInterval = 120
local ScanOffset = 0.2
local ScanRange = 1.5

local _empty = {}


---Clear signals of a constant combinator.
---@param comb LuaEntity A Factorio constant combinator.
local function clear_combinator_output(comb)
  local beh = comb.get_control_behavior() --[[@as LuaConstantCombinatorControlBehavior?]]
  -- If no behavior and/or no sections, combinator already has no output.
  if (not beh) or (beh.sections_count == 0) then return end
  local sec = beh.get_section(1)
  if sec and sec.filters_count > 0 then
    sec.filters = _empty
  end
end

---Update signals of a constant combinator.
---@param comb LuaEntity? A Factorio constant combinator.
---@param signals (LogisticFilter[])? Signals to set. Nil to clear.
local function set_combinator_output(comb, signals)
  if comb and comb.valid then
    if not signals then
      return clear_combinator_output(comb)
    end
    local beh = comb.get_or_create_control_behavior() --[[@as LuaConstantCombinatorControlBehavior]]
    if not beh then return end
    beh.get_section(1).filters = signals or _empty
  end
end

local function set_sensor_output(itemSensor, signals)
  if itemSensor.LogisticSection and itemSensor.LogisticSection.valid then
    itemSensor.LogisticSection.filters = signals or _empty
  elseif itemSensor.Sensor and itemSensor.Sensor.valid then
    local sensor = itemSensor.Sensor
    itemSensor.ControlBehavior = sensor.get_or_create_control_behavior() --[[@as LuaConstantCombinatorControlBehavior]]
    itemSensor.LogisticSection = itemSensor.ControlBehavior.get_section(1)
    itemSensor.LogisticSection.filters = signals or _empty
  end
end

---- EVENTS ----

function OnEntityCreated(event)
  local entity = event.created_entity or event.entity or event.destination --[[@as LuaEntity]]
  if entity and entity.valid and entity.name == SENSOR then
    storage.ItemSensors = storage.ItemSensors or {}

    entity.operable = false
    entity.rotatable = false
    local itemSensor = {}
    itemSensor.ID = entity.unit_number
    itemSensor.Sensor = entity
    itemSensor.ControlBehavior = entity.get_or_create_control_behavior() --[[@as LuaConstantCombinatorControlBehavior]]
    itemSensor.LogisticSection = itemSensor.ControlBehavior.get_section(1)
    itemSensor.ScanArea = GetScanArea(entity)
    SetConnectedEntity(itemSensor)

    storage.ItemSensors[#storage.ItemSensors+1] = itemSensor

    if #storage.ItemSensors > 0 then
      script.on_event( defines.events.on_tick, OnTick )
    end

    ResetStride()
  end
end

-- called from on_entity_removed and when entity becomes invalid
function RemoveSensor(sensorID)
  for i=#storage.ItemSensors, 1, -1 do
    if storage.ItemSensors[i].ID == sensorID then
      table.remove(storage.ItemSensors,i)
    end
  end

  if #storage.ItemSensors == 0 then
    script.on_event( defines.events.on_tick, nil )
  end

  ResetStride()
end

function OnEntityRemoved(event)
  local entity = event.entity
  if entity and entity.valid and entity.name == SENSOR then
    RemoveSensor(entity.unit_number)
  end
end

-- Update all sensors on every tick (Lord)
function OnTick(event)
  for i=1, #storage.ItemSensors do
    local itemSensor = storage.ItemSensors[i]
    if not itemSensor.Sensor.valid then
      RemoveSensor(itemSensor.ID) -- remove invalidated sensors
    else
      if not itemSensor.SkipEntityScanning and (game.tick - itemSensor.LastScanned) >= ScanInterval then
        SetConnectedEntity(itemSensor)
      end
      UpdateSensor(itemSensor)
    end
  end
end


-- grouped stepping by Optera
-- 91307.27ms on 100k ticks
-- function OnTick(event)
--   storage.tickCount = storage.tickCount or 1
--   storage.SensorIndex = storage.SensorIndex or 1

--   -- only work if index is within bounds
--   if storage.SensorIndex <= #storage.ItemSensors then
--     local lastIndex = storage.SensorIndex + storage.SensorStride - 1
--     if lastIndex >= #storage.ItemSensors then
--       lastIndex = #storage.ItemSensors
--     end

--     -- game.print("[IS] "..storage.tickCount.." / "..game.tick.." updating sensors "..storage.SensorIndex.." to "..lastIndex)
--     for i=storage.SensorIndex, lastIndex do
--       local itemSensor = storage.ItemSensors[i]
--       -- game.print("[IS] skipScan: "..tostring(itemSensor.SkipEntityScanning).." LastScan: "..tostring(itemSensor.LastScanned).."/"..game.tick)

--       if not itemSensor.Sensor.valid then
--           RemoveSensor(itemSensor.ID) -- remove invalidated sensors
--       else
--         if not itemSensor.SkipEntityScanning and (game.tick - itemSensor.LastScanned) >= ScanInterval then
--           SetConnectedEntity(itemSensor)
--         end
--         UpdateSensor(itemSensor)
--       end
--     end
--     storage.SensorIndex = lastIndex + 1
--   end

--   -- reset clock and index
--   if storage.tickCount < UpdateInterval then
--     storage.tickCount = storage.tickCount + 1
--   else
--     storage.tickCount = 1
--     storage.SensorIndex = 1
--   end
-- end

-- stepping from tick modulo with stride by eradicator
-- 93048.58ms on 100k ticks: 1.9% slower than grouped stepping
-- function OnTick(event)
  -- local offset = event.tick % UpdateInterval
  -- for i=#storage.ItemSensors - offset, 1, -1 * UpdateInterval do
    -- local itemSensor = storage.ItemSensors[i]
    -- if not itemSensor.SkipEntityScanning and (event.tick - itemSensor.LastScanned) >= ScanInterval then
      -- SetConnectedEntity(itemSensor)
    -- end
    -- UpdateSensor(itemSensor)
  -- end
-- end

---- LOGIC ----

-- recalculates how many sensors are updated each tick
function ResetStride()
  if #storage.ItemSensors > UpdateInterval then
    storage.SensorStride =  ceil(#storage.ItemSensors/UpdateInterval)
  else
    storage.SensorStride = 1
  end
  -- log("[IS] stride set to "..storage.SensorStride)
end


function ResetSensors()
  storage.ItemSensors = storage.ItemSensors or {}
  for i=1, #storage.ItemSensors do
    local itemSensor = storage.ItemSensors[i]
    itemSensor.ID = itemSensor.Sensor.unit_number
    itemSensor.ScanArea = GetScanArea(itemSensor.Sensor)
    itemSensor.ConnectedEntity = nil
    itemSensor.Inventory = {}
    SetConnectedEntity(itemSensor)
  end
end

---@param sensor LuaEntity
---@return BoundingBox
function GetScanArea(sensor)
  if sensor.direction == defines.direction.south then --south
    return{{sensor.position.x - ScanOffset, sensor.position.y}, {sensor.position.x + ScanOffset, sensor.position.y + ScanRange}}
  elseif sensor.direction == defines.direction.west then --west
    return{{sensor.position.x - ScanRange, sensor.position.y - ScanOffset}, {sensor.position.x, sensor.position.y + ScanOffset}}
  elseif sensor.direction == defines.direction.north then --north
    return{{sensor.position.x - ScanOffset, sensor.position.y - ScanRange}, {sensor.position.x + ScanOffset, sensor.position.y}}
  elseif sensor.direction == defines.direction.east then --east
    return{{sensor.position.x, sensor.position.y - ScanOffset}, {sensor.position.x + ScanRange, sensor.position.y + ScanOffset}}
  else
    -- Should be impossible, pretend its facing north!
    return{{sensor.position.x - ScanOffset, sensor.position.y - ScanRange}, {sensor.position.x + ScanOffset, sensor.position.y}}
  end
end

-- cache inventories, keep inventory index
function SetInventories(itemSensor, entity)
  itemSensor.Inventory = {}
  local inv = nil
  for i=1, 8 do -- iterate blindly over every possible inventory and store the result so we have to do it only once
    inv = entity.get_inventory(i)
    if inv then
      itemSensor.Inventory[i] = inv
    end
  end
end

function SetConnectedEntity(itemSensor)
  itemSensor.LastScanned = game.tick
  local surface = itemSensor.Sensor.surface --[[@as LuaSurface]]
  local connectedEntities = surface.find_entities(itemSensor.ScanArea)
  -- game.print("DEBUG: Found "..#connectedEntities.." entities in direction "..itemSensor.Sensor.direction)
  if connectedEntities then
    for i=1, #connectedEntities do
      local entity = connectedEntities[i]
      if entity.valid and SupportedTypes[entity.type] ~= nil then
        -- game.print("DEBUG: Sensor "..itemSensor.Sensor.unit_number.." found entity "..tostring(entity.type).." "..tostring(entity.name))
        if itemSensor.ConnectedEntity ~= entity then
          SetInventories(itemSensor, entity)
        end
        itemSensor.ConnectedEntity = entity
        itemSensor.SkipEntityScanning = SupportedTypes[entity.type]
        return
      end
    end
  end
  -- if no entity was found remove stored data
  -- game.print("DEBUG: Sensor "..itemSensor.Sensor.unit_number.." no entity found")
  itemSensor.ConnectedEntity = nil
  itemSensor.SkipEntityScanning = false
  if (not itemSensor.Inventory) or next(itemSensor.Inventory) then
    itemSensor.Inventory = {}
  end
end


function UpdateSensor(itemSensor)
  local sensor = itemSensor.Sensor
  local connectedEntity = itemSensor.ConnectedEntity --[[@as LuaEntity?]]

  -- clear output of invalid connections
  if not connectedEntity or not connectedEntity.valid or not itemSensor.Inventory then
    itemSensor.ConnectedEntity = nil
    if (not itemSensor.Inventory) or next(itemSensor.Inventory) then
      itemSensor.Inventory = {}
    end
    itemSensor.SkipEntityScanning = false
    -- set_combinator_output(sensor, nil)
    set_sensor_output(itemSensor, nil)
    return
  end

  ---@type LogisticFilter[]
  local signals = {}
  local signalIndex = 1

  -- Vehicle signals and movement detection
  if connectedEntity.type == LOCO then
    if connectedEntity.train.state == defines.train_state.wait_station
    or connectedEntity.train.state == defines.train_state.wait_signal
    or connectedEntity.train.state == defines.train_state.manual_control then --keeps showing inventory for ScanInterval ticks after movement start > neglect able
    else -- train is moving > remove connection
      itemSensor.ConnectedEntity = nil
      itemSensor.Inventory = {}
      itemSensor.SkipEntityScanning = false
      -- set_combinator_output(sensor, nil)
      set_sensor_output(itemSensor, nil)
      return
    end

  elseif connectedEntity.type == WAGON or connectedEntity.type == WAGONFLUID or connectedEntity.type == WAGONARTILLERY then
    if connectedEntity.train.state == defines.train_state.wait_station
    or connectedEntity.train.state == defines.train_state.wait_signal
    or connectedEntity.train.state == defines.train_state.manual_control then --keeps showing inventory for ScanInterval ticks after movement start > neglect able
    else -- train is moving > remove connection
      itemSensor.ConnectedEntity = nil
      itemSensor.Inventory = {}
      itemSensor.SkipEntityScanning = false
      -- set_combinator_output(sensor, nil)
      set_sensor_output(itemSensor, nil)
      return
    end

  end

  -- get all fluids
  if connectedEntity.fluids_count > 0 then
    local fluidContents = connectedEntity.get_fluid_contents()
    for fluidName, fluidAmount in pairs(fluidContents) do
      signals[signalIndex] = {
        value = {
          type = "fluid",
          name = fluidName,
          quality = "normal",
          comparator = "=",
        },
        min = ceil(fluidAmount),
      }
      signalIndex = signalIndex+1
    end
  end

  -- get items in all inventories
  for inv_index, inv in pairs(itemSensor.Inventory) do
    local typed_inv = inv --[[@as LuaInventory]]
    local contentsTable = typed_inv.get_contents()
    for k,v in pairs(contentsTable) do
      signals[signalIndex] = {
        value = {type = "item", name = v.name, quality = v.quality, comparator = "=" },
        min = v.count,
      }
      signalIndex = signalIndex+1
    end
  end

  -- set_combinator_output(sensor, signals)
  set_sensor_output(itemSensor, signals)
end

---- INIT ----
do

local function init_events()
  script.on_event( defines.events.on_built_entity, OnEntityCreated, EVENT_FILTER )
  script.on_event( defines.events.on_robot_built_entity, OnEntityCreated, EVENT_FILTER )
  script.on_event( defines.events.on_entity_cloned, OnEntityCreated, EVENT_FILTER )
  script.on_event( {defines.events.script_raised_built, defines.events.script_raised_revive}, OnEntityCreated )

  script.on_event( defines.events.on_pre_player_mined_item, OnEntityRemoved, EVENT_FILTER )
  script.on_event( defines.events.on_robot_pre_mined, OnEntityRemoved, EVENT_FILTER )
  script.on_event( defines.events.on_entity_died, OnEntityRemoved, EVENT_FILTER )
  script.on_event( defines.events.script_raised_destroy, OnEntityRemoved )

  if storage.ItemSensors and #storage.ItemSensors > 0 then
    script.on_event( defines.events.on_tick, OnTick )
  end
end

script.on_load(function()
  init_events()
end)

script.on_init(function()
  storage.ItemSensors = storage.ItemSensors or {}
  ResetStride()
  init_events()
end)

script.on_configuration_changed(function(data)
  ResetSensors()
  ResetStride()
  init_events()
end)

end
