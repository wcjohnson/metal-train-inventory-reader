data:extend({
  {
    type = "item",
    name = "metal-train-inventory-reader",
    place_result="metal-train-inventory-reader",
    icon = "__metal-train-inventory-reader__/graphics/icons/inventory-sensor.png",
    icon_size = 32,
    subgroup = data.raw["item"]["train-stop"].subgroup,
    order = data.raw["item"]["train-stop"].order.."-b",
    stack_size= 50,
  }
})
