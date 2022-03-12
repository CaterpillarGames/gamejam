pico-8 cartridge // http://www.pico-8.com
version 18
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
		towers = {
			makeTower(32, 64, towerTypes.standard)
		},
		enemies = {
			makeEnemy(64, 20)
		},
		projectiles = {}
	}
end

function makeCursor()
	return {
		pos = vec2(64, 64),
		update = function(self) 
			self.pos = vec2(
				stat(32), stat(33))
		end,
		draw = function(self)
			spr(0, self.pos.x - 4, self.pos.y - 4)
		end
	}
end

towerTypes = {
	standard = {
		name = 'standard',
		attackCooldown = 10,
		attackStrength = 2,
		projectileSpeed = 40
	},
	long = {
		name = 'long',
		attackCooldown = 10,
		attackStrength = 2,
		projectileSpeed = 40
	},
	short = {
		name = 'short',
		attackCooldown = 10,
		attackStrength = 2,
		projectileSpeed = 40
	}
}

function makeTower(x, y, type)
	assert(type != nil)
	return {
		pos = vec2(x,y),
		type = type,
		attackStrength = type.attackStrength,
		attackCooldown = type.attackCooldown,
		attackCountdown = 0,
		projectileSpeed = type.projectileSpeed,
		theta = 0,
		omega = 0.01,
		lockedOnEnemy = nil,
		setEnemyLock = function(self)
			-- TODO
			self.lockedOnEnemy = gs.enemies[1]
		end,
		targetTheta = function(self)
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
			if self.attackCountdown > 0 then
				return
			end
			self:launchProjectile(enemy.pos)
			self.attackCountdown = self.attackCooldown			
		end,
		launchProjectile = function(self, targetVec2)
			local proj = makeProjectile(
				self.pos, 
				vec2fromAngle(self.theta) * self.projectileSpeed, 
				self.attackStrength,
				0)
			add(gs.projectiles, proj)
		end,
		draw = function(self)
			local tipLocation = self.pos + 10 * vec2fromAngle(self.theta)
			line(self.pos.x, self.pos.y, tipLocation.x, tipLocation.y, 7)
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
		draw = function(self)
			print('O', self.pos.x, self.pos.y, 7)
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
			self.pos += self.vel * gs.dt
			local enemy = self:getInRangeEnemy()
			if enemy != nil then
				enemy:takeDamage(self.attackStrength)
				self.isDead = true
			end
		end
	}
end

function makeBase()
	return {
		pos = vec2(64, 100),
		health = 100,
		draw = function(self)
			print('base', self.pos.x, self.pos.y, 7)
			print(self.health, self.pos.x, self.pos.y + 10, 7)
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

	if hasAnimation() then
		local active, exception = coresume(gs.currentAnimation)
		if exception then
			stop(trace(gs.currentAnimation, exception))
		end

		return
	end

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
end

function checkGameOver()
	if gs.base.isDead then
		gs.gameOverState = 'lose'
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

end

function drawGameOverLose()
	print('you lost!')
end

function makeEnemy(x, y)
	return {
		duration = 0,
		pos = vec2(x, y),
		age = 0,
		isInRange = function(self)
			return gs.base.pos:isWithin(self.pos, 15)
		end,
		update = function(self)
			self.attackCountdown = max(self.attackCountdown - 1, 0)
			if not self:isInRange() then
				self.age += 1
				self.pos += vec2(0, 20) * gs.dt
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
		health = 10,
		attackStrength = 1,
		attackCooldown = 10,
		attackCountdown = 0,
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
			local text = 'enemy'
			if self:walkIndex() == 1 then
				text = 'ENEMY'
			end
			print(text, self.pos.x, self.pos.y, 7)
			print(self.health, self.pos.x, self.pos.y+6, 7)
		end
	}

end

function _draw()
	cls(0)
	if gs.isGameOver then
		if gs.gameOverState == gameOverWin then
			drawGameOverWin()
		else
			drawGameOverLose()
		end
		return
	end

	gs.base:draw()
	for enemy in all(gs.enemies) do
		enemy:draw()
	end
	for tower in all(gs.towers) do
		tower:draw()
	end
	for proj in all(gs.projectiles) do
		proj:draw()
	end

	gs.cursor:draw()
	-- Draw
end

__gfx__
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00700700000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00077000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00077000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00700700000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
