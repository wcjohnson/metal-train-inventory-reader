data:extend({
  {
    type = "recipe",
    name = "metal-train-inventory-reader",
    icon = "__metal-train-inventory-reader__/graphics/icons/inventory-sensor.png",
    icon_size = 32,
    enabled = true,
    ingredients =
    {
      {type="item", name="copper-cable", amount=5},
      {type="item", name="electronic-circuit", amount= 5},
    },
    results = {{type="item", name="metal-train-inventory-reader", amount=1}},
  }
})
