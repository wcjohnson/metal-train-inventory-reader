local reader_entity = table.deepcopy(data.raw["constant-combinator"]["constant-combinator"])
reader_entity.name = "metal-train-inventory-reader"
reader_entity.icon = "__metal-train-inventory-reader__/graphics/icons/inventory-sensor.png"
reader_entity.icon_size = 32
reader_entity.icon_mipmaps = nil
reader_entity.minable.result = "metal-train-inventory-reader"
reader_entity.sprites = make_4way_animation_from_spritesheet(
  { layers =
    {
      {
        filename = "__metal-train-inventory-reader__/graphics/entity/inventory-sensor.png",
        width = 58,
        height = 52,
        frame_count = 1,
        shift = util.by_pixel(0, 5),
        hr_version =
        {
          scale = 0.5,
          filename = "__metal-train-inventory-reader__/graphics/entity/hr-inventory-sensor.png",
          width = 114,
          height = 102,
          frame_count = 1,
          shift = util.by_pixel(0, 5),
        },
      },
      {
        filename = "__base__/graphics/entity/combinator/constant-combinator-shadow.png",
        width = 50,
        height = 34,
        frame_count = 1,
        shift = util.by_pixel(9, 6),
        draw_as_shadow = true,
        hr_version =
        {
          scale = 0.5,
          filename = "__base__/graphics/entity/combinator/hr-constant-combinator-shadow.png",
          width = 98,
          height = 66,
          frame_count = 1,
          shift = util.by_pixel(8.5, 5.5),
          draw_as_shadow = true,
        },
      },
    },
  })

reader_entity.item_slot_count = 1000


data:extend({ reader_entity })
