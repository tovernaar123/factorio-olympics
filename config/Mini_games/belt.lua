return {
    {
        surface = "Belt_Madness",
        center = {x = 0, y = 0},
        area = {{-25, -25}, {26, 26}},
        level_width = 14, -- the size of the map
        recipes = {"transport-belt", "underground-belt"},
        chests = {
            {
                item = "iron-plate",
                input = 1,
                output = 1
            },
            {
                item = "copper-plate",
                input = 2,
                output = 2
            },
            {
                item = "steel-plate",
                input = 4,
                output = 4
            },
            {
                item = "copper-ore",
                input = 5,
                output = 5
            }
        }
    }
}
