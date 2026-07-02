-- Pure git-remote-URL -> permalink logic, with zero dependency on the `vim`
-- global. Kept separate from copy.lua (which wires this up to a keymap and
-- shells out to git) so it can be unit tested with plain `busted`, no nvim
-- process required. See tests/permalink_spec.lua.

local M = {}

-- Normalize a git remote URL (ssh, scp-like, or https) into a host + path pair.
-- Returns nil, error_message on failure.
---@param remote_url string
---@return string? host
---@return string? path_or_err path on success, error message on failure
function M.parse_remote_url(remote_url)
  local host, path = remote_url:match '^ssh://[^@]+@([^/:]+)[:%d]*/(.+)$'
  if not host then
    host, path = remote_url:match '^[%w_.-]+@([^:]+):(.+)$'
  end
  if not host then
    -- user@host form must be tried before bare host: with plain `[^@/]+@?([^/]+)`
    -- Lua's greedy-with-backtracking `+` would consume the whole host into the
    -- first group and backtrack the second group down to a single character.
    host, path = remote_url:match '^https?://[^@]+@([^/]+)/(.+)$'
  end
  if not host then
    host, path = remote_url:match '^https?://([^/]+)/(.+)$'
  end
  if not host then
    return nil, 'Could not parse remote URL: ' .. remote_url
  end
  return host, (path:gsub('%.git$', ''))
end

-- GitLab uses '/-/blob/<sha>/path', GitHub (and GitHub Enterprise) use '/blob/<sha>/path'.
---@param host string
---@return string
function M.blob_segment(host)
  local h = host:lower()
  if h:find 'github%.com' then
    return '/blob/'
  end
  return '/-/blob/' -- default to GitLab's convention (also correct for self-hosted GitLab)
end

---@param remote_url string
---@param sha string
---@param relative_path string
---@param line integer
---@return string? url
---@return string? err
function M.build_url(remote_url, sha, relative_path, line)
  local host, path = M.parse_remote_url(remote_url)
  if not host then
    return nil, path -- path holds the error message in this branch
  end
  return string.format('https://%s/%s%s%s/%s#L%d', host, path, M.blob_segment(host), sha, relative_path, line)
end

return M
