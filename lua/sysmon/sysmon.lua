local M = {}

-- Default configuration
local config = {
	update_interval = 2000, -- Default 2 Seconds
	use_icons = false,   -- Do not use icons by default
}

local icons = {
	cpu = "",
	mem = "",
	temp = "",
}

-- Cached values to avoid unnecessary updates
local cached_cpu, cached_mem, cached_temp = "", "", ""
local timer = nil -- Timer to fire information fetching to continue when cursor stands still

-- Utility function to run shell commands asynchronously
local function run_command(cmd, callback)
	local stdout = vim.loop.new_pipe(false)
	local stderr = vim.loop.new_pipe(false)
	local handle

	handle = vim.loop.spawn("bash", {
		args = { "-c", cmd },
		stdio = { nil, stdout, stderr },
	}, function()
		stdout:read_stop()
		stderr:read_stop()
		stdout:close()
		stderr:close()
		handle:close()
	end)

	stdout:read_start(function(_, data)
		if data then
			callback(data)
		end
	end)

	stderr:read_start(function(_, data)
		if data then
			vim.notify("Error: " .. data, vim.log.levels.ERROR)
		end
	end)
end

-- Trim whitespace
local function trim(str)
	return str:match("^%s*(.-)%s*$") or ""
end

-- Update system stats (throttled by a 5-second interval)
function M.update_sys()
	-- Fetch CPU usage
	run_command("top -bn1 | grep 'Cpu(s)' | sed 's/.*, *\\([0-9.]*\\)%* id.*/\\1/' | awk '{print 100 - $1}'",
		function(cpu)
			if config.use_icons then
				-- TODO: Use icons
				cached_cpu = icons.cpu .. " " .. trim(cpu) .. "%%"
			else
				cached_cpu = "CPU: " .. trim(cpu) .. "%%"
			end
		end)

	-- Fetch memory usage
	run_command("free -m | awk 'NR==2{printf \"%.2f/%.2f GB\", $3/1024,$2/1024 }'", function(mem)
		if config.use_icons then
			cached_mem = icons.mem .. " " .. trim(mem)
		else
			cached_mem = "Mem: " .. trim(mem)
		end
	end)

	-- Fetch system temperature
	run_command("sensors | awk '/^CPU:/{print $2}'", function(temp)
		if config.use_icons then
			cached_temp = icons.temp .. " " .. trim(temp)
		else
			cached_temp = "Temp: " .. trim(temp)
		end
	end)
end

-- Return system stats for the statusline
function M.update_statusline()
	return table.concat({ cached_cpu, cached_mem, cached_temp }, " | ")
end

function M.start_timer()
	if timer == nil then
		timer = vim.loop.new_timer()
		timer:start(0, config.update_interval, vim.schedule_wrap(function()
			M.update_sys()
		end))
	end
end

function M.stop_timer()
	if timer then
		timer:stop()
		timer:close()
		timer = nil
	end
end

-- Plugin setup
function M.setup(user_config)
	-- Merge user config with default
	config = vim.tbl_deep_extend("force", config, user_config or {})

	-- Start timer with updated config
	M.start_timer()
end

return M
