local FX = require("arena_fx")
FX.load()
local arenaWidth = 960
local levelWidth = 3600
local flagX = levelWidth - 150
local floorY = 460
local gravity = 1500
local jumpSpeed = 600
local maxHealth = 100
local fighterWidth = 38
local standingHeight = 76
local crouchingHeight = 44
local blockDamageScale = 0.20
local blockKnockbackScale = 0.25
local roundDuration = 120
local roundEndDelay = 2
local winnerScreenDuration = 3
local roundsToWin = 2
local hitStopDuration = 0.06
local hitFlashDuration = 0.12
local comboTimeout = 1.5
local fighter1StartX = 260
local fighter2StartX = 700
local cameraX = 0
local cameraCenterX = arenaWidth / 2
local cameraZoom = 1
local screenShakeTimer = 0
local screenShakeStrength = 0
local screenFlashTimer = 0
local superBannerTimer = 0
local superBannerText = ""
local mountDistance = 72
local riderOffset = 34
local cpuEnabled = true
local cpuDifficulty = "normal"
local uiFont = love.graphics.newFont(12)
local timerFont = love.graphics.newFont(28)
local resultFont = love.graphics.newFont(38)
local titleFont = love.graphics.newFont(46)
local characterFont = love.graphics.newFont(24)
local controllerQrImage
local controllerQrCheckTimer = 0
local controllerQrFileData
local controllerQrUrl = "Start controller_server.py"

local characters = {
    {
        name = "EMBER", title = "THE FIREBRAND",
        color = { 0.94, 0.28, 0.18 }, accent = { 1.00, 0.72, 0.20 },
        health = 95, speed = 315, power = 1.08, jump = 1.04,
        affinity = "HORSE",
        description = "Fast, fearless, and built for pressure.",
    },
    {
        name = "TEMPEST", title = "THE SKY DANCER",
        color = { 0.22, 0.68, 0.96 }, accent = { 0.58, 0.92, 1.00 },
        health = 90, speed = 325, power = 0.96, jump = 1.16,
        affinity = "HORSE",
        description = "Lightning movement and unmatched jumps.",
    },
    {
        name = "WARDEN", title = "THE IRON WALL",
        color = { 0.50, 0.58, 0.70 }, accent = { 0.88, 0.92, 1.00 },
        health = 120, speed = 245, power = 1.12, jump = 0.92,
        affinity = "BOAR",
        description = "Heavy armor, crushing blows, steady feet.",
    },
    {
        name = "VIPER", title = "THE NIGHT HUNTER",
        color = { 0.50, 0.88, 0.35 }, accent = { 0.78, 1.00, 0.48 },
        health = 100, speed = 290, power = 1.04, jump = 1.08,
        affinity = "BOAR",
        description = "Balanced, elusive, and hard to predict.",
    },
}

local attacks = {
    high = { startup = 0.05, active = 0.09, recovery = 0.24, range = 64,
        height = 16, damage = 19, knockback = 16, yOffset = 60,
        lane = "HIGH", limb = "arm" },
    mid = { startup = 0.10, active = 0.13, recovery = 0.31, range = 76,
        height = 22, damage = 27, knockback = 25, yOffset = 39,
        lane = "MID", limb = "arm" },
    low = { startup = 0.15, active = 0.16, recovery = 0.40, range = 86,
        height = 18, damage = 31, knockback = 29, yOffset = 9,
        lane = "LOW", limb = "leg" },
}

local specialMoves = {
    { name = "WEB SWING", cooldown = 7.0, duration = 0.72 },
    { name = "TELEPORT", cooldown = 8.0, duration = 0.32 },
    { name = "SPIDER FLIGHT", cooldown = 12.0, duration = 0.32, flight = 3.0 },
    { name = "TIME STOP", cooldown = 20.0, duration = 0.42, freeze = 3.0 },
}

local function triggerSuperFeedback(index)
    screenShakeTimer = 0.38
    screenShakeStrength = index == 4 and 13 or 8
    screenFlashTimer = 0.24
    superBannerTimer = 0.9
    superBannerText = specialMoves[index].name .. "!"
end

local cpuProfiles = {
    easy = {
        reactionMin = 0.70, reactionMax = 1.00,
        attackChance = 0.48, blockChance = 0.12, jumpChance = 0.04,
        attackCooldownMin = 1.5, attackCooldownMax = 2.0,
    },
    normal = {
        reactionMin = 0.30, reactionMax = 0.52,
        attackChance = 0.65, blockChance = 0.16, jumpChance = 0.08,
        attackCooldownMin = 1.1, attackCooldownMax = 1.45,
    },
    hard = {
        reactionMin = 0.14, reactionMax = 0.28,
        attackChance = 0.88, blockChance = 0.20, jumpChance = 0.12,
        attackCooldownMin = 0.48, attackCooldownMax = 0.72,
    },
}

local cpu = {
    decisionTimer = 0.35,
    attackCooldown = 0,
    blockTimer = 0,
    jumpCooldown = 0,
}

local pits = {
    { left = 1160, right = 1310 },
    { left = 1980, right = 2160 },
    { left = 2860, right = 3030 },
}

local platforms = {
    { x = 1030, y = 365, width = 150, height = 18 },
    { x = 1260, y = 335, width = 145, height = 18, moving = true,
        startX = 1260, range = 130, speed = 1.35, phase = 0 },
    { x = 1740, y = 345, width = 180, height = 18 },
    { x = 2020, y = 305, width = 150, height = 18, moving = true,
        startX = 2020, range = 105, speed = 1.55, phase = 1.7 },
    { x = 2570, y = 350, width = 165, height = 18 },
    { x = 2900, y = 320, width = 165, height = 18, moving = true,
        startX = 2900, range = 120, speed = 1.25, phase = 3.1 },
}

local spikes = {
    { x = 720, width = 80 }, { x = 1490, width = 90 },
    { x = 2440, width = 90 }, { x = 3230, width = 75 },
}

local function isOverPit(x)
    for _, pit in ipairs(pits) do
        if x > pit.left and x < pit.right then
            return true
        end
    end
    return false
end

local function platformAtFoot(x, y)
    for _, platform in ipairs(platforms) do
        if x >= platform.x - 12 and x <= platform.x + platform.width + 12
            and math.abs(y - platform.y) < 5 then
            return platform
        end
    end
    return nil
end

local loseLife
local spawnFireball
local fireballs = {}
local fighter1, fighter2

local Fighter = {}
Fighter.__index = Fighter

function Fighter.new(x, color, controls)
    return setmetatable({
        startX = x,
        x = x,
        y = floorY,
        velocityY = 0,
        speed = 280,
        power = 1,
        jumpScale = 1,
        character = nil,
        grounded = true,
        health = maxHealth,
        maxHealth = maxHealth,
        facing = 1,
        color = color,
        controls = controls,
        state = "idle",
        blocking = false,
        crouching = false,
        attack = nil,
        recovery = 0,
        hitFlash = 0,
        combo = 0,
        comboTimer = 0,
        ko = false,
        mount = nil,
        special = nil,
        specialCooldowns = { 0, 0, 0, 0 },
        flightTimer = 0,
        timeStopTimer = 0,
        mushroomTimer = 0,
        shieldHealth = 0,
        fireTimer = 0,
        fireballCooldown = 0,
        bootsTimer = 0,
        bondCharmTimer = 0,
        stunTimer = 0,
        invulnerableTimer = 0,
        platform = nil,
        comebackBoost = 1,
    }, Fighter)
end

function Fighter:reset()
    if self.mount then
        self.mount.rider = nil
        self.mount = nil
    end
    self.x = self.startX
    self.y = floorY
    self.velocityY = 0
    self.grounded = true
    self.health = self.maxHealth
    self.facing = self.startX < arenaWidth / 2 and 1 or -1
    self.state = "idle"
    self.blocking = false
    self.crouching = false
    self.attack = nil
    self.recovery = 0
    self.hitFlash = 0
    self.combo = 0
    self.comboTimer = 0
    self.ko = false
    self.special = nil
    self.specialCooldowns = { 0, 0, 0, 0 }
    self.flightTimer = 0
    self.timeStopTimer = 0
    self.mushroomTimer = 0
    self.shieldHealth = 0
    self.fireTimer = 0
    self.fireballCooldown = 0
    self.bootsTimer = 0
    self.bondCharmTimer = 0
    self.stunTimer = 0
    self.invulnerableTimer = 0
    self.platform = nil
    self.comebackBoost = 1
end

function Fighter:takeDamage(amount, knockback, attacker, bypassBlock)
    if self.ko or self.invulnerableTimer > 0 then
        return
    end

    local blocking = self.blocking and not bypassBlock
    local damageScale = blocking and blockDamageScale or 1
    if self.mushroomTimer > 0 then
        damageScale = damageScale * 0.80
    end
    local knockbackScale = blocking and blockKnockbackScale or 1
    local damage = math.max(1, math.floor(amount * damageScale + 0.5))
    if self.shieldHealth > 0 then
        local absorbed = math.min(self.shieldHealth, damage)
        self.shieldHealth = self.shieldHealth - absorbed
        damage = damage - absorbed
        self.hitFlash = hitFlashDuration
        if damage <= 0 then
            return
        end
    end
    FX.hit(self,damage,blocking)
    self.health = math.max(0, self.health - damage)
    if self.health == 0 then
        FX.sound("ko")
        self.ko = true
        self.attack = nil
        self.special = nil
        self.recovery = 0
        self.blocking = false
        if self.mount then
            self.mount.rider = nil
            self.mount.x = self.x
            self.mount.bonded = false
            self.mount.mood = "STARTLED"
            self.mount = nil
        end
        return
    end

    self.x = math.max(fighterWidth / 2,
        math.min(levelWidth - fighterWidth / 2,
            self.x + attacker.facing * knockback * knockbackScale))
end

function Fighter:isDown(control)
    if self.aiInput then
        return self.aiInput[control] == true
    end
    if self.phoneInput and self.phoneInput[control] then
        return true
    end
    return love.keyboard.isDown(self.controls[control])
end

function Fighter:jump()
    if not self.ko and self.stunTimer <= 0 and self.grounded then
        local mountJump = self.mount and self.mount.jumpBoost or 1
        if self.mount and self.mount.bonded then
            mountJump = mountJump + 0.08
        end
        FX.sound("jump")
        self.velocityY = -jumpSpeed * self.jumpScale * mountJump
        self.grounded = false
    end
end

function Fighter:startAttack(kind)
    if self.ko or self.stunTimer > 0 or self.blocking or self:isDown("block")
        or self.attack or self.special or self.recovery > 0 then
        return
    end

    FX.sound("whoosh")
    local settings = attacks[kind]
    local sizeScale = self.mushroomTimer > 0 and 1.35 or 1
    self.attack = {
        kind = kind,
        phase = "startup",
        timer = settings.startup,
        hitOpponent = false,
        hitbox = { x = 0, y = 0, width = settings.range * sizeScale,
            height = settings.height * sizeScale },
    }
    if kind == "high" and self.fireTimer > 0 and self.fireballCooldown <= 0
        and spawnFireball then
        spawnFireball(self)
        self.fireballCooldown = 0.65
    end
end

function Fighter:startSpecial(index)
    if self.ko or self.stunTimer > 0 or self.attack or self.special or self.blocking
        or self.recovery > 0 or self.specialCooldowns[index] > 0 then
        return false
    end
    local move = specialMoves[index]
    if not move then return false end
    self.special = {
        index = index,
        name = move.name,
        timer = move.duration,
        duration = move.duration,
        hit = false,
        startX = self.x,
        startY = self.y,
        startGrounded = self.grounded,
        startPlatform = self.platform,
        anchorX = self.x + self.facing * 270,
        targetX = self.x + self.facing * 270,
    }
    self.specialCooldowns[index] = move.cooldown
    if move.flight then
        self.flightTimer = move.flight
        self.grounded = false
        self.velocityY = 0
    end
    if move.freeze then
        local opponent = self == fighter1 and fighter2 or fighter1
        opponent.timeStopTimer = move.freeze
        opponent.stunTimer = math.max(opponent.stunTimer, move.freeze)
        opponent.attack = nil
        opponent.special = nil
        opponent.blocking = false
    end
    self.blocking = false
    FX.special(self,index)
    triggerSuperFeedback(index)
    return true
end

function Fighter:update(dt)
    self.hitFlash = math.max(0, self.hitFlash - dt)
    self.comboTimer = math.max(0, self.comboTimer - dt)
    for i = 1, #specialMoves do
        self.specialCooldowns[i] = math.max(0, self.specialCooldowns[i] - dt)
    end
    self.mushroomTimer = math.max(0, self.mushroomTimer - dt)
    self.fireTimer = math.max(0, self.fireTimer - dt)
    self.fireballCooldown = math.max(0, self.fireballCooldown - dt)
    self.bootsTimer = math.max(0, self.bootsTimer - dt)
    self.bondCharmTimer = math.max(0, self.bondCharmTimer - dt)
    self.stunTimer = math.max(0, self.stunTimer - dt)
    self.flightTimer = math.max(0, self.flightTimer - dt)
    self.timeStopTimer = math.max(0, self.timeStopTimer - dt)
    self.invulnerableTimer = math.max(0, self.invulnerableTimer - dt)
    if self.comboTimer == 0 then
        self.combo = 0
    end
    if self.ko then
        self.state = "ko"
        return
    end
    if self.timeStopTimer > 0 then
        self.blocking = false
        self.state = "time_stopped"
        return
    end
    if self.stunTimer > 0 then
        self.state = "stunned"
        self.blocking = false
    end

    if self.platform then
        self.x = self.x + (self.platform.dx or 0)
    end
    if self.grounded then
        local support = platformAtFoot(self.x, self.y)
        if self.y == floorY and not isOverPit(self.x) then
            self.platform = nil
        elseif support then
            self.platform = support
        else
            self.grounded = false
            self.platform = nil
        end
    end

    local canControl = self.stunTimer <= 0
    self.blocking = canControl and not self.attack and not self.special
        and self:isDown("block")
    local direction = 0
    if canControl and self:isDown("left") then
        direction = direction - 1
    end
    if canControl and self:isDown("right") then
        direction = direction + 1
    end
    local speedMultiplier = self.mount and self.mount.speedBoost or 1
    if self.mount and self.mount.bonded then
        speedMultiplier = speedMultiplier + 0.12
    end
    if self.bootsTimer > 0 then
        speedMultiplier = speedMultiplier * 1.35
    end
    speedMultiplier = speedMultiplier * self.comebackBoost
    self.x = math.max(fighterWidth / 2,
        math.min(levelWidth - fighterWidth / 2,
            self.x + direction * self.speed * speedMultiplier * dt))
    if self.mount then
        self.mount.x = self.x
        self.mount.y = self.y
        self.mount.facing = self.facing
    end

    if self.special and self.special.index == 1 then
        self.grounded = false
        self.velocityY = 0
    elseif self.flightTimer > 0 then
        self.grounded = false
        self.platform = nil
        self.velocityY = 0
        local vertical = (self:isDown("crouch") and 1 or 0)
            - (self:isDown("jump") and 1 or 0)
        self.y = math.max(floorY - 230,
            math.min(floorY - 90, self.y + vertical * 190 * dt))
    elseif not self.grounded then
        local previousY = self.y
        self.velocityY = self.velocityY + gravity * dt
        self.y = self.y + self.velocityY * dt
        local landedPlatform = nil
        if self.velocityY >= 0 then
            for _, platform in ipairs(platforms) do
                if self.x >= platform.x - 12
                    and self.x <= platform.x + platform.width + 12
                    and previousY <= platform.y and self.y >= platform.y then
                    landedPlatform = platform
                    break
                end
            end
        end
        if landedPlatform then
            self.y = landedPlatform.y
            self.velocityY = 0
            self.grounded = true
            self.platform = landedPlatform
        elseif self.y >= floorY and not isOverPit(self.x) then
            self.y = floorY
            self.velocityY = 0
            self.grounded = true
            self.platform = nil
        elseif self.y > floorY + 220 and loseLife then
            loseLife(self, "FELL")
            return
        end
    end

    self.crouching = self.grounded and self:isDown("crouch")
    self.recovery = math.max(0, self.recovery - dt)
end

function Fighter:updateState()
    if self.ko then
        self.state = "ko"
    elseif self.timeStopTimer > 0 then
        self.state = "time_stopped"
    elseif self.stunTimer > 0 then
        self.state = "stunned"
    elseif self.special then
        self.state = string.lower(self.special.name):gsub(" ", "_")
    elseif self.attack then
        self.state = attacks[self.attack.kind].lane:lower() .. "_attack"
    elseif self.blocking then
        self.state = "blocking"
    elseif not self.grounded then
        self.state = "jumping"
    elseif self.crouching then
        self.state = "crouching"
    elseif self:isDown("left") or self:isDown("right") then
        self.state = "walking"
    else
        self.state = "idle"
    end
end

fighter1 = Fighter.new(fighter1StartX, { 0.42, 0.72, 0.88 }, {
    left = "a", right = "d", jump = "w", crouch = "s",
    high = "j", mid = "k", low = "h", block = "l",
    special1 = "u", special2 = "i", special3 = "o", special4 = "p",
})
fighter2 = Fighter.new(fighter2StartX, { 0.88, 0.38, 0.25 }, {
    left = "left", right = "right", jump = "up", crouch = "down",
    high = "n", mid = "m", low = ",", block = "b",
    special1 = "1", special2 = "2", special3 = "3", special4 = "4",
})

local fighters = { fighter1, fighter2 }
local selectedCharacter = { 1, 2 }
local selectionReady = { false, false }
local menuPulse = 0

local function applyCharacter(fighter, characterIndex)
    local character = characters[characterIndex]
    fighter.character = character
    fighter.color = character.color
    fighter.speed = character.speed
    fighter.power = character.power
    fighter.jumpScale = character.jump
    fighter.maxHealth = character.health
    fighter.health = character.health
end

local animals = {
    {
        kind = "HORSE", x = 200, startX = 200, y = floorY,
        color = { 0.58, 0.34, 0.17 }, mane = { 0.18, 0.11, 0.08 },
        speedBoost = 1.45, jumpBoost = 1.18, rider = nil, facing = 1,
        mood = "CURIOUS", bob = 0, bondTimer = 0, bonded = false,
    },
    {
        kind = "BOAR", x = 760, startX = 760, y = floorY,
        color = { 0.42, 0.30, 0.24 }, mane = { 0.20, 0.16, 0.14 },
        speedBoost = 1.25, jumpBoost = 1.08, rider = nil, facing = -1,
        mood = "GRUMPY", bob = 0, bondTimer = 0, bonded = false,
    },
}

local levelBlocks = {
    { x = 840, y = 278, powerType = "MUSHROOM" },
    { x = 900, y = 222, powerType = "SHIELD" },
    { x = 960, y = 278, powerType = "FIRE" },
    { x = 1580, y = 260, powerType = "BOOTS" },
    { x = 1640, y = 204, powerType = "BOND" },
    { x = 2260, y = 278, powerType = "LIGHTNING" },
    { x = 2320, y = 222, powerType = "SHIELD" },
    { x = 2380, y = 278, powerType = "FIRE" },
    { x = 2920, y = 250, powerType = "MUSHROOM" },
}
local mushrooms = {}

local function resetPowerUps()
    mushrooms = {}
    for _, block in ipairs(levelBlocks) do
        block.hit = false
        block.bump = 0
    end
end

local function spawnPowerUp(block, fighter)
    block.hit = true
    block.bump = 0.22
    table.insert(mushrooms, {
        kind = block.powerType,
        x = block.x + 23,
        y = block.y - 10,
        velocityY = -120,
        direction = fighter.facing,
        collected = false,
    })
end

local function updatePowerUps(dt)
    for _, block in ipairs(levelBlocks) do
        block.bump = math.max(0, (block.bump or 0) - dt)
        if not block.hit then
            for _, fighter in ipairs(fighters) do
                local scale = fighter.mushroomTimer > 0 and 1.35 or 1
                local headY = fighter.y - (fighter.mount and riderOffset or 0)
                    - standingHeight * scale - 22 * scale
                if fighter.velocityY < 0
                    and math.abs(fighter.x - (block.x + 23)) < 38
                    and headY <= block.y + 54 and headY >= block.y + 18 then
                    spawnPowerUp(block, fighter)
                    fighter.velocityY = math.max(80, -fighter.velocityY * 0.25)
                    break
                end
            end
        end
    end

    for _, mushroom in ipairs(mushrooms) do
        if not mushroom.collected then
            mushroom.velocityY = mushroom.velocityY + gravity * dt
            mushroom.y = mushroom.y + mushroom.velocityY * dt
            if mushroom.y >= floorY - 18 then
                mushroom.y = floorY - 18
                mushroom.velocityY = 0
                mushroom.x = mushroom.x + mushroom.direction * 72 * dt
            end
            mushroom.x = math.max(20, math.min(levelWidth - 20, mushroom.x))

            for _, fighter in ipairs(fighters) do
                if not fighter.ko and math.abs(fighter.x - mushroom.x) < 34
                    and math.abs(fighter.y - mushroom.y) < 70 then
                    mushroom.collected = true
                    FX.sound("pickup")
                    if mushroom.kind == "MUSHROOM" then
                        fighter.mushroomTimer = 14
                        fighter.health = math.min(fighter.maxHealth, fighter.health + 25)
                    elseif mushroom.kind == "SHIELD" then
                        fighter.shieldHealth = 40
                    elseif mushroom.kind == "FIRE" then
                        fighter.fireTimer = 14
                    elseif mushroom.kind == "BOOTS" then
                        fighter.bootsTimer = 12
                    elseif mushroom.kind == "BOND" then
                        fighter.bondCharmTimer = 16
                        if fighter.mount then
                            fighter.mount.bonded = true
                            fighter.mount.bondTimer = 2.4
                        end
                    elseif mushroom.kind == "LIGHTNING" then
                        local opponent = fighter == fighter1 and fighter2 or fighter1
                        opponent.stunTimer = math.max(opponent.stunTimer, 1.5)
                        opponent.attack = nil
                        opponent.special = nil
                    end
                    fighter.hitFlash = 0.35
                    break
                end
            end
        end
    end
end

local function resetAnimals()
    for _, animal in ipairs(animals) do
        animal.x = animal.startX
        animal.y = floorY
        animal.rider = nil
        animal.bonded = false
        animal.bondTimer = 0
        animal.mood = animal.kind == "HORSE" and "CURIOUS" or "GRUMPY"
        animal.facing = animal.startX < arenaWidth / 2 and 1 or -1
    end
end

local function toggleMount(fighter)
    if fighter.ko or not fighter.grounded or fighter.attack then
        return false
    end
    if fighter.mount then
        fighter.mount.rider = nil
        fighter.mount.bonded = false
        fighter.mount.mood = "WAITING"
        fighter.mount.x = math.max(45, math.min(levelWidth - 45,
            fighter.x - fighter.facing * 52))
        fighter.mount.y = floorY
        fighter.mount = nil
        return true
    end

    local closest = nil
    local closestDistance = mountDistance + 1
    for _, animal in ipairs(animals) do
        local distance = math.abs(fighter.x - animal.x)
        if not animal.rider and distance <= mountDistance and distance < closestDistance then
            closest = animal
            closestDistance = distance
        end
    end
    if closest then
        fighter.mount = closest
        closest.rider = fighter
        closest.bonded = fighter.bondCharmTimer > 0
            or (fighter.character and fighter.character.affinity == closest.kind)
        closest.bondTimer = closest.bonded and 2.4 or 0.8
        closest.mood = closest.bonded and "BONDED!" or "READY"
        closest.x = fighter.x
        closest.y = fighter.y
        closest.facing = fighter.facing
        return true
    end
    return false
end

local function updateAnimals(dt)
    for _, animal in ipairs(animals) do
        animal.bob = animal.bob + dt * (animal.rider and 8 or 2.5)
        animal.bondTimer = math.max(0, animal.bondTimer - dt)
        if animal.rider then
            animal.x = animal.rider.x
            animal.y = animal.rider.y
            animal.facing = animal.rider.facing
        else
            local nearest = nil
            local nearestDistance = math.huge
            for _, fighter in ipairs(fighters) do
                if not fighter.ko then
                    local distance = math.abs(fighter.x - animal.x)
                    if distance < nearestDistance then
                        nearest = fighter
                        nearestDistance = distance
                    end
                end
            end

            if nearest and nearestDistance < 150 then
                local direction = nearest.x > animal.x and 1 or -1
                animal.facing = direction
                if nearest.mount then
                    animal.mood = "STARTLED"
                    animal.x = animal.x - direction * 42 * dt
                elseif nearest.character
                    and nearest.character.affinity == animal.kind then
                    animal.mood = "FRIENDLY"
                    if nearestDistance > 62 then
                        animal.x = animal.x + direction * 24 * dt
                    end
                else
                    animal.mood = animal.kind == "HORSE" and "CURIOUS" or "WATCHING"
                end
            end
            animal.x = math.max(48, math.min(levelWidth - 48, animal.x))
            animal.y = floorY
        end
    end

    local first = animals[1]
    local second = animals[2]
    if not first.rider and not second.rider then
        local distance = second.x - first.x
        if math.abs(distance) < 105 then
            local direction = distance >= 0 and 1 or -1
            local push = (105 - math.abs(distance)) * 0.5
            first.x = first.x - direction * push
            second.x = second.x + direction * push
            first.facing = direction
            second.facing = -direction
            first.mood = "SNIFFING"
            second.mood = "SNIFFING"
        end
    end
end

local game = {
    state = "character_select",
    timeRemaining = roundDuration,
    hitStopTimer = 0,
    round = 1,
    score1 = 0,
    score2 = 0,
    result = "",
    transitionTimer = 0,
    lives = { 3, 3 },
}

local function resetPlatforms()
    for _, platform in ipairs(platforms) do
        if platform.moving then
            platform.x = platform.startX
        end
        platform.dx = 0
    end
end

local function updatePlatforms(dt)
    for _, platform in ipairs(platforms) do
        platform.dx = 0
        if platform.moving then
            local oldX = platform.x
            platform.x = platform.startX
                + math.sin(menuPulse * platform.speed + platform.phase) * platform.range
            platform.dx = platform.x - oldX
        end
    end
end

spawnFireball = function(fighter)
    table.insert(fireballs, {
        x = fighter.x + fighter.facing * 34,
        y = fighter.y - (fighter.mount and riderOffset or 0) - 44,
        velocityX = fighter.facing * 520,
        owner = fighter,
        active = true,
        life = 2.2,
    })
end

local function updateFireballs(dt)
    for _, fireball in ipairs(fireballs) do
        if fireball.active then
            fireball.x = fireball.x + fireball.velocityX * dt
            fireball.life = fireball.life - dt
            local defender = fireball.owner == fighter1 and fighter2 or fighter1
            if not defender.ko and math.abs(defender.x - fireball.x) < 30
                and math.abs((defender.y - 45) - fireball.y) < 70 then
                defender:takeDamage(18 * fireball.owner.power
                    * fireball.owner.comebackBoost, 42, fireball.owner)
                defender.hitFlash = hitFlashDuration
                fireball.active = false
            elseif fireball.life <= 0 or fireball.x < 0 or fireball.x > levelWidth then
                fireball.active = false
            end
        end
    end
end

local function checkpointFor(x)
    local checkpoints = { 180, 820, 1500, 2240, 3060 }
    local result = checkpoints[1]
    for _, checkpoint in ipairs(checkpoints) do
        if checkpoint <= x then
            result = checkpoint
        end
    end
    return result
end

loseLife = function(fighter, reason)
    if game.state ~= "fighting" then
        return
    end
    local playerNumber = fighter == fighter1 and 1 or 2
    FX.sound("ko")
    FX.burst(fighter.x,fighter.y-40,fighter.color,35,190)
    game.lives[playerNumber] = math.max(0, game.lives[playerNumber] - 1)
    if fighter.mount then
        fighter.mount.rider = nil
        fighter.mount.bonded = false
        fighter.mount = nil
    end
    if game.lives[playerNumber] <= 0 then
        local winner = playerNumber == 1 and 2 or 1
        game.state = "match_over"
        game.result = "PLAYER " .. winner .. " WINS — NO LIVES LEFT"
        game.transitionTimer = winnerScreenDuration
        return
    end
    fighter.x = checkpointFor(fighter.x)
    fighter.y = floorY - 90
    fighter.velocityY = 0
    fighter.grounded = false
    fighter.platform = nil
    fighter.health = fighter.maxHealth
    fighter.ko = false
    fighter.attack = nil
    fighter.special = nil
    fighter.blocking = false
    fighter.mushroomTimer = 0
    fighter.shieldHealth = 0
    fighter.fireTimer = 0
    fighter.bootsTimer = 0
    fighter.stunTimer = 0
    fighter.invulnerableTimer = 2.0
    fighter.state = "respawning"
end

local function updateComebackBoosts()
    for playerNumber, fighter in ipairs(fighters) do
        local opponent = playerNumber == 1 and fighter2 or fighter1
        local otherNumber = playerNumber == 1 and 2 or 1
        local behindLives = game.lives[playerNumber] < game.lives[otherNumber]
        local behindRace = opponent.x - fighter.x > 520
        fighter.comebackBoost = (behindLives or behindRace) and 1.12 or 1
    end
end

local function updateHazards()
    for _, fighter in ipairs(fighters) do
        if not fighter.ko and fighter.invulnerableTimer <= 0
            and fighter.y >= floorY - 3 then
            for _, spike in ipairs(spikes) do
                if fighter.x > spike.x and fighter.x < spike.x + spike.width then
                    local attacker = fighter == fighter1 and fighter2 or fighter1
                    fighter:takeDamage(18, 18, attacker)
                    fighter.velocityY = -260
                    fighter.grounded = false
                    fighter.invulnerableTimer = 0.85
                    break
                end
            end
        end
    end
end

local function resetRound()
    resetAnimals()
    resetPowerUps()
    resetPlatforms()
    fireballs = {}
    fighter1:reset()
    fighter2:reset()
    game.hitStopTimer = 0
    fighter2.aiInput = nil
    cpu.decisionTimer = 0.35
    cpu.attackCooldown = 0
    cpu.blockTimer = 0
    cpu.jumpCooldown = 0
    game.timeRemaining = roundDuration
    game.result = ""
    game.transitionTimer = 0
    game.state = "fighting"
    FX.reset(); FX.sound("confirm")
    cameraX = 0
    cameraCenterX = arenaWidth / 2
    cameraZoom = 1
end

local function restartMatch()
    game.round = 1
    game.score1 = 0
    game.score2 = 0
    game.lives = { 3, 3 }
    resetRound()
end

local function beginMatch()
    applyCharacter(fighter1, selectedCharacter[1])
    applyCharacter(fighter2, selectedCharacter[2])
    game.round = 1
    game.score1 = 0
    game.score2 = 0
    game.lives = { 3, 3 }
    resetRound()
end

local function openCharacterSelect()
    game.state = "character_select"
    selectionReady[1] = false
    selectionReady[2] = false
    fighter1.aiInput = nil
    fighter2.aiInput = nil
end

local phonePollTimer = 0
local previousPhoneEvents = { {}, {} }
local phoneEventsInitialized = false
local phoneConnected = { false, false }

local function readControllerFile(name)
    local data=love.filesystem.read(name)
    if data then return data end
    local f=io.open(love.filesystem.getSourceBaseDirectory().."/"..name,"rb")
    if f then local value=f:read("*a");f:close();return value end
end

local function refreshControllerQr(force)
    controllerQrCheckTimer = 0.5
    local url = readControllerFile("controller_url.txt")
    if url then
        controllerQrUrl = url:gsub("%s+$", "")
    end
    local info = love.filesystem.getInfo("controller_qr.png")
    if not info then
        return
    end

    local data = love.filesystem.read("controller_qr.png")
    if not data or (not force and data == controllerQrFileData) then
        return
    end
    local ok, fileData = pcall(love.filesystem.newFileData, data, "controller_qr.png")
    if not ok then
        return
    end
    local imageOk, image = pcall(love.graphics.newImage, fileData)
    if imageOk then
        image:setFilter("nearest", "nearest")
        controllerQrImage = image
        controllerQrFileData = data
    end
end

local function readPhoneState()
    local contents = readControllerFile("phone_controls.txt")
    local values = {}
    if contents then
        for key, value in contents:gmatch("([%w_]+)=([^\n]+)") do
            values[key] = value
        end
    end
    return values
end

local function handlePhonePress(playerNumber, action)
    local fighter = fighters[playerNumber]
    if game.state == "character_select" then
        if action == "left" then
            selectedCharacter[playerNumber] = (selectedCharacter[playerNumber] - 2)
                % #characters + 1
            selectionReady[playerNumber] = false
        elseif action == "right" then
            selectedCharacter[playerNumber] = selectedCharacter[playerNumber]
                % #characters + 1
            selectionReady[playerNumber] = false
        elseif action == "confirm" or action == "high" or action == "punch" then
            selectionReady[playerNumber] = true
            if playerNumber == 1 and cpuEnabled then
                repeat
                    selectedCharacter[2] = love.math.random(1, #characters)
                until selectedCharacter[2] ~= selectedCharacter[1]
                selectionReady[2] = true
            end
            if selectionReady[1] and selectionReady[2] then
                beginMatch()
            end
        end
        return
    end
    if game.state ~= "fighting" or fighter.ko then
        return
    end
    if action == "jump" then
        fighter:jump()
    elseif action == "high" or action == "punch" then
        fighter:startAttack("high")
    elseif action == "mid" or action == "kick" then
        fighter:startAttack("mid")
    elseif action == "low" then
        fighter:startAttack("low")
    elseif action == "mount" then
        toggleMount(fighter)
    elseif action == "special1" then
        fighter:startSpecial(1)
    elseif action == "special2" then
        fighter:startSpecial(2)
    elseif action == "special3" then
        fighter:startSpecial(3)
    elseif action == "special4" then
        fighter:startSpecial(4)
    end
end

local function updatePhoneControls(dt)
    phonePollTimer = phonePollTimer - dt
    if phonePollTimer > 0 then
        return
    end
    phonePollTimer = 0.04
    local values = readPhoneState()
    local currentTime = os.time()
    -- Switch to local PvP only when a second phone is actively connected.
    local p2seen=tonumber(values["p2_seen"] or "0") or 0
    if currentTime-p2seen<=2 then cpuEnabled=false end

    local actions = {
        "left", "right", "jump", "crouch", "high", "mid", "low", "punch", "kick", "block",
        "mount", "special1", "special2", "special3", "special4", "confirm",
    }
    for playerNumber = 1, 2 do
        local seen = tonumber(values["p" .. playerNumber .. "_seen"] or "0") or 0
        local connected = currentTime - seen <= 2
        phoneConnected[playerNumber] = connected
        local current = {}
        for _, action in ipairs(actions) do
            current[action] = connected
                and values["p" .. playerNumber .. "_" .. action] == "1"
            local eventKey = "p" .. playerNumber .. "_event_" .. action
            local eventCount = tonumber(values[eventKey] or "0") or 0
            local previousCount = previousPhoneEvents[playerNumber][action]
                or eventCount
            if phoneEventsInitialized and eventCount > previousCount then
                handlePhonePress(playerNumber, action)
            end
            previousPhoneEvents[playerNumber][action] = eventCount
        end
        fighters[playerNumber].phoneInput = connected and current or nil
    end
    phoneEventsInitialized = true
end

local function finishRound(winner)
    if game.state ~= "fighting" then
        return
    end

    if winner == 1 then
        game.score1 = game.score1 + 1
        game.result = "FIGHTER 1 WINS"
    elseif winner == 2 then
        game.score2 = game.score2 + 1
        game.result = "FIGHTER 2 WINS"
    else
        game.result = "DRAW"
    end

    fighter1.attack = nil
    fighter2.attack = nil
    fighter1.special = nil
    fighter2.special = nil
    game.hitStopTimer = 0
    fighter1.blocking = false
    fighter2.blocking = false
    fighter1.state = fighter1.ko and "ko" or "idle"
    fighter2.state = fighter2.ko and "ko" or "idle"

    if (winner == 1 and game.score1 >= roundsToWin)
        or (winner == 2 and game.score2 >= roundsToWin) then
        game.result = "FIGHTER " .. winner .. " WINS THE MATCH"
        fighter1.combo = 0
        fighter1.comboTimer = 0
        fighter2.combo = 0
        fighter2.comboTimer = 0
        game.state = "match_over"
        game.transitionTimer = winnerScreenDuration
    else
        game.state = "round_over"
        game.transitionTimer = roundEndDelay
    end
end

local function overlaps(a, b)
    return a.x < b.x + b.width and a.x + a.width > b.x
        and a.y < b.y + b.height and a.y + a.height > b.y
end

local function updateAttack(attacker, defender, dt)
    local attack = attacker.attack
    if not attack then
        return
    end

    local settings = attacks[attack.kind]
    attack.timer = attack.timer - dt
    if attack.timer <= 0 then
        if attack.phase == "startup" then
            attack.phase = "active"
            attack.timer = settings.active
        else
            attacker.attack = nil
            attacker.recovery = settings.recovery
            if not attack.hitOpponent then
                attacker.combo = 0
                attacker.comboTimer = 0
            end
            return
        end
    end

    if attack.phase == "active" then
        local hitbox = attack.hitbox
        local attackerOffset = attacker.mount and riderOffset or 0
        hitbox.y = attacker.y - attackerOffset - settings.yOffset
        if attacker.facing > 0 then
            hitbox.x = attacker.x + fighterWidth / 2 + 2
        else
            hitbox.x = attacker.x - fighterWidth / 2 - 2 - hitbox.width
        end

        if not attack.hitOpponent and not defender.ko then
            local defenderScale = defender.mushroomTimer > 0 and 1.35 or 1
            local defenderHeight = (defender.crouching and crouchingHeight
                or standingHeight) * defenderScale
            local defenderOffset = defender.mount and riderOffset or 0
            local defenderBox = {
                x = defender.x - fighterWidth / 2,
                y = defender.y - defenderOffset - defenderHeight,
                width = fighterWidth,
                height = defenderHeight,
            }
            local duckedHigh = settings.lane == "HIGH"
                and defender.crouching and defender.grounded
            if overlaps(hitbox, defenderBox) and not duckedHigh then
                attack.hitOpponent = true
                local bondPower = attacker.mount and attacker.mount.bonded and 1.05 or 1
                local mushroomPower = attacker.mushroomTimer > 0 and 1.35 or 1
                defender:takeDamage(settings.damage * attacker.power
                    * bondPower * mushroomPower * attacker.comebackBoost,
                    settings.knockback, attacker,
                    settings.lane == "LOW" and not defender.crouching)
                attacker.combo = attacker.combo + 1
                attacker.comboTimer = comboTimeout
                defender.combo = 0
                defender.comboTimer = 0
                defender.hitFlash = hitFlashDuration
                game.hitStopTimer = hitStopDuration
            end
        end
    end
end

local function updateSpecial(attacker, defender, dt)
    local special = attacker.special
    if not special then
        return
    end

    special.timer = special.timer - dt
    local progress = 1 - special.timer / special.duration
    local distance = math.abs(defender.x - attacker.x)
    local direction = defender.x >= attacker.x and 1 or -1
    local mushroomPower = attacker.mushroomTimer > 0 and 1.35 or 1

    if special.index == 1 then
        local eased = progress * progress * (3 - 2 * progress)
        special.targetX = special.startX + attacker.facing * 270 * eased
        attacker.x = math.max(fighterWidth / 2,
            math.min(levelWidth - fighterWidth / 2, special.targetX))
        attacker.y = special.startY - math.sin(progress * math.pi) * 112
        attacker.velocityY = 0
        attacker.grounded = false
        local swingDistance = math.abs(defender.x - attacker.x)
        if not special.hit and swingDistance <= 62 then
            special.hit = true
            defender:takeDamage(14 * attacker.power * mushroomPower
                * attacker.comebackBoost, 34, attacker)
            defender.hitFlash = hitFlashDuration
            game.hitStopTimer = hitStopDuration * 0.7
        end
    elseif special.index == 2 then
        if not special.didTeleport and progress >= 0.16 then
            special.didTeleport = true
            local targetX
            if distance <= 420 then
                targetX = defender.x + attacker.facing * 54
            else
                targetX = special.startX + attacker.facing * 220
            end
            attacker.x = math.max(fighterWidth / 2,
                math.min(levelWidth - fighterWidth / 2, targetX))
            attacker.invulnerableTimer = math.max(attacker.invulnerableTimer, 0.42)
            special.targetX = attacker.x
            attacker.facing = defender.x >= attacker.x and 1 or -1
        end
    elseif special.index == 3 then
        special.targetX = attacker.x
    end

    if special.timer <= 0 then
        if special.index == 1 then
            attacker.y = special.startY
            attacker.grounded = special.startGrounded
            attacker.platform = special.startPlatform
            attacker.velocityY = 0
        end
        attacker.special = nil
        attacker.recovery = 0.22
    end
end

local function separateFighters()
    local minimumDistance = fighterWidth
    local distance = fighter2.x - fighter1.x
    if math.abs(distance) >= minimumDistance then
        return
    end

    local direction = distance >= 0 and 1 or -1
    local overlap = minimumDistance - math.abs(distance)
    fighter1.x = fighter1.x - direction * overlap / 2
    fighter2.x = fighter2.x + direction * overlap / 2

    -- Keep separation when one fighter is already against an arena edge.
    if fighter1.x < fighterWidth / 2 then
        fighter1.x = fighterWidth / 2
        fighter2.x = fighter1.x + minimumDistance
    elseif fighter2.x > levelWidth - fighterWidth / 2 then
        fighter2.x = levelWidth - fighterWidth / 2
        fighter1.x = fighter2.x - minimumDistance
    end
end

local function updateCpu(dt)
    local profile = cpuProfiles[cpuDifficulty] or cpuProfiles.normal
    local input = { left = false, right = false, crouch = false, block = false }
    fighter2.aiInput = input

    cpu.decisionTimer = math.max(0, cpu.decisionTimer - dt)
    cpu.attackCooldown = math.max(0, cpu.attackCooldown - dt)
    cpu.blockTimer = math.max(0, cpu.blockTimer - dt)
    cpu.jumpCooldown = math.max(0, cpu.jumpCooldown - dt)

    local horizontalDistance = fighter1.x - fighter2.x
    local distance = math.abs(horizontalDistance)
    if distance > 90 then
        input.left = horizontalDistance < 0
        input.right = horizontalDistance > 0
    end
    input.block = cpu.blockTimer > 0
    if fighter1.attack and fighter1.attack.phase == "active" then
        local incomingLane = attacks[fighter1.attack.kind].lane
        if incomingLane == "HIGH" then
            input.crouch = true
            input.block = false
        elseif incomingLane == "MID" then
            input.block = true
        elseif incomingLane == "LOW" then
            input.crouch = true
            input.block = true
        end
    end

    -- Anticipate ground hazards instead of repeatedly walking into pits.
    if fighter2.grounded and cpu.jumpCooldown<=0 then
        local dir=input.left and -1 or 1
        local ahead=fighter2.x+dir*95
        local hazard=isOverPit(ahead)
        for _,v in ipairs(spikes)do if ahead>=v.x-24 and ahead<=v.x+v.width+24 then hazard=true end end
        if hazard then fighter2:jump();cpu.jumpCooldown=.6 end
    end
    if cpu.decisionTimer > 0 or fighter2.ko then
        return
    end

    if not fighter2.mount then
        toggleMount(fighter2)
    end

    cpu.decisionTimer = profile.reactionMin
        + love.math.random() * (profile.reactionMax - profile.reactionMin)
    local roll = love.math.random()

    if distance > 145 and distance <= 400 and fighter2.specialCooldowns[1] == 0
        and roll < 0.20 then
        fighter2:startSpecial(1)
    elseif distance <= 360 and fighter2.specialCooldowns[4] == 0
        and roll < 0.08 then
        fighter2:startSpecial(4)
    elseif distance <= 120 and fighter2.specialCooldowns[3] == 0
        and roll < 0.16 then
        fighter2:startSpecial(3)
    elseif distance <= 190 and fighter2.specialCooldowns[2] == 0
        and roll < 0.14 then
        fighter2:startSpecial(2)
    elseif distance <= 145 and roll < profile.blockChance
        and cpu.blockTimer == 0 and not fighter2.attack then
        cpu.blockTimer = 0.30 + love.math.random() * 0.35
    elseif roll < profile.blockChance + profile.jumpChance
        and fighter2.grounded and cpu.jumpCooldown == 0 then
        fighter2:jump()
        cpu.jumpCooldown = 2.0 + love.math.random() * 2.0
    elseif distance <= 128 and roll < profile.blockChance + profile.jumpChance + profile.attackChance
        and cpu.attackCooldown == 0 and not fighter2.attack and not fighter2.blocking then
        local rollKind = love.math.random()
        local kind = rollKind < 0.34 and "high"
            or (rollKind < 0.68 and "mid" or "low")
        fighter2:startAttack(kind)
        cpu.attackCooldown = profile.attackCooldownMin
            + love.math.random() * (profile.attackCooldownMax - profile.attackCooldownMin)
    end
end

function love.keypressed(key, scancode, isrepeat)
    if not isrepeat then
        if key=="f2" then cpuEnabled=not cpuEnabled; fighter2.aiInput=nil; FX.sound("menu"); return end
        if FX.key(key) then return end
        if key=="c" then FX.paused=false end
        if game.state=="character_select" then FX.sound(key=="return" and "confirm" or "menu") end
    end
    if key == "f11" and not isrepeat then
        love.window.setFullscreen(not love.window.getFullscreen(), "desktop")
        return
    end
    if game.state == "character_select" then
        if key == "escape" then
            love.event.quit()
            return
        elseif isrepeat then
            return
        end

        if not selectionReady[1] then
            if key == "a" or (cpuEnabled and key == "left") then
                selectedCharacter[1] = (selectedCharacter[1] - 2) % #characters + 1
            elseif key == "d" or (cpuEnabled and key == "right") then
                selectedCharacter[1] = selectedCharacter[1] % #characters + 1
            elseif key == "j" or key == "return" or key == "space" then
                selectionReady[1] = true
                if cpuEnabled then
                    repeat
                        selectedCharacter[2] = love.math.random(1, #characters)
                    until selectedCharacter[2] ~= selectedCharacter[1]
                    selectionReady[2] = true
                    beginMatch()
                end
            end
        elseif key == "a" or key == "d"
            or (cpuEnabled and (key == "left" or key == "right")) then
            selectionReady[1] = false
        end

        if not cpuEnabled and not selectionReady[2] then
            if key == "left" then
                selectedCharacter[2] = (selectedCharacter[2] - 2) % #characters + 1
            elseif key == "right" then
                selectedCharacter[2] = selectedCharacter[2] % #characters + 1
            elseif key == "n" then
                selectionReady[2] = true
            end
        end
        if not cpuEnabled and selectionReady[1] and selectionReady[2] then
            beginMatch()
        end
        return
    end

    if key == "r" and not isrepeat then
        restartMatch()
        return
    elseif key == "c" and not isrepeat then
        openCharacterSelect()
        return
    elseif key == "escape" then
        love.event.quit()
        return
    end
    if isrepeat or game.state ~= "fighting" or game.hitStopTimer > 0 then
        return
    end

    if key == "e" then
        toggleMount(fighter1)
        return
    elseif key == "/" and not cpuEnabled then
        toggleMount(fighter2)
        return
    end

    for _, fighter in ipairs(fighters) do
        if not (cpuEnabled and fighter == fighter2) then
            if key == fighter.controls.jump then
                fighter:jump()
            elseif key == fighter.controls.high then
                fighter:startAttack("high")
            elseif key == fighter.controls.mid then
                fighter:startAttack("mid")
            elseif key == fighter.controls.low then
                fighter:startAttack("low")
            elseif key == fighter.controls.special1 then
                fighter:startSpecial(1)
            elseif key == fighter.controls.special2 then
                fighter:startSpecial(2)
            elseif key == fighter.controls.special3 then
                fighter:startSpecial(3)
            elseif key == fighter.controls.special4 then
                fighter:startSpecial(4)
            end
        end
    end
end

function love.update(dt)
    dt=math.min(dt,.04)
    FX.update(dt,{game=game,fighters=fighters})
    if FX.paused then return end
    menuPulse = menuPulse + dt
    controllerQrCheckTimer = controllerQrCheckTimer - dt
    screenShakeTimer = math.max(0, screenShakeTimer - dt)
    screenFlashTimer = math.max(0, screenFlashTimer - dt)
    superBannerTimer = math.max(0, superBannerTimer - dt)
    updatePhoneControls(dt)
    if game.state == "character_select" then
        return
    end
    if game.state == "round_over" then
        fighter1.hitFlash = math.max(0, fighter1.hitFlash - dt)
        fighter2.hitFlash = math.max(0, fighter2.hitFlash - dt)
        game.transitionTimer = game.transitionTimer - dt
        if game.transitionTimer <= 0 then
            game.round = game.round + 1
            resetRound()
        end
        return
    elseif game.state ~= "fighting" then
        if game.state == "match_over" or game.state == "game_won" then
            game.transitionTimer = game.transitionTimer - dt
            if game.transitionTimer <= 0 then
                openCharacterSelect()
            end
        end
        fighter1.hitFlash = math.max(0, fighter1.hitFlash - dt)
        fighter2.hitFlash = math.max(0, fighter2.hitFlash - dt)
        return
    end

    if game.hitStopTimer > 0 then
        game.hitStopTimer = math.max(0, game.hitStopTimer - dt)
        return
    end

    game.timeRemaining = math.max(0, game.timeRemaining - dt)
    updatePlatforms(dt)
    updateComebackBoosts()
    if cpuEnabled and game.state == "fighting" then
        updateCpu(dt)
    else
        fighter2.aiInput = nil
    end
    fighter1:update(dt)
    fighter2:update(dt)
    updatePowerUps(dt)
    updateFireballs(dt)
    updateHazards()
    separateFighters()

    if fighter2.x > fighter1.x then
        fighter1.facing = 1
        fighter2.facing = -1
    else
        fighter1.facing = -1
        fighter2.facing = 1
    end
    updateAnimals(dt)
    updateSpecial(fighter1, fighter2, dt)
    updateSpecial(fighter2, fighter1, dt)

    local fighterDistance = math.abs(fighter2.x - fighter1.x)
    local desiredZoom = math.max(0.55, math.min(1, 760 / (fighterDistance + 260)))
    cameraZoom = cameraZoom + (desiredZoom - cameraZoom) * math.min(1, dt * 3.5)
    local desiredCenter = (fighter1.x + fighter2.x) / 2
    local visibleHalf = arenaWidth / (2 * cameraZoom)
    desiredCenter = math.max(visibleHalf,
        math.min(levelWidth - visibleHalf, desiredCenter))
    cameraCenterX = cameraCenterX
        + (desiredCenter - cameraCenterX) * math.min(1, dt * 4.5)
    cameraX = cameraCenterX - visibleHalf

    updateAttack(fighter1, fighter2, dt)
    updateAttack(fighter2, fighter1, dt)
    separateFighters()

    fighter1:updateState()
    fighter2:updateState()

    if fighter1.x >= flagX - 24 or fighter2.x >= flagX - 24 then
        local winner = fighter1.x >= flagX - 24 and 1 or 2
        game.state = "game_won"
        game.result = "PLAYER " .. winner .. " CAPTURED THE FLAG!"
        game.transitionTimer = winnerScreenDuration
        fighter1.attack = nil
        fighter2.attack = nil
        fighter1.blocking = false
        fighter2.blocking = false
        return
    end

    if fighter1.ko then
        loseLife(fighter1, "KO")
    end
    if fighter2.ko and game.state == "fighting" then
        loseLife(fighter2, "KO")
    end
    if game.state ~= "fighting" then
        return
    end
    if game.timeRemaining <= 0 then
        game.state = "match_over"
        game.transitionTimer = winnerScreenDuration
        if fighter1.x > fighter2.x then
            game.result = "TIME — PLAYER 1 WINS THE RACE"
        elseif fighter2.x > fighter1.x then
            game.result = "TIME — PLAYER 2 WINS THE RACE"
        elseif game.lives[1] > game.lives[2] then
            game.result = "TIME — PLAYER 1 WINS ON LIVES"
        elseif game.lives[2] > game.lives[1] then
            game.result = "TIME — PLAYER 2 WINS ON LIVES"
        else
            game.result = "TIME — DRAW"
        end
    end
end

local function drawEmberFighter(fighter, scale, bodyShift)
    local crouchScale = fighter.crouching and 0.88 or 1
    love.graphics.push()
    love.graphics.translate(fighter.x + bodyShift,
        fighter.y - (fighter.mount and riderOffset or 0))
    love.graphics.scale(fighter.facing * scale, scale * crouchScale)

    local pulse = 0.5 + 0.5 * math.sin(menuPulse * 11 + fighter.x * 0.025)
    local red = { 0.78 + pulse * 0.10, 0.075, 0.055 }
    local bright = { 1.00, 0.28 + pulse * 0.20, 0.035 }
    local dark = { 0.105, 0.055, 0.075 }
    local skin = { 0.91, 0.53, 0.36 }
    local attackReach = fighter.attack
        and (fighter.attack.phase == "active" and 1 or 0.45) or 0

    -- Long dark trousers and wrapped shin guards.
    love.graphics.setColor(0.035, 0.028, 0.045)
    love.graphics.polygon("fill", -11, -38, 1, -38, -4, -19, -18, -4,
        -29, -4, -22, -18)
    love.graphics.polygon("fill", 0, -38, 12, -39, 19, -20, 29, -7,
        18, -2, 7, -17)
    love.graphics.setColor(0.38, 0.055, 0.045)
    love.graphics.polygon("fill", -23, -19, -17, -15, -25, -6, -30, -6)
    love.graphics.polygon("fill", 16, -18, 22, -20, 30, -8, 24, -5)
    love.graphics.setColor(0.075, 0.045, 0.055)
    love.graphics.polygon("fill", -29, -5, -17, -5, -14, -1, -34, -1)
    love.graphics.polygon("fill", 20, -5, 32, -7, 37, -2, 20, -1)
    love.graphics.setColor(bright)
    love.graphics.line(-24, -17, -19, -12, -26, -7)
    love.graphics.line(17, -17, 23, -13, 29, -8)
    love.graphics.setColor(0.16, 0.035, 0.045)
    love.graphics.line(-18, -34, -11, -27, -17, -19)
    love.graphics.line(3, -35, 10, -27, 14, -20)
    love.graphics.setColor(0.70, 0.10, 0.055)
    love.graphics.line(-17, -31, -13, -27)
    love.graphics.line(4, -32, 9, -27)
    love.graphics.setColor(1, 0.72, 0.25)
    love.graphics.line(-31, -3, -21, -3)
    love.graphics.line(23, -4, 34, -4)

    -- A loose flame sash trails behind the fighter and follows the idle motion.
    local clothWave = math.sin(menuPulse * 5 + fighter.x * 0.03) * 4
    love.graphics.setColor(0.43, 0.025, 0.035, 0.96)
    love.graphics.polygon("fill", -8, -42, -18, -39, -37, -48 + clothWave,
        -31, -35 + clothWave, -47, -25 + clothWave, -23, -29, -9, -34)
    love.graphics.setColor(bright[1], bright[2], bright[3], 0.94)
    love.graphics.polygon("fill", -18, -40, -34, -45 + clothWave,
        -28, -35 + clothWave, -42, -27 + clothWave, -22, -31)

    -- Fitted red-and-black top, edged with gold piping.
    love.graphics.setColor(dark)
    love.graphics.polygon("fill", -12, -69, 8, -69, 15, -59, 10, -38,
        -10, -38, -16, -57)
    love.graphics.setColor(red)
    love.graphics.polygon("fill", -10, -66, 6, -66, 10, -57, 6, -43,
        -8, -43, -13, -57)
    love.graphics.setColor(1, 0.63, 0.18)
    love.graphics.line(-10, -64, -4, -57, 3, -64, 8, -58)
    love.graphics.line(-8, -43, 7, -43)
    love.graphics.setColor(0.14, 0.055, 0.045)
    love.graphics.rectangle("fill", -12, -40, 25, 5, 2, 2)
    love.graphics.setColor(1, 0.68, 0.20)
    love.graphics.rectangle("fill", -2, -40, 6, 5, 1, 1)
    love.graphics.setColor(0.72, 0.045, 0.035)
    love.graphics.polygon("fill", -10, -35, 8, -35, 26, -30,
        13, -27, -3, -31, -18, -27)
    love.graphics.setColor(1, 0.31, 0.035)
    love.graphics.polygon("fill", -15, -31, -4, -28, -17, -23,
        -30, -22, -20, -27)
    love.graphics.setColor(1, 0.74, 0.23)
    love.graphics.line(-9, -39, 1, -37, 10, -39)
    love.graphics.circle("fill", 1, -37, 2)
    love.graphics.setColor(0.97, 0.30, 0.12)
    love.graphics.line(-11, -59, -5, -55, -10, -50)
    love.graphics.line(8, -59, 3, -54, 8, -50)

    -- Raised guard and forward striking arm, drawn as outlined segments.
    love.graphics.setColor(0.075, 0.035, 0.045)
    love.graphics.setLineWidth(12)
    love.graphics.line(-9, -62, -20, -53, -17, -45)
    love.graphics.line(9, -61, 18, -54, 24 + 19 * attackReach, -53)
    love.graphics.setColor(skin)
    love.graphics.setLineWidth(7)
    love.graphics.line(-9, -62, -20, -53, -17, -45)
    love.graphics.line(9, -61, 18, -54, 24 + 19 * attackReach, -53)
    love.graphics.setLineWidth(1)
    love.graphics.setColor(0.48, 0.045, 0.04)
    love.graphics.circle("fill", -17, -44, 6)
    love.graphics.circle("fill", 25 + 19 * attackReach, -53, 7)
    love.graphics.setColor(1, 0.53, 0.16)
    love.graphics.rectangle("fill", 13, -57, 8, 6, 2, 2)
    love.graphics.rectangle("fill", -22, -48, 8, 6, 2, 2)
    love.graphics.setColor(0.98, 0.67, 0.18)
    love.graphics.line(14, -56, 20, -56)
    love.graphics.line(-22, -47, -16, -47)
    love.graphics.setColor(0.22, 0.045, 0.04)
    love.graphics.circle("fill", 25 + 19 * attackReach, -53, 3)
    love.graphics.circle("fill", -17, -44, 3)

    -- Face, dark headband and the high, flame-shaped ponytail.
    love.graphics.setColor(0.10, 0.025, 0.04)
    love.graphics.polygon("fill", -8, -78, -18, -88, -32, -99,
        -25, -88, -42, -94, -30, -83, -47, -86, -29, -76, -13, -70)
    love.graphics.setColor(0.62, 0.035, 0.025)
    love.graphics.polygon("fill", -17, -82, -31, -96, -26, -86,
        -40, -91, -28, -82, -43, -82, -26, -76)
    love.graphics.setColor(bright)
    love.graphics.line(-25, -91, -31, -87, -39, -87)
    love.graphics.line(-22, -84, -32, -80)
    love.graphics.setColor(0.12, 0.035, 0.04)
    love.graphics.polygon("fill", -10, -71, -17, -83, -12, -79,
        -13, -91, -5, -83, 0, -94, 3, -82, 10, -88, 8, -77, 14, -70)
    love.graphics.setColor(0.42, 0.025, 0.025)
    love.graphics.polygon("fill", -12, -81, -20, -91, -9, -87,
        -7, -98, 0, -87, 10, -93, 6, -81)
    love.graphics.setColor(bright)
    love.graphics.line(-18, -90, -10, -87, -7, -94)
    love.graphics.line(-3, -85, 2, -91, 7, -87)
    love.graphics.setColor(skin)
    love.graphics.ellipse("fill", 1, -73, 10, 12)
    love.graphics.setColor(0.12, 0.025, 0.035)
    love.graphics.polygon("fill", -9, -77, -7, -84, 6, -83,
        11, -77, 5, -80, -3, -79)
    love.graphics.setColor(1, 0.83, 0.58)
    love.graphics.line(1, -73, 5, -72)
    love.graphics.setColor(0.20, 0.035, 0.045)
    love.graphics.line(2, -76, 7, -76)
    love.graphics.circle("fill", 5, -76, 1.2)
    love.graphics.setColor(0.72, 0.26, 0.16)
    love.graphics.line(10, -72, 12, -69)
    love.graphics.setColor(0.20, 0.025, 0.035)
    love.graphics.line(6, -68, 1, -66, -2, -67)
    love.graphics.setColor(1, 0.67, 0.15)
    love.graphics.rectangle("fill", -8, -81, 16, 3, 1, 1)
    love.graphics.circle("fill", 8, -80, 2)

    if fighter.fireTimer > 0 then
        love.graphics.setColor(1, 0.25, 0.025, 0.75)
        for i = 1, 3 do
            local flameY = -26 - i * 17
            local flameX = -8 - (i % 2) * 5
            love.graphics.polygon("fill", flameX, flameY + 9,
                flameX - 5, flameY, flameX - 3, flameY - 10 - pulse * 4,
                flameX + 3, flameY - 2, flameX + 7, flameY + 8)
        end
    end
    love.graphics.pop()
end

local function drawFighter(fighter)
    if FX.fighter(fighter) then return end
    local scale = fighter.mushroomTimer > 0 and 1.35 or 1
    local bodyWidth = fighterWidth * scale
    local bodyHeight = (fighter.crouching and crouchingHeight or standingHeight) * scale
    local bodyBaseY = fighter.y - (fighter.mount and riderOffset or 0)
    local bodyTop = bodyBaseY - bodyHeight
    local bodyShift = 0
    if fighter.timeStopTimer > 0 then
        love.graphics.setColor(0.22, 0.78, 1, 0.22)
        love.graphics.circle("fill", fighter.x, bodyTop + bodyHeight / 2, 56 * scale)
        love.graphics.setColor(0.42, 0.88, 1, 0.88)
        love.graphics.setLineWidth(3)
        love.graphics.circle("line", fighter.x, bodyTop + bodyHeight / 2, 48 * scale)
        love.graphics.setLineWidth(1)
        for shard = 1, 6 do
            local angle = shard * math.pi / 3 + menuPulse * 0.6
            local sx = fighter.x + math.cos(angle) * 40 * scale
            local sy = bodyTop + bodyHeight / 2 + math.sin(angle) * 40 * scale
            love.graphics.polygon("fill", sx, sy - 9, sx + 6, sy,
                sx, sy + 9, sx - 6, sy)
        end
    end
    if fighter.attack then
        bodyShift = fighter.facing * (fighter.attack.phase == "active" and 4 or -2)
    elseif fighter.special and fighter.special.index == 2 then
        bodyShift = fighter.facing * 10
    elseif fighter.recovery > 0 then
        bodyShift = -fighter.facing * 2
    end

    if fighter.mushroomTimer > 0 then
        local pulse = 0.20 + 0.08 * math.sin(menuPulse * 8)
        love.graphics.setColor(1, 0.28, 0.18, pulse)
        love.graphics.circle("fill", fighter.x, bodyTop + bodyHeight / 2,
            46 * scale)
        love.graphics.setColor(1, 0.84, 0.28, 0.9)
        love.graphics.rectangle("line", fighter.x - bodyWidth / 2 - 5,
            bodyTop - 20 * scale, bodyWidth + 10, bodyHeight + 25 * scale)
    end
    if fighter.shieldHealth > 0 then
        love.graphics.setColor(0.24, 0.68, 1, 0.22)
        love.graphics.circle("fill", fighter.x, bodyTop + bodyHeight / 2,
            54 * scale)
        love.graphics.setColor(0.52, 0.86, 1, 0.9)
        love.graphics.circle("line", fighter.x, bodyTop + bodyHeight / 2,
            54 * scale)
    end

    if fighter.invulnerableTimer > 0
        and math.floor(fighter.invulnerableTimer * 12) % 2 == 0 then
        love.graphics.setColor(fighter.color[1], fighter.color[2], fighter.color[3], 0.28)
    elseif fighter.hitFlash > 0 then
        love.graphics.setColor(1, 1, 1)
    else
        love.graphics.setColor(fighter.color[1], fighter.color[2], fighter.color[3])
    end
    if fighter.character and fighter.character.name == "EMBER" then
        drawEmberFighter(fighter, scale, bodyShift)
    else
        love.graphics.rectangle("fill", fighter.x - bodyWidth / 2 + bodyShift, bodyTop,
            bodyWidth, bodyHeight)
        love.graphics.circle("fill", fighter.x + bodyShift,
            bodyTop - 11 * scale, 12 * scale)
    end

    if fighter.attack then
        local settings = attacks[fighter.attack.kind]
        local active = fighter.attack.phase == "active"
        local extension = active and 1 or 0.34
        local fromX = fighter.x + bodyShift + fighter.facing * bodyWidth * 0.18
        local fromY = bodyTop + bodyHeight
            * (settings.lane == "LOW" and 0.76
                or (settings.lane == "HIGH" and 0.20 or 0.48))
        local toX = fighter.x + bodyShift + fighter.facing
            * (bodyWidth * 0.5 + settings.range * 0.58 * extension) * scale
        local toY = settings.lane == "HIGH" and bodyTop + bodyHeight * 0.17
            or (settings.lane == "MID" and bodyTop + bodyHeight * 0.48
                or bodyBaseY - 5 * scale)
        local limbWidth = settings.limb == "leg" and 10 or 7
        love.graphics.setColor(0.045, 0.045, 0.07, 0.92)
        love.graphics.setLineWidth((limbWidth + 4) * scale)
        love.graphics.line(fromX, fromY, toX, toY)
        love.graphics.setColor(settings.lane == "HIGH" and 1 or 0.98,
            settings.lane == "MID" and 0.92 or 0.68,
            settings.lane == "LOW" and 0.20 or 0.34, 1)
        love.graphics.setLineWidth(limbWidth * scale)
        love.graphics.line(fromX, fromY, toX, toY)
        love.graphics.circle("fill", toX, toY, (settings.limb == "leg" and 7 or 5) * scale)
        love.graphics.setLineWidth(1)
    end

    if fighter.blocking then
        love.graphics.setColor(0.55, 0.88, 1, 0.8)
        love.graphics.rectangle("line", fighter.x - bodyWidth / 2 - 5,
            bodyTop - 5, bodyWidth + 10, bodyHeight + 10)
    end

    if fighter.attack and fighter.attack.phase == "active" then
        local hitbox = fighter.attack.hitbox
        local settings = attacks[fighter.attack.kind]
        love.graphics.setColor(settings.lane == "HIGH" and 1 or 0.30,
            settings.lane == "MID" and 0.78 or 0.46,
            settings.lane == "LOW" and 0.12 or 1, 0.32)
        love.graphics.rectangle("fill", hitbox.x, hitbox.y, hitbox.width, hitbox.height)
        love.graphics.setColor(1, 0.95, 0.75, 0.9)
        love.graphics.rectangle("line", hitbox.x, hitbox.y, hitbox.width, hitbox.height)
    end
end

local function drawSpecialEffect(fighter)
    local special = fighter.special
    local accent = fighter.character and fighter.character.accent or fighter.color

    if fighter.flightTimer > 0 then
        local pulse = 0.22 + 0.08 * math.sin(menuPulse * 12)
        love.graphics.setColor(0.34, 0.72, 1, pulse)
        love.graphics.ellipse("line", fighter.x, fighter.y - 15, 48, 15)
        love.graphics.setColor(accent[1], accent[2], accent[3], 0.48)
        for wing = -1, 1, 2 do
            love.graphics.arc("line", fighter.x, fighter.y - 48, 38,
                wing < 0 and math.pi or 0,
                wing < 0 and math.pi * 1.65 or math.pi * 0.65)
        end
    end
    if not special then return end
    local progress = 1 - special.timer / special.duration

    if special.index == 1 then
        local handX = fighter.x + fighter.facing * 18
        local handY = fighter.y - (fighter.mount and riderOffset or 0) - 48
        local tipX, tipY = special.anchorX, math.max(70, special.startY - 290)
        love.graphics.setLineWidth(3)
        love.graphics.setColor(0.88, 0.96, 1, 0.95)
        love.graphics.line(handX, handY, tipX, tipY)
        love.graphics.setLineWidth(1)
        for strand = -2, 2 do
            local fraction = (strand + 3) / 6
            local webX = tipX + (handX - tipX) * fraction
            local webY = tipY + (handY - tipY) * fraction
            love.graphics.line(tipX - 15, tipY + strand * 6,
                webX, webY, tipX + 15, tipY + strand * 6)
        end
        love.graphics.circle("line", tipX, tipY, 11)
        love.graphics.line(tipX - 13, tipY - 7, tipX + 13, tipY + 7)
        love.graphics.line(tipX - 13, tipY + 7, tipX + 13, tipY - 7)
        love.graphics.setLineWidth(1)
    elseif special.index == 2 then
        for i = 1, 5 do
            local ghostX = special.startX
                + (fighter.x - special.startX) * (i / 5)
            love.graphics.setColor(accent[1], accent[2], accent[3], 0.23 / i)
            love.graphics.rectangle("fill", ghostX - 19, fighter.y - 75,
                38, 70, 9, 9)
        end
    elseif special.index == 4 then
        local radius = 35 + math.sin(math.min(1, progress) * math.pi) * 130
        love.graphics.setColor(0.28, 0.75, 1, 0.20)
        love.graphics.circle("fill", fighter.x, fighter.y - 42, radius)
        love.graphics.setColor(0.66, 0.92, 1, 0.9)
        love.graphics.setLineWidth(4)
        love.graphics.circle("line", fighter.x, fighter.y - 42, radius)
        love.graphics.setLineWidth(1)
    end
end

local function drawAnimal(animal)
    if FX.animal(animal) then return end
    local x = animal.x
    local y = animal.y + math.sin(animal.bob) * (animal.rider and 2.5 or 1)
    local facing = animal.facing or 1
    love.graphics.setColor(animal.color)
    if animal.kind == "HORSE" then
        love.graphics.ellipse("fill", x, y - 25, 43, 21)
        love.graphics.rectangle("fill", x + facing * 25 - 7, y - 58, 14, 38)
        love.graphics.ellipse("fill", x + facing * 32, y - 60, 18, 13)
        love.graphics.rectangle("fill", x - 28, y - 24, 8, 24)
        love.graphics.rectangle("fill", x + 20, y - 24, 8, 24)
        love.graphics.setColor(animal.mane)
        love.graphics.rectangle("fill", x + facing * 19 - 4, y - 58, 8, 31)
        love.graphics.polygon("fill", x - facing * 42, y - 34,
            x - facing * 58, y - 45, x - facing * 45, y - 25)
    else
        love.graphics.ellipse("fill", x, y - 20, 42, 20)
        love.graphics.ellipse("fill", x + facing * 34, y - 24, 20, 15)
        love.graphics.rectangle("fill", x - 25, y - 19, 8, 19)
        love.graphics.rectangle("fill", x + 18, y - 19, 8, 19)
        love.graphics.setColor(0.92, 0.84, 0.62)
        love.graphics.polygon("fill", x + facing * 47, y - 24,
            x + facing * 58, y - 30, x + facing * 49, y - 18)
        love.graphics.setColor(animal.mane)
        love.graphics.polygon("fill", x - 22, y - 39, x + 15, y - 41, x, y - 31)
    end

    if not animal.rider then
        love.graphics.setColor(0.95, 0.88, 0.38)
        love.graphics.printf(animal.kind, x - 48, y - 88, 96, "center")
        love.graphics.setColor(0.68, 0.74, 0.84)
        love.graphics.printf(animal.mood, x - 55, y - 74, 110, "center")
        if math.abs(fighter1.x - animal.x) <= mountDistance then
            love.graphics.setColor(1, 0.92, 0.42)
            love.graphics.printf("E  RIDE", x - 55, y - 105, 110, "center")
        elseif not cpuEnabled and math.abs(fighter2.x - animal.x) <= mountDistance then
            love.graphics.setColor(1, 0.92, 0.42)
            love.graphics.printf("/  RIDE", x - 55, y - 105, 110, "center")
        end
    elseif animal.bondTimer > 0 then
        local riderColor = animal.rider.character.accent
        love.graphics.setColor(riderColor[1], riderColor[2], riderColor[3],
            math.min(1, animal.bondTimer))
        love.graphics.printf(animal.bonded and "★ PERFECT BOND ★" or "MOUNTED",
            x - 90, y - 146, 180, "center")
        if animal.bonded then
            for i = 1, 3 do
                local angle = menuPulse * 2.4 + i * 2.1
                love.graphics.circle("fill", x + math.cos(angle) * 50,
                    y - 75 + math.sin(angle) * 18, 3)
            end
        end
    end
end

local function drawHealthBar(fighter, x, alignRight, label)
    FX.health(fighter,x,alignRight,label,game.lives[fighter==fighter1 and 1 or 2]); do return end
    local barWidth = 180
    local barX = alignRight and x - barWidth or x
    love.graphics.setColor(0.10, 0.10, 0.13)
    love.graphics.rectangle("fill", barX, 64, barWidth, 16)
    love.graphics.setColor(fighter.color[1], fighter.color[2], fighter.color[3])
    love.graphics.rectangle("fill", barX, 64,
        barWidth * fighter.health / fighter.maxHealth, 16)
    love.graphics.setColor(0.92, 0.94, 1)
    local playerNumber = fighter == fighter1 and 1 or 2
    local livesText = string.rep("*", game.lives[playerNumber])
    if alignRight then
        love.graphics.printf(label .. " HP " .. fighter.health,
            barX - 132, 63, 124, "right")
        love.graphics.printf(livesText, barX, 44, barWidth, "right")
        love.graphics.printf("State: " .. fighter.state, barX - 132, 86, 304, "right")
    else
        love.graphics.print(label .. " HP " .. fighter.health, barX + barWidth + 8, 63)
        love.graphics.print(livesText, barX, 44)
        love.graphics.print("State: " .. fighter.state, barX, 86)
    end

    local attackStatus = "READY"
    if fighter.attack then
        attackStatus = string.upper(fighter.attack.kind) .. " "
            .. string.upper(fighter.attack.phase)
    elseif fighter.recovery > 0 then
        attackStatus = "RECOVERY"
    elseif fighter.blocking then
        attackStatus = "BLOCKING"
    end
    if alignRight then
        love.graphics.printf("Attack: " .. attackStatus,
            barX - 132, 106, 304, "right")
    else
        love.graphics.print("Attack: " .. attackStatus, barX, 106)
    end
end

local function drawSpecialHud(fighter, x, alignRight, keys)
    FX.specialHud(fighter,x,alignRight,keys); do return end
    local totalWidth = 274
    local startX = alignRight and x - totalWidth or x
    for i, move in ipairs(specialMoves) do
        local boxX = startX + (i - 1) * 68
        local ready = fighter.specialCooldowns[i] <= 0
        love.graphics.setColor(ready and { 0.16, 0.28, 0.24, 0.94 }
            or { 0.11, 0.12, 0.17, 0.90 })
        love.graphics.rectangle("fill", boxX, 126, 64, 28, 5, 5)
        love.graphics.setColor(ready and { 0.40, 1.00, 0.64 }
            or { 0.42, 0.44, 0.52 })
        love.graphics.rectangle("line", boxX, 126, 64, 28, 5, 5)
        love.graphics.printf(keys[i] .. "  " .. (ready and "READY"
            or string.format("%.1f", fighter.specialCooldowns[i])),
            boxX, 132, 64, "center")
    end
end

local function drawStat(label, value, maximum, x, y, width, color)
    love.graphics.setFont(uiFont)
    love.graphics.setColor(0.72, 0.76, 0.86)
    love.graphics.print(label, x, y)
    love.graphics.setColor(0.12, 0.14, 0.22)
    love.graphics.rectangle("fill", x + 48, y + 3, width, 7, 4, 4)
    love.graphics.setColor(color)
    love.graphics.rectangle("fill", x + 48, y + 3,
        width * math.min(1, value / maximum), 7, 4, 4)
end

local function drawCharacterPortrait(character, x, y, scale, selected)
    if FX.portrait(character,x,y,scale,selected) then return end
    if selected then
        local glow = 0.16 + 0.08 * math.sin(menuPulse * 4)
        love.graphics.setColor(character.accent[1], character.accent[2],
            character.accent[3], glow)
        love.graphics.circle("fill", x, y, 70 * scale)
    end

    if character.name == "EMBER" then
        love.graphics.setColor(0.12, 0.025, 0.04)
        love.graphics.polygon("fill", x - 8 * scale, y - 12 * scale,
            x - 24 * scale, y - 39 * scale, x - 13 * scale, y - 33 * scale,
            x - 7 * scale, y - 53 * scale, x + 1 * scale, y - 34 * scale,
            x + 18 * scale, y - 45 * scale, x + 10 * scale, y - 25 * scale)
        love.graphics.setColor(0.90, 0.14, 0.025)
        love.graphics.polygon("fill", x - 14 * scale, y - 34 * scale,
            x - 22 * scale, y - 48 * scale, x - 9 * scale, y - 42 * scale,
            x - 3 * scale, y - 58 * scale, x + 2 * scale, y - 39 * scale)
        love.graphics.setColor(0.08, 0.04, 0.06)
        love.graphics.polygon("fill", x - 38 * scale, y + 60 * scale,
            x - 28 * scale, y + 5 * scale, x - 15 * scale, y - 6 * scale,
            x + 16 * scale, y - 6 * scale, x + 30 * scale, y + 8 * scale,
            x + 40 * scale, y + 60 * scale)
        love.graphics.setColor(0.78, 0.055, 0.035)
        love.graphics.polygon("fill", x - 25 * scale, y + 17 * scale,
            x - 21 * scale, y - 8 * scale, x - 12 * scale, y - 17 * scale,
            x + 12 * scale, y - 17 * scale, x + 23 * scale, y - 5 * scale,
            x + 28 * scale, y + 18 * scale, x + 10 * scale, y + 11 * scale,
            x - 9 * scale, y + 11 * scale)
        love.graphics.setColor(0.93, 0.54, 0.37)
        love.graphics.ellipse("fill", x + 2 * scale, y - 25 * scale,
            17 * scale, 22 * scale)
        love.graphics.setColor(0.10, 0.025, 0.035)
        love.graphics.polygon("fill", x - 15 * scale, y - 28 * scale,
            x - 12 * scale, y - 46 * scale, x + 7 * scale, y - 48 * scale,
            x + 20 * scale, y - 32 * scale, x + 10 * scale, y - 37 * scale,
            x - 2 * scale, y - 35 * scale)
        love.graphics.setColor(1, 0.74, 0.22)
        love.graphics.rectangle("fill", x - 13 * scale, y - 39 * scale,
            28 * scale, 4 * scale, 2 * scale, 2 * scale)
        love.graphics.circle("fill", x + 15 * scale, y - 37 * scale, 3 * scale)
        love.graphics.setColor(0.20, 0.025, 0.035)
        love.graphics.line(x + 7 * scale, y - 26 * scale,
            x + 14 * scale, y - 25 * scale)
        love.graphics.setColor(1, 0.48, 0.12)
        love.graphics.polygon("fill", x - 28 * scale, y + 17 * scale,
            x - 8 * scale, y + 12 * scale, x + 12 * scale, y + 17 * scale,
            x + 26 * scale, y + 30 * scale, x + 7 * scale, y + 25 * scale,
            x - 11 * scale, y + 30 * scale, x - 31 * scale, y + 24 * scale)
        love.graphics.setColor(1, 0.70, 0.20)
        love.graphics.rectangle("fill", x - 4 * scale, y + 14 * scale,
            8 * scale, 8 * scale, 2 * scale, 2 * scale)
        return
    end

    love.graphics.setColor(0.06, 0.07, 0.12)
    love.graphics.polygon("fill",
        x - 42 * scale, y + 58 * scale,
        x - 30 * scale, y - 5 * scale,
        x + 30 * scale, y - 5 * scale,
        x + 42 * scale, y + 58 * scale)
    love.graphics.setColor(character.color)
    love.graphics.rectangle("fill", x - 25 * scale, y - 2 * scale,
        50 * scale, 62 * scale, 10 * scale, 10 * scale)
    love.graphics.circle("fill", x, y - 28 * scale, 27 * scale)
    love.graphics.setColor(character.accent)
    love.graphics.polygon("fill",
        x - 28 * scale, y - 34 * scale,
        x, y - 60 * scale,
        x + 28 * scale, y - 34 * scale,
        x + 17 * scale, y - 42 * scale,
        x - 18 * scale, y - 42 * scale)
    love.graphics.rectangle("fill", x - 30 * scale, y + 15 * scale,
        60 * scale, 9 * scale, 4 * scale, 4 * scale)
    love.graphics.setColor(1, 0.96, 0.78)
    love.graphics.rectangle("fill", x - 16 * scale, y - 31 * scale,
        10 * scale, 4 * scale, 2 * scale, 2 * scale)
    love.graphics.rectangle("fill", x + 6 * scale, y - 31 * scale,
        10 * scale, 4 * scale, 2 * scale, 2 * scale)
end

local function drawCharacterSelect()
    love.graphics.clear(0.025, 0.03, 0.07)
    for y = 0, 540, 18 do
        local blend = y / 540
        love.graphics.setColor(0.04 + blend * 0.06, 0.05 + blend * 0.03,
            0.12 + blend * 0.08, 1)
        love.graphics.rectangle("fill", 0, y, arenaWidth, 18)
    end
    FX.backgroundDraw(0)
    love.graphics.setColor(.015,.025,.05,.72)
    love.graphics.rectangle("fill",0,0,960,540)
    for i = 1, 22 do
        local x = (i * 137) % arenaWidth
        local y = 82 + (i * 71) % 360
        local alpha = 0.12 + 0.08 * math.sin(menuPulse * 1.6 + i)
        love.graphics.setColor(0.55, 0.72, 1, alpha)
        love.graphics.circle("fill", x, y, i % 3 + 1)
    end

    love.graphics.setFont(titleFont)
    love.graphics.setColor(0.12, 0.42, 0.72, 0.28)
    love.graphics.printf("CHOOSE YOUR FIGHTER", 3, 25, arenaWidth, "center")
    love.graphics.setColor(0.94, 0.96, 1)
    love.graphics.printf("CHOOSE YOUR FIGHTER", 0, 22, arenaWidth, "center")
    love.graphics.setFont(uiFont)
    love.graphics.setColor(0.48, 0.78, 1)
    love.graphics.printf("SHADOW FIGHTERS  //  RIDE. STRIKE. SURVIVE.",
        0, 75, arenaWidth, "center")
    love.graphics.setColor(0.58, 0.64, 0.78)
    love.graphics.printf("F11 FULLSCREEN   /   F2 CPU OR PVP   /   ESC PAUSE", 0, 91, arenaWidth, "center")

    local cardWidth = 202
    local cardGap = 18
    local startX = 49
    for i, character in ipairs(characters) do
        local x = startX + (i - 1) * (cardWidth + cardGap)
        local p1Selected = selectedCharacter[1] == i
        local p2Selected = not cpuEnabled and selectedCharacter[2] == i
        local selected = p1Selected or p2Selected
        local y = selected and 108 or 116
        local cardHeight = selected and 334 or 318

        love.graphics.setColor(0, 0, 0, 0.35)
        love.graphics.rectangle("fill", x + 5, y + 7, cardWidth, cardHeight, 12, 12)
        love.graphics.setColor(0.075, 0.085, 0.15, 0.96)
        love.graphics.rectangle("fill", x, y, cardWidth, cardHeight, 12, 12)
        if p1Selected or p2Selected then
            love.graphics.setFont(uiFont)
            if p1Selected then
                love.graphics.setColor(0.16, 0.46, 0.78, 0.92)
                love.graphics.rectangle("fill", x + 12, y + 13, 48, 20, 6, 6)
                love.graphics.setColor(1, 1, 1)
                love.graphics.printf("P1", x + 12, y + 17, 48, "center")
            end
            if p2Selected then
                love.graphics.setColor(0.68, 0.28, 0.18, 0.94)
                love.graphics.rectangle("fill", x + (p1Selected and 66 or 12),
                    y + 13, 48, 20, 6, 6)
                love.graphics.setColor(1, 1, 1)
                love.graphics.printf("P2", x + (p1Selected and 66 or 12),
                    y + 17, 48, "center")
            end
        end
        love.graphics.setColor(character.color[1], character.color[2],
            character.color[3], selected and 0.95 or 0.42)
        love.graphics.rectangle("line", x, y, cardWidth, cardHeight, 12, 12)
        love.graphics.rectangle("fill", x, y, cardWidth, 5, 12, 12)

        drawCharacterPortrait(character, x + cardWidth / 2, y + 100,
            selected and 0.90 or 0.82, selected)
        love.graphics.setFont(characterFont)
        love.graphics.setColor(character.accent)
        love.graphics.printf(character.name, x, y + 178, cardWidth, "center")
        love.graphics.setFont(uiFont)
        love.graphics.setColor(0.64, 0.68, 0.78)
        love.graphics.printf(character.title, x, y + 207, cardWidth, "center")
        love.graphics.setColor(0.82, 0.84, 0.90)
        love.graphics.printf(character.description, x + 16, y + 229,
            cardWidth - 32, "center")
        love.graphics.setColor(character.accent)
        love.graphics.printf("BONDS WITH " .. character.affinity,
            x + 16, y + 257, cardWidth - 32, "center")
        drawStat("HP", character.health, 120, x + 18, y + 278, 112, character.color)
        drawStat("SPD", character.speed, 325, x + 18, y + 296, 112, character.color)
        drawStat("PWR", character.power, 1.12, x + 18, y + 314, 112, character.color)

        if selected then
            love.graphics.setColor(character.accent)
            love.graphics.polygon("fill", x + cardWidth / 2 - 9, y - 10,
                x + cardWidth / 2 + 9, y - 10, x + cardWidth / 2, y - 1)
        end
    end

    local current = characters[selectedCharacter[1]]
    love.graphics.setColor(0.04, 0.05, 0.09, 0.92)
    love.graphics.rectangle("fill", 0, 448, arenaWidth, 92)
    love.graphics.setColor(current.color)
    love.graphics.rectangle("fill", 0, 448, arenaWidth, 2)
    love.graphics.setFont(characterFont)
    love.graphics.setColor(current.accent)
    love.graphics.print("P1  " .. current.name, 28, 458)
    love.graphics.setFont(uiFont)
    love.graphics.setColor(phoneConnected[1] and { 0.38, 1.00, 0.62 }
        or { 0.48, 0.52, 0.62 })
    love.graphics.print("P1 PHONE: " .. (phoneConnected[1] and "CONNECTED" or "WAITING"),
        28, 511)
    love.graphics.setColor(0.82, 0.86, 0.94)
    love.graphics.print("A / D  SELECT", 228, 470)
    love.graphics.print("J / ENTER  CONFIRM", 228, 490)
    if controllerQrCheckTimer <= 0 then
        refreshControllerQr(controllerQrImage == nil)
    end
    if controllerQrImage then
        love.graphics.setColor(1, 1, 1)
        love.graphics.draw(controllerQrImage, 390, 454, 0, 0.50, 0.50)
        love.graphics.setFont(uiFont)
        love.graphics.setColor(0.74, 0.82, 1)
        love.graphics.print("PHONE CONTROLLER", 472, 459)
        love.graphics.setColor(0.90, 0.94, 1)
        love.graphics.print("SCAN TO JOIN", 472, 478)
        love.graphics.setColor(0.62, 0.70, 0.85)
        love.graphics.printf(controllerQrUrl, 472, 499, 210, "left")
    end
    love.graphics.setColor(phoneConnected[2] and { 0.38, 1.00, 0.62 }
        or { 0.48, 0.52, 0.62 })
    love.graphics.printf("P2 PHONE: " .. (phoneConnected[2] and "CONNECTED" or "WAITING")
        .. (selectionReady[2] and "  /  READY" or ""), 700, 460, 230, "right")
    love.graphics.setColor(0.48, 0.54, 0.66)
    love.graphics.printf(cpuEnabled and "OPPONENT: CPU RANDOM"
        or "P2: ARROWS + N TO CONFIRM", 700, 483, 230, "right")
    love.graphics.setColor(0.55, 0.60, 0.72)
    love.graphics.printf("C MENU  /  ESC QUIT", 700, 508, 230, "right")
end

local function drawScrollingBackground()
    if FX.backgroundDraw(cameraX) then return end
    love.graphics.clear(0.08, 0.13, 0.26)
    for y = 0, floorY, 20 do
        local t = y / floorY
        love.graphics.setColor(0.08 + t * 0.16, 0.14 + t * 0.12,
            0.30 + t * 0.14)
        love.graphics.rectangle("fill", 0, y, arenaWidth, 20)
    end

    love.graphics.setColor(1, 0.72, 0.28, 0.18)
    love.graphics.circle("fill", 760 - cameraX * 0.04, 130, 72)
    for i = 0, 10 do
        local cloudX = i * 390 - cameraX * 0.16
        love.graphics.setColor(0.82, 0.88, 1, 0.24)
        love.graphics.ellipse("fill", cloudX, 112 + (i % 3) * 36, 72, 18)
        love.graphics.circle("fill", cloudX - 28, 105 + (i % 3) * 36, 22)
        love.graphics.circle("fill", cloudX + 20, 101 + (i % 3) * 36, 28)
    end

    for i = 0, 8 do
        local hillX = i * 520 - cameraX * 0.32
        love.graphics.setColor(0.12, 0.24, 0.30)
        love.graphics.polygon("fill", hillX - 220, floorY,
            hillX, 215 + (i % 2) * 45, hillX + 230, floorY)
        love.graphics.setColor(0.16, 0.34, 0.32)
        love.graphics.polygon("fill", hillX - 130, floorY,
            hillX + 60, 285 + (i % 3) * 18, hillX + 260, floorY)
    end
end

local function drawFlag()
    love.graphics.setColor(0.88, 0.90, 0.96)
    love.graphics.rectangle("fill", flagX, floorY - 205, 8, 205)
    love.graphics.setColor(1, 0.78, 0.18)
    love.graphics.circle("fill", flagX + 4, floorY - 212, 11)
    love.graphics.setColor(0.92, 0.18, 0.24)
    love.graphics.polygon("fill", flagX + 8, floorY - 195,
        flagX + 92, floorY - 168, flagX + 8, floorY - 138)
    love.graphics.setColor(1, 0.88, 0.34)
    love.graphics.printf("GOAL", flagX + 10, floorY - 186, 72, "center")
end

local function drawWorldScenery()
    love.graphics.setColor(0.10, 0.15, 0.20)
    love.graphics.rectangle("fill", 0, floorY, levelWidth, 80)
    love.graphics.setColor(0.29, 0.43, 0.44)
    love.graphics.rectangle("fill", 0, floorY, levelWidth, 8)
    for x = 0, levelWidth, 64 do
        love.graphics.setColor((x / 64) % 2 == 0 and { 0.12, 0.19, 0.24 }
            or { 0.14, 0.21, 0.27 })
        love.graphics.rectangle("fill", x, floorY + 8, 64, 34)
    end

    for _, pit in ipairs(pits) do
        love.graphics.setColor(0.015, 0.02, 0.04)
        love.graphics.rectangle("fill", pit.left, floorY - 2,
            pit.right - pit.left, 100)
        love.graphics.setColor(0.72, 0.18, 0.10, 0.45)
        for x = pit.left + 12, pit.right - 12, 24 do
            love.graphics.polygon("fill", x - 8, floorY + 70,
                x, floorY + 42, x + 8, floorY + 70)
        end
    end

    for _, platform in ipairs(platforms) do
        love.graphics.setColor(platform.moving and { 0.24, 0.70, 0.84 }
            or { 0.52, 0.42, 0.62 })
        love.graphics.rectangle("fill", platform.x, platform.y,
            platform.width, platform.height, 6, 6)
        love.graphics.setColor(0.82, 0.88, 1, 0.75)
        love.graphics.rectangle("line", platform.x + 2, platform.y + 2,
            platform.width - 4, platform.height - 4, 5, 5)
    end

    for _, spike in ipairs(spikes) do
        love.graphics.setColor(0.78, 0.82, 0.90)
        for x = spike.x, spike.x + spike.width - 16, 16 do
            love.graphics.polygon("fill", x, floorY,
                x + 8, floorY - 28, x + 16, floorY)
        end
    end

    for _, block in ipairs(levelBlocks) do
        local bumpOffset = block.bump > 0 and -8 * math.sin(block.bump / 0.22 * math.pi) or 0
        local y = block.y + bumpOffset
        love.graphics.setColor(block.hit and { 0.34, 0.30, 0.28 }
            or { 0.90, 0.54, 0.16 })
        love.graphics.rectangle("fill", block.x, y, 46, 46, 5, 5)
        love.graphics.setColor(block.hit and { 0.48, 0.44, 0.40 }
            or { 1, 0.78, 0.28 })
        love.graphics.rectangle("line", block.x + 3, y + 3, 40, 40, 4, 4)
        love.graphics.setFont(characterFont)
        love.graphics.printf(block.hit and "·" or "?", block.x, y + 8, 46, "center")
    end

    for _, mushroom in ipairs(mushrooms) do
        if not mushroom.collected then
            local colors = {
                MUSHROOM = { 0.96, 0.18, 0.18 }, SHIELD = { 0.24, 0.64, 1.00 },
                FIRE = { 1.00, 0.42, 0.08 }, BOOTS = { 0.38, 1.00, 0.52 },
                BOND = { 0.94, 0.42, 0.88 }, LIGHTNING = { 1.00, 0.90, 0.18 },
            }
            local labels = {
                MUSHROOM = "M", SHIELD = "S", FIRE = "F",
                BOOTS = "B", BOND = "*", LIGHTNING = "L",
            }
            love.graphics.setColor(colors[mushroom.kind] or colors.MUSHROOM)
            love.graphics.circle("fill", mushroom.x, mushroom.y, 19)
            love.graphics.setColor(1, 0.96, 0.88)
            love.graphics.circle("line", mushroom.x, mushroom.y, 16)
            love.graphics.setFont(uiFont)
            love.graphics.printf(labels[mushroom.kind] or "?",
                mushroom.x - 18, mushroom.y - 7, 36, "center")
        end
    end

    for _, fireball in ipairs(fireballs) do
        if fireball.active then
            love.graphics.setColor(1, 0.28, 0.08, 0.28)
            love.graphics.circle("fill", fireball.x, fireball.y, 21)
            love.graphics.setColor(1, 0.78, 0.20)
            love.graphics.circle("fill", fireball.x, fireball.y, 11)
        end
    end

    drawFlag()
end

local function powerStatus(fighter)
    local status = {}
    if fighter.mushroomTimer > 0 then table.insert(status, "GIANT") end
    if fighter.shieldHealth > 0 then table.insert(status, "SHIELD " .. fighter.shieldHealth) end
    if fighter.fireTimer > 0 then table.insert(status, "FIRE") end
    if fighter.bootsTimer > 0 then table.insert(status, "SPEED") end
    if fighter.bondCharmTimer > 0 then table.insert(status, "BOND") end
    if fighter.comebackBoost > 1 then table.insert(status, "COMEBACK") end
    return table.concat(status, "  /  ")
end

function love.draw()
    local screenWidth, screenHeight = love.graphics.getDimensions()
    local screenScale = math.min(screenWidth / arenaWidth, screenHeight / 540)
    local offsetX = (screenWidth - arenaWidth * screenScale) / 2
    local offsetY = (screenHeight - 540 * screenScale) / 2
    love.graphics.clear(0.015, 0.02, 0.045)
    love.graphics.push()
    love.graphics.translate(offsetX, offsetY)
    love.graphics.scale(screenScale, screenScale)
    if game.state == "character_select" then
        drawCharacterSelect()
        love.graphics.pop()
        FX.overlay()
        return
    end
    love.graphics.push()
    if screenShakeTimer > 0 then
        local shake = screenShakeStrength * screenShakeTimer / 0.38
        love.graphics.translate((love.math.random() * 2 - 1) * shake,
            (love.math.random() * 2 - 1) * shake)
    end
    love.graphics.setFont(uiFont)
    drawScrollingBackground()
    love.graphics.push()
    love.graphics.translate(arenaWidth / 2, floorY)
    love.graphics.scale(cameraZoom, cameraZoom)
    love.graphics.translate(-cameraCenterX, -floorY)
    drawWorldScenery()
    for _, animal in ipairs(animals) do
        drawAnimal(animal)
    end
    drawFighter(fighter1)
    drawFighter(fighter2)
    drawSpecialEffect(fighter1)
    drawSpecialEffect(fighter2)
    FX.world({fighters=fighters})
    love.graphics.pop()
    drawHealthBar(fighter1, 12, false, "F1")
    drawHealthBar(fighter2, arenaWidth - 12, true, "F2")
    drawSpecialHud(fighter1, 12, false, { "U", "I", "O", "P" })
    drawSpecialHud(fighter2, arenaWidth - 12, true, { "1", "2", "3", "4" })

    love.graphics.setColor(0.92, 0.94, 1)
    love.graphics.setFont(timerFont)
    love.graphics.printf(string.format("%02d", math.ceil(game.timeRemaining)),
        0, 0, arenaWidth, "center")
    love.graphics.setFont(uiFont)
    love.graphics.printf("3-LIFE FLAG RACE", 0, 34, arenaWidth, "center")

    if fighter1.combo > 0 then
        love.graphics.setColor(1, 0.86, 0.35)
        love.graphics.print(fighter1.combo .. " HIT COMBO", 12, 164)
    end
    if fighter2.combo > 0 then
        love.graphics.setColor(1, 0.86, 0.35)
        love.graphics.printf(fighter2.combo .. " HIT COMBO", arenaWidth - 192,
            164, 180, "right")
    end

    if game.state == "round_over" or game.state == "match_over"
        or game.state == "game_won" then
        love.graphics.setColor(1, 0.82, 0.25)
        love.graphics.setFont(resultFont)
        love.graphics.printf(game.result, 0, 190, arenaWidth, "center")
        love.graphics.setFont(uiFont)
        if game.state == "round_over" then
            love.graphics.setColor(0.92, 0.94, 1)
            love.graphics.printf("NEXT ROUND IN " .. math.ceil(game.transitionTimer),
                0, 245, arenaWidth, "center")
        elseif game.state == "match_over" then
            love.graphics.setColor(0.92, 0.94, 1)
            love.graphics.printf("RETURNING TO FIGHTER SELECT IN "
                .. math.max(0, math.ceil(game.transitionTimer)),
                0, 245, arenaWidth, "center")
        else
            love.graphics.setColor(0.92, 0.94, 1)
            love.graphics.printf("THE SHADOW ROAD IS CONQUERED!  /  R RESTART  /  C CHARACTERS",
                0, 245, arenaWidth, "center")
        end
    end

    love.graphics.setFont(uiFont)
    love.graphics.setColor(0.92, 0.94, 1)
    love.graphics.print("", 12, 12)
    local progressWidth = 230
    local progress = math.min(1, fighter1.x / flagX)
    local progress2 = math.min(1, fighter2.x / flagX)
    love.graphics.setColor(0.08, 0.09, 0.14, 0.88)
    love.graphics.rectangle("fill", arenaWidth / 2 - progressWidth / 2,
        52, progressWidth, 10, 5, 5)
    love.graphics.setColor(1, 0.72, 0.20)
    love.graphics.rectangle("fill", arenaWidth / 2 - progressWidth / 2,
        52, progressWidth * progress, 10, 5, 5)
    love.graphics.setColor(0.30, 0.72, 1.00)
    love.graphics.rectangle("fill", arenaWidth / 2 - progressWidth / 2,
        59, progressWidth * progress2, 3, 2, 2)
    love.graphics.setColor(0.94, 0.96, 1)
    love.graphics.printf("P1 " .. math.floor(progress * 100) .. "%  /  P2 "
        .. math.floor(progress2 * 100) .. "%",
        arenaWidth / 2 - 70, 65, 140, "center")
    love.graphics.printf("A D MOVE / W JUMP / S CROUCH / J K H ATTACK / L GUARD / E RIDE / U I O P SUPER",
        0, 516, arenaWidth, "center")
    if fighter1.mount then
        love.graphics.setColor(fighter1.mount.bonded and { 1, 0.86, 0.28 }
            or { 0.80, 0.84, 0.92 })
        love.graphics.print(fighter1.mount.kind
            .. (fighter1.mount.bonded and "  PERFECT BOND" or "  MOUNTED"), 12, 180)
    end
    if fighter1.mushroomTimer > 0 then
        love.graphics.setColor(1, 0.36, 0.20)
        love.graphics.print("SUPER SIZE  "
            .. string.format("%.1fs", fighter1.mushroomTimer), 12, 198)
    end
    if fighter2.mount then
        love.graphics.setColor(fighter2.mount.bonded and { 1, 0.86, 0.28 }
            or { 0.80, 0.84, 0.92 })
        love.graphics.printf(fighter2.mount.kind
            .. (fighter2.mount.bonded and "  PERFECT BOND" or "  MOUNTED"),
            arenaWidth - 212, 180, 200, "right")
    end
    if fighter2.mushroomTimer > 0 then
        love.graphics.setColor(1, 0.36, 0.20)
        love.graphics.printf("SUPER SIZE  "
            .. string.format("%.1fs", fighter2.mushroomTimer),
            arenaWidth - 212, 198, 200, "right")
    end
    love.graphics.setColor(1, 0.82, 0.30)
    love.graphics.print(powerStatus(fighter1), 12, 216)
    love.graphics.setColor(0.46, 0.82, 1)
    love.graphics.printf(powerStatus(fighter2), arenaWidth - 312, 216, 300, "right")
    love.graphics.pop()

    if screenFlashTimer > 0 then
        love.graphics.setColor(0.82, 0.94, 1, 0.28 * screenFlashTimer / 0.24)
        love.graphics.rectangle("fill", 0, 0, arenaWidth, 540)
    end
    if superBannerTimer > 0 then
        love.graphics.setFont(characterFont)
        love.graphics.setColor(0.72, 0.92, 1, math.min(1, superBannerTimer * 1.5))
        love.graphics.printf(superBannerText, 0, 174, arenaWidth, "center")
    end
    love.graphics.pop()
    FX.overlay()
end

-- Integration checks execute real combat, stage and audio code under LÖVE.
function love.load(args)
 if not args or args[1]~='--selftest' then return end
 local function check(v,msg)assert(v,msg);print('PASS '..msg)end
 applyCharacter(fighter1,1);applyCharacter(fighter2,3);resetRound()
 check(FX.background~=nil,'illustrated background loaded')
 for _,n in ipairs({'ember','tempest','warden','viper'})do check(FX.art[n] and FX.sheets[n] and FX.walks[n],n..' portrait and ten action poses loaded')end
 check(FX.animals.HORSE and FX.animals.BOAR,'illustrated mounts loaded')
 check(FX.music.arena_theme and FX.music.menu_theme,'both streaming music tracks loaded')
 local count=0;for _ in pairs(FX.sources)do count=count+1 end;check(count==17,'17 sound effect sources loaded')
 local f=fighter1;local d=fighter2
 f.health=f.maxHealth;d.blocking=false;d:takeDamage(25,10,f);check(d.health==d.maxHealth-25,'unblocked damage preserved')
 d.health=d.maxHealth;d.blocking=true;d:takeDamage(25,10,f);check(d.health==d.maxHealth-5,'guard reduces incoming damage')
 d.health=d.maxHealth;d:takeDamage(25,10,f,true);check(d.health==d.maxHealth-25,'low attack bypasses standing block')
 resetRound();f=fighter1;f.x=530;f.y=460;f.grounded=true
 FX.update(.016,{game=game,fighters=fighters});check(f.velocityY==-850 and not f.grounded,'spring launches fighter')
 resetRound();f=fighter1;f.x=1430;f.y=350;f.grounded=false;f.velocityY=100
 FX.update(.016,{game=game,fighters=fighters});check(f.velocityY<100,'wind lifts airborne fighter')
 resetRound();f=fighter1;f.x=850;f.y=460;f.health=40;f.facing=1;f.specialCooldowns={7,8,9,10}
 for i=1,3 do f.attack={phase='active',kind='high'};FX.update(.41,{game=game,fighters=fighters})end
 check(FX.gimmicks[2].hp==0 and f.health==58 and f.specialCooldowns[1]==3,'crystal breaks once and restores health/cooldowns')
 FX.update(.41,{game=game,fighters=fighters});check(f.health==58,'destroyed crystal cannot be farmed')
 resetRound();f=fighter1;f.x=3080;f.grounded=true;FX.update(.016,{game=game,fighters=fighters});check(f.shieldHealth==30,'altar grants shield')
 local cd=FX.gimmicks[7].cool;f.shieldHealth=0;FX.update(.1,{game=game,fighters=fighters});check(f.shieldHealth==0 and FX.gimmicks[7].cool<cd,'altar cooldown prevents repeated reward')
 resetRound();check(FX.gimmicks[2].hp==3 and FX.gimmicks[7].cool==0,'restart resets stage gimmicks')
 for i=1,4 do resetRound();check(fighter1:startSpecial(i),'super '..i..' starts');check(fighter1.specialCooldowns[i]>0,'super '..i..' cooldown');end
 FX.key('escape');local old=fighter1.x;love.update(.016);check(fighter1.x==old,'pause freezes gameplay');FX.key('escape')
 updatePhoneControls(.1);check(cpuEnabled,'CPU stays on with no second phone')
 local canvas=love.graphics.newCanvas(960,540);love.graphics.setCanvas(canvas)
 for i=1,4 do applyCharacter(fighter1,i);for _,pose in ipairs({'idle','high','low','crouch','jump','hit','walk','ride','block'})do
  fighter1:reset();fighter1.x=300
  if pose=='high'or pose=='low'then fighter1.attack={phase='active',kind=pose}
  elseif pose=='crouch'then fighter1.crouching=true elseif pose=='jump'then fighter1.grounded=false
  elseif pose=='hit'then fighter1.hitFlash=.1 elseif pose=='walk'then fighter1._oldDrawX=290
  elseif pose=='ride'then fighter1.mount={bonded=false} elseif pose=='block'then fighter1.blocking=true end
  check(FX.fighter(fighter1),'render '..characters[i].name..' '..pose)
 end end
 love.graphics.setCanvas();print('ALL INTEGRATION CHECKS PASSED');love.event.quit(0)
end
