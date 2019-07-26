fcEmptyAnimations = {--luacheck: allow defined top
    filename = "__TheFatController__/graphics/trans1.png",
    priority = "medium",
    width = 1,
    height = 1,
    direction_count = 18,
    frame_count = 1,
    animation_speed = 0.15,
    shift = {0.0, 0.0},
    axially_symmetrical = true
}

fcEmptyLevel = {--luacheck: allow defined top
    idle = fcEmptyAnimations,
    idle_with_gun = fcEmptyAnimations,
    running = fcEmptyAnimations,
    running_with_gun = fcEmptyAnimations,
    mining_with_tool = fcEmptyAnimations,
}

fcanimations = {--luacheck: ignore
    level1 = fcEmptyLevel,
    level2addon = nil,
    level3addon = nil
}
