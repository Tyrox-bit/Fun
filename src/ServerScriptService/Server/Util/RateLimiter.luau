-- Token-bucket rate limiter per player. Every client->server remote uses one.

local Players = game:GetService("Players")

local RateLimiter = {}
RateLimiter.__index = RateLimiter

local limiters = {}

Players.PlayerRemoving:Connect(function(player)
	for _, limiter in limiters do
		limiter._buckets[player] = nil
	end
end)

-- capacity: burst size, refillPerSecond: sustained rate
function RateLimiter.new(capacity: number, refillPerSecond: number)
	local self = setmetatable({
		_capacity = capacity,
		_refill = refillPerSecond,
		_buckets = {},
	}, RateLimiter)
	table.insert(limiters, self)
	return self
end

function RateLimiter:Allow(player: Player, cost: number?): boolean
	local price = cost or 1
	local now = os.clock()
	local bucket = self._buckets[player]
	if not bucket then
		bucket = { tokens = self._capacity, time = now }
		self._buckets[player] = bucket
	end
	bucket.tokens = math.min(self._capacity, bucket.tokens + (now - bucket.time) * self._refill)
	bucket.time = now
	if bucket.tokens < price then
		return false
	end
	bucket.tokens -= price
	return true
end

return RateLimiter
