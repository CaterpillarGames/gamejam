pico-8 cartridge // http://www.pico-8.com
version 35
__lua__
--{GAMENAME}
--{AUTHORINFO} 

--[[
# Embed: 750 x 680
game_name: XXXXX
# Leave blank to use game-name
game_slug: 
trijam_number: XX
trijam_theme: XX
tagline: XXXXXXXX
time_left: 'X:XX:XX'
develop_time: ''
description: |
  XXXX
controls: |
  * XXXX
hints: ''
acknowledgements: ''
todo: ''
version: 0.1.0
img_alt: XXXX
about_extra: ''
--]]

gs = nil

dirs = {
	left = 0,
	right = 1,
	up = 2,
	down = 3,
	z = 4,
	x = 5
}

gameOverWin = 'win'
gameOverLose = 'lose'

poke(0x5f2d, 0x1 | 0x2)

function _init()
	gs = {
		dt = 1/30,
		isGameOver = false,
		gameOverState = nil,
		startTime = t(),
		endTime = nil,
		currentAnimation = nil,
		cursor = makeCursor(),
		base = makeBase(),
		reserveTowers = {
			makeTower(8, 116, towerTypes.standard),
			makeTower(20, 116, towerTypes.short),
			makeTower(32, 116, towerTypes.long),
		},
		towers = {
			--makeTower(32, 64, towerTypes.standard)
		},
		enemies = {
			--makeEnemy(44, 3, enemyTypes.paralegal),
			--makeEnemy(44, 48, enemyTypes.judge)
		},
		projectiles = {},
		waves = makeWaves(),
		waveNumber = 0,
		maxAllowedTowers = 2,
		canGrabTower = function(self, tower)
			return #self.towers < self.maxAllowedTowers
		end
	}

end


-- enemies is an array of a sequence of moves
function makeWaves()
	local ret = {
		{
			maxAllowedTowers = 1,
			enemies = {
				enemyTypes.paralegal
			}
		},

		{
			maxAllowedTowers = 2,
			enemies = {
				enemyTypes.paralegal,
				enemyTypes.paralegal,
				enemyTypes.judge
			}
		},

		{
			maxAllowedTowers = 4,
			enemies = {
				enemyTypes.paralegal,
				80,
				enemyTypes.paralegal,
				90,
				enemyTypes.judge,
				90,
				enemyTypes.judge
			}
		}
	}
	return ret
end

function makeCursor()
	return {
		pos = vec2(64, 64),
		graspedEntity = nil,
		isLeadingClick = false,
		clickedThisFrame = false,
		clickedLastFrame = false,
		update = function(self) 
			self.clickedThisFrame = (stat(34) & 0x1) > 0 or btn(dirs.x) 
			self.isLeadingClick = self.clickedThisFrame and not self.clickedLastFrame
			self.clickedLastFrame = self.clickedThisFrame
			self.pos = vec2(
				stat(32), stat(33))

			if self.graspedEntity == nil then
				local hovered = self:getHoveredTower()
				if hovered != nil then
					if self.isLeadingClick and gs:canGrabTower(hovered) then
						self.graspedEntity = hovered:clone()
					end
				end
			else
				self.graspedEntity.pos = self.pos:clone()
				if self.isLeadingClick then
					add(gs.towers, self.graspedEntity)
					self.graspedEntity = nil
				end
			end

		end,
		getHoveredTower = function(self)
			for tower in all(gs.reserveTowers) do
				if tower.pos:isWithin(self.pos, 10) then
					return tower
				end
			end
			return nil
		end,
		draw = function(self)
			if self.graspedEntity != nil then
				self.graspedEntity:draw()
			end
			local hovered = self:getHoveredTower()
			if hovered != nil then
				local outlineColor = 8
				if gs:canGrabTower(hovered) then
					outlineColor = 7
				end
				rect(hovered.pos.x - 2, hovered.pos.y - 3, hovered.pos.x + 10, hovered.pos.y + 9, outlineColor)
			end
			local spriteNumber = 16
			if self.graspedEntity != nil then
				spriteNumber = 17
			end
			spr(spriteNumber, self.pos.x - 4, self.pos.y - 4)
		end
	}
end

		-- speed = type.movementSpeed, --40,
		-- health = type.health,
		-- attackStrength = type.attackStrength,
		-- attackCooldown = type.attackCooldown,

enemyTypes = {
	paralegal = {
		name = 'paralegal',
		attackCooldown = 10,
		attackStrength = 2,
		movementSpeed = 20,
		health = 40,
		spriteNumber = 4
	},
	judge = {
		name = 'judge',
		attackCooldown = 10,
		attackStrength = 5,
		movementSpeed = 40,
		health = 100,
		spriteNumber = 6
	}
}

towerTypes = {
	standard = {
		name = 'standard',
		attackCooldown = 10,
		attackStrength = 20,
		targetRange = 75,
		projectileSpeed = 40,
		projectileSpriteNumber = 8,
		towerSpriteNumber = 1
	},
	long = {
		name = 'long',
		attackCooldown = 20,
		attackStrength = 20,
		targetRange = 200,
		projectileSpeed = 150,
		projectileSpriteNumber = 24,
		towerSpriteNumber = 3
	},
	short = {
		name = 'short',
		attackCooldown = 20,
		attackStrength = 60,
		targetRange = 40,
		projectileSpeed = 40,
		projectileSpriteNumber = 9,
		towerSpriteNumber = 2
	}
}

function makeTower(x, y, type)
	assert(type != nil)
	return {
		isModel = false,
		pos = vec2(x,y),
		clone = function(self)
			return makeTower(self.pos.x, self.pos.y, self.type)
		end,
		type = type,
		targetRange = type.targetRange,
		towerSpriteNumber = type.towerSpriteNumber,
		attackStrength = type.attackStrength,
		attackCooldown = type.attackCooldown,
		attackCountdown = 0,
		projectileSpeed = type.projectileSpeed,
		theta = 0,
		omega = 0.01,
		lockedOnEnemy = nil,
		setEnemyLock = function(self)
			-- TODO
			--self.lockedOnEnemy = gs.enemies[1]
			local targetEnemy = nil
			local distance = nil
			for enemy in all(self:getEnemiesInRange()) do
				local curDist = self.pos:eucDist(enemy.pos)
				if targetEnemy == nil then
					targetEnemy = enemy
					distance = curDist
				else
					if curDist > distance and self.type.name == towerTypes.long.name then
						targetEnemy = enemy
						distance = curDist
					elseif curDist < distance then
						targetEnemy = enemy
						distance = curDist
					end
				end
			end
			self.lockedOnEnemy = targetEnemy
		end,
		getEnemiesInRange = function(self)
			local ret = {}
			for enemy in all(gs.enemies) do
				if self.pos:isWithin(enemy.pos, self.targetRange) then
					add(ret, enemy)
				end
			end
			return ret
		end,
		targetTheta = function(self)
			if self.isModel then
				return 0
			end
			local enemy = self.lockedOnEnemy
			if enemy == nil then
				return 0
			end
			return atan2(enemy.pos.x - self.pos.x, enemy.pos.y - self.pos.y)
		end,
		update = function(self)
			self:setEnemyLock()
			self.attackCountdown = max(0, self.attackCountdown - 1)
			-- local dtheta = self:targetTheta() - self.theta
			-- if abs(dtheta) > self.omega then
			-- 	dtheta = self.omega * sgn(dtheta)
			-- end
			-- self.theta += dtheta
			self.theta = self:targetTheta()

			if self.lockedOnEnemy != nil then
				self:tryAttack(self.lockedOnEnemy)
			end
		end,
		tryAttack = function(self, enemy)
			if self.isModel then
				return
			end
			if self.attackCountdown > 0 then
				return
			end
			self:launchProjectile(enemy.pos)
			self.attackCountdown = self.attackCooldown			
		end,
		launchProjectile = function(self, targetVec2)
			local proj = makeProjectile(
				self.pos + vec2fromAngle(self.theta) * 10, 
				vec2fromAngle(self.theta) * self.projectileSpeed, 
				self.attackStrength,
				self.type.projectileSpriteNumber)
			add(gs.projectiles, proj)
		end,
		draw = function(self)
			spr(self.spriteNumber, self.pos.x-2, self.pos.y)
			local perp = vec2fromAngle(self.theta + 0.25)
			local lineStart = self.pos - perp * 4
			local lineEnd = lineStart + 8 * vec2fromAngle(self.theta)

			useYellowTransparency()
			for i = 0, 7 do
				tline(lineEnd.x, lineEnd.y,
					lineStart.x, lineStart.y,
						self.towerSpriteNumber + i/8, 0,
						0, 
						1/8)
				tline(lineEnd.x+1, lineEnd.y,
					lineStart.x+1, lineStart.y, 
						self.towerSpriteNumber + i/8, 0,
						0, 
						1/8)
				lineStart += perp
				lineEnd += perp
			end
			palt()
			-- line(self.pos.x, self.pos.y, tipLocation.x, tipLocation.y, 7)



		end
	}
end

function makeProjectile(pos, vel, attackStrength, spriteNumber)
	return {
		pos = pos,
		vel = vel,
		isDead = false,
		attackStrength = attackStrength,
		spriteNumber = spriteNumber,
		maxAge = 60,
		age = 0,
		draw = function(self)
			if self.spriteNumber == 24 then
				local lineEnd = self.pos + self.vel / 20
				line(self.pos.x, self.pos.y, lineEnd.x, lineEnd.y, 12)
			else
				spr(self.spriteNumber, self.pos.x - 4, self.pos.y - 4)
			end
			--print('O', self.pos.x, self.pos.y, 7)
		end,
		getInRangeEnemy = function(self)
			for enemy in all(gs.enemies) do
				if self.pos:isWithin(enemy.pos, 10) then
					return enemy
				end
			end
			return nil
		end,
		update = function(self)
			self.age += 1
			if self.age > self.maxAge then
				self.isDead = true
			end	

			self.pos += self.vel * gs.dt
			local enemy = self:getInRangeEnemy()
			if enemy != nil then
				enemy:takeDamage(self.attackStrength)
				self.isDead = true
			end
		end
	}
end

function useYellowTransparency()
	palt(0, false)
	palt(10, true)
end

function makeBase()
	return {
		pos = vec2(64, 100),
		health = 100,
		draw = function(self)
			--print('base', self.pos.x, self.pos.y, 7)
			useYellowTransparency()
			spr(10, self.pos.x, self.pos.y, 2, 2)
			palt()
			print(self.health, self.pos.x, self.pos.y + 20, 7)
		end,
		isDead = false,
		takeDamage = function(self, amount)
			self.health -= amount
			if self.health <= 0 then
				self.isDead = true
			end
		end,
		update = function(self) 
		end
	}
end

function rndrange(_min, _max)
	local diff = _max - _min
	return _min + diff * rnd()
end

metaTable = {
	__add = function(v1, v2)
		return vec2(v1.x + v2.x, v1.y + v2.y)
	end,
	__sub = function(v1, v2)
		return vec2(v1.x - v2.x, v1.y - v2.y)
	end,
	__mul = function(s, v)
		if type(s) == 'table' then
			s,v = v,s
		end

		return vec2(s * v.x, s * v.y)
	end,
	__div = function(v, s)
		return vec2(v.x / s, v.y / s)
	end,
	__eq = function(v1, v2)
		return v1.x == v2.x and v1.y == v2.y
	end
}

function vec2fromAngle(ang)
	return vec2(cos(ang), sin(ang))
end

function vecFromDir(dir)
	if dir == dirs.left then
		return vec2(-1, 0)
	elseif dir == dirs.right then
		return vec2(1, 0)
	elseif dir == dirs.up then
		return vec2(0, -1)
	elseif dir == dirs.down then
		return vec2(0, 1)
	else
		assert(false)
	end
end

function modInc(x, mod)
	return (x + 1) % mod
end

function modDec(x, mod)
	return (x - 1) % mod
end

function vec2(x, y)
	local ret = {
		x = x,
		y = y,

		norm = function(self)
			return vec2fromAngle(atan2(self.x, self.y))
		end,
		squareDist = function(self, other)
			return max(abs(self.x - other.x), abs(self.y - other.y))
		end,
		taxiDist = function(self, other)
			return abs(self.x - other.x) + abs(self.y - other.y)
		end,
		-- Beware of using this on vectors that are more than 128 away
		eucDist = function(self, other)
			local dx = self.x - other.x
			local dy = self.y - other.y
			return sqrt(dx * dx + dy * dy)
			--return approx_magnitude(dx, dy)
		end,
		isWithin = function(self, other, value)
			return self:taxiDist(other) <= value and
				self:eucDist(other) <= value
		end,
		isOnScreen = function(self, extra)
			if extra == nil then extra = 0 end

			return extra <= self.x and self.x <= 128 - extra
				and extra <= self.y and self.y <= 128 - extra
		end,
		length = function(self)
			return self:eucDist(vec2(0, 0))
		end,
		angle = function(self)
			return atan2(self.x, self.y)
		end,
		clone = function(self)
			return vec2(self.x, self.y)
		end
	}

	setmetatable(ret, metaTable)

	return ret
end


function hasAnimation()
	return gs.currentAnimation != nil and costatus(gs.currentAnimation) != 'dead'
end

function acceptInput()

end

function _update()
	if gs.isGameOver then
		if gs.endTime == nil then
			gs.endTime = t()
		end
		-- Restart
		if btnp(dirs.x) then
			_init()
		end
		return
	end

	-- if hasAnimation() then
	-- 	return
	-- end

	acceptInput()

	for enemy in all(gs.enemies) do
		enemy:update()
	end

	for tower in all(gs.towers) do
		tower:update()
	end

	for proj in all(gs.projectiles) do
		proj:update()
	end

	clearDead()

	gs.base:update()

	checkGameOver()

	gs.cursor:update()

	checkNextWave()

	--checkTowerGrasping()
end

function checkNextWave()
	if hasAnimation() then
		return
	end
	if #gs.enemies == 0 then
		gs.currentAnimation = cocreate(function()
			gs.waveNumber += 1
			if gs.waveNumber > #gs.waves then
				return
			end

			local wave = gs.waves[gs.waveNumber]

			for i = 1, 20 do
				print('wave number ' .. gs.waveNumber, 50, 50, 7)
				yield()
			end
			
			gs.maxAllowedTowers = wave.maxAllowedTowers
			--print()
			--assert(wave[1] != nil)

			for entry in all(wave.enemies) do

				if type(entry) == 'number' then
					for i = 0, entry do
						yield()
					end
				else
					add(gs.enemies, makeEnemy(44, 3, entry))
				end
			end
		end)
	end
end

-- function checkTowerGrasping()
-- 	if gs.cursor.isLeadingClick then

-- 	end
-- end

function checkGameOver()
	if gs.base.isDead then
		gs.gameOverState = 'lose'
		gs.isGameOver = true
	elseif gs.waveNumber > #gs.waves then
		gs.gameOverState = 'win'
		gs.isGameOver = true
	end

end

function clearDead()
	for enemy in all(gs.enemies) do
		if enemy.isDead then
			del(gs.enemies, enemy)
		end
	end
	for proj in all(gs.projectiles) do
		if proj.isDead then
			del(gs.projectiles, proj)
		end
	end
end

function drawGameOverWin()
	print('you won!')
end

function drawGameOverLose()
	print('you lost!')
end

function makeEnemy(x, y, type)
	return {
		duration = 0,
		type = type,
		pos = vec2(x, y),
		velDir = vec2(0, 1),
		speed = type.movementSpeed, --40,
		health = type.health,
		attackStrength = type.attackStrength,
		attackCooldown = type.attackCooldown,
		attackCountdown = 0,
		spriteNumber = type.spriteNumber,
		age = 0,
		isInRange = function(self)
			return gs.base.pos:isWithin(self.pos, 15)
		end,
		update = function(self)
			self.attackCountdown = max(self.attackCountdown - 1, 0)
			if not self:isInRange() then
				self.age += 1
				--self.pos += vec2(0, 10) * gs.dt
				--local newPos = self.pos + self.velDir * self.speed * gs.dt
				local newPos = self.pos + self.velDir * 4

				local spriteThere = mget(newPos.x/8, newPos.y/8)
				if fget(spriteThere, 0) then
					self.pos += self.velDir * self.speed * gs.dt
				else
					if self.velDir == vec2(0, 1) then
						local spriteThere2 = mget(self.pos.x/8 + 1, self.pos.y/8)
						if fget(spriteThere2, 0) then
							self.velDir = vec2(1, 0)
						else
							self.velDir = vec2(-1, 0)
						end
					elseif self.velDir == vec2(1, 0) or self.velDir == vec2(-1, 0) then
						self.velDir = vec2(0, 1)
					end
				end
			else
				self:tryAttack()
			end
		end,
		tryAttack = function(self)
			if self.attackCountdown > 0 then
				return
			end
			gs.base:takeDamage(self.attackStrength)
			self.attackCountdown = self.attackCooldown
		end,
		isDead = false,
		takeDamage = function(self, amount)
			self.health -= amount
			if self.health <= 0 then
				self.isDead = true
			end
		end,
		walkIndex = function(self)
			return (self.age \ 15)%2
		end,
		draw = function(self)
			local spriteNumber = self.spriteNumber
			if self:walkIndex() == 1 then
				spriteNumber += 1
			end
			useYellowTransparency()
			spr(spriteNumber, self.pos.x -4, self.pos.y-4)
			-- local text = 'enemy'
			-- if self:walkIndex() == 1 then
			-- 	text = 'ENEMY'
			-- end
			-- print(text, self.pos.x, self.pos.y, 7)
			print(self.health, self.pos.x, self.pos.y+6, 7)
			palt()
		end
	}

end

function _draw()
	cls(9)
	if gs.isGameOver then
		if gs.gameOverState == gameOverWin then
			drawGameOverWin()
		else
			drawGameOverLose()
		end
		return
	end

	map(0, 0, 0, 0, 128, 128, 1)

	gs.base:draw()
	for enemy in all(gs.enemies) do
		enemy:draw()
	end
	for tower in all(gs.towers) do
		tower:draw()
	end
	for tower in all(gs.reserveTowers) do
		tower:draw()
	end
	for proj in all(gs.projectiles) do
		proj:draw()
	end

	gs.cursor:draw()

	if hasAnimation() then
		local active, exception = coresume(gs.currentAnimation)
		if exception then
			stop(trace(gs.currentAnimation, exception))
		end
	end

	-- Draw
end


__gfx__
00056000aaaeeaaa88888888aaaddaaaaa0000aaaa0000aaaa0000aaaa0000aa0000000000000000aaaaaaa66666aaaa00000000000000000000000000000000
00666c00aaaeeaaaa888888aaaadaaaaaa0fffaaaa0fffaaaa0fffaaaa0fffaa00000000000cc000aaaaaa6665656aaa00000000000000000000000000000000
00666c00aaaeeaaaa888cc8aaaadaaaaaaffffaaaaffffaaaaffffaaaaffffaa0000c00000cccc00aaaaaa66565656aa00000000000000000000000000000000
006660c0aaeeeeaaa888cc8aaaadaaaaa000780aa000780aa007700aa007700a0000c0000cccccc0aaaaaa666565656a00000000000000000000000000000000
00056660aaeeceaaa88ccc8aaaadaaaa0a0078a0a000780a0a0770a0a007700a000ccc000cccccc0aaaaaaa66656566a00000000000000000000000000000000
00056cc0aaeeceaaa88ccc8aaaaddaaaaa0077aaaa0077aaaa0000aaaa0000aa000ccc0000cccc006aaaaaac666666aa00000000000000000000000000000000
00666cc0aaeeeeaaa888888aaadcddaaaa0000aaaa0000aaaa0000aaaa0000aa0000c000000cc0006666aaaac6666aaa00000000000000000000000000000000
06666cc0aaaeeaaaaa0000aaaaddddaaaa0aa0aaa0aaaa0aaa0000aaaa0000aa0000000000000000acccacaca56aaaaa00000000000000000000000000000000
00010000000000000000000000000000aa0000aaaaaaaaaa00000000000000000000000c66666666accccacaa56aaaaa00000000000000000000000000000000
00171000001110000000000000000000aa0fffaaaa0000aa0000000000000000000000c0666566d6acccaaaaa56aaaa600000000000000000000000000000000
00171100017771000000000000000000aaffffaaaa0fffaa000000000000000000000c0066666666acccaaaa6666aa6a00000000000000000000000000000000
00177f1001177f100000000000000000a007700aaaffffaa00000000000000000000c000666665666ccca66a6666aa6a00000000000000000000000000000000
01777f1017177f1000000000000000000a0770a0a007700a0000000000000000000c0000666666666ccc6aa666666a6a00000000000000000000000000000000
01777f1017777f100000000000000000aa0000aaa007700a000000000000000000c00000666656666ccc66666666666600000000000000000000000000000000
001fff1001ffff100000000000000000aa0000aaaa0000aa00000000000000000c000000d6666666666666605666668600000000000000000000000000000000
00011100001111000000000000000000aa0000aaa000000a0000000000000000c000000066666666666666605666666600000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000a0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__gff__
0000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__map__
0001020300190000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000190000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000191919191919191900000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000001900000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000019191919191919191900000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000019000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000019191919191919191919000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000019000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000019191919191919000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000019000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000019000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000019000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000019000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
