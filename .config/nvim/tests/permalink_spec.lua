local permalink = require 'custom.settings.permalink'

describe('permalink.parse_remote_url', function()
  it('parses scp-like ssh urls (git@host:path)', function()
    local host, path = permalink.parse_remote_url 'git@github.com:ashvinsharma/dotfiles.git'
    assert.equals('github.com', host)
    assert.equals('ashvinsharma/dotfiles', path)
  end)

  it('parses scp-like ssh urls for gitlab', function()
    local host, path = permalink.parse_remote_url 'git@gitlab.com:my-group/my-project.git'
    assert.equals('gitlab.com', host)
    assert.equals('my-group/my-project', path)
  end)

  it('parses scp-like ssh urls with gitlab subgroups', function()
    local host, path = permalink.parse_remote_url 'git@gitlab.com:group/subgroup/repo.git'
    assert.equals('gitlab.com', host)
    assert.equals('group/subgroup/repo', path)
  end)

  it('parses explicit ssh:// urls with a custom port', function()
    local host, path = permalink.parse_remote_url 'ssh://git@gitlab.example.com:2222/group/sub/repo.git'
    assert.equals('gitlab.example.com', host)
    assert.equals('group/sub/repo', path)
  end)

  it('parses bare https urls without a user', function()
    local host, path = permalink.parse_remote_url 'https://gitlab.com/group/sub/repo.git'
    assert.equals('gitlab.com', host)
    assert.equals('group/sub/repo', path)
  end)

  it('parses bare https urls for github', function()
    local host, path = permalink.parse_remote_url 'https://github.com/org/repo.git'
    assert.equals('github.com', host)
    assert.equals('org/repo', path)
  end)

  it('parses https urls with an embedded user (user@host)', function()
    local host, path = permalink.parse_remote_url 'https://user@gitlab.com/org/repo.git'
    assert.equals('gitlab.com', host)
    assert.equals('org/repo', path)
  end)

  it('parses https urls against self-hosted gitlab domains', function()
    local host, path = permalink.parse_remote_url 'https://gitlab.self-hosted.example.com/org/repo.git'
    assert.equals('gitlab.self-hosted.example.com', host)
    assert.equals('org/repo', path)
  end)

  it('does not mis-capture the host to a single trailing character (regression)', function()
    -- Prior bug: '^https?://[^@/]+@?([^/]+)/(.+)$' backtracked [^@/]+ down to
    -- nothing-but-the-last-char whenever there was no literal '@' in the URL.
    local host = permalink.parse_remote_url 'https://gitlab.com/group/sub/repo.git'
    assert.is_not.equals('m', host)
    assert.equals('gitlab.com', host)
  end)

  it('strips a trailing .git', function()
    local _, path = permalink.parse_remote_url 'git@gitlab.com:group/repo.git'
    assert.is_nil(path:match '%.git$')
  end)

  it('returns nil and an error message for unparseable urls', function()
    local host, err = permalink.parse_remote_url 'not-a-git-url'
    assert.is_nil(host)
    assert.is_string(err)
    assert.truthy(err:match 'Could not parse remote URL')
  end)
end)

describe('permalink.blob_segment', function()
  it('uses /blob/ for github.com', function()
    assert.equals('/blob/', permalink.blob_segment 'github.com')
  end)

  it('uses /blob/ for github.com regardless of case', function()
    assert.equals('/blob/', permalink.blob_segment 'GitHub.COM')
  end)

  it('uses /-/blob/ for gitlab.com', function()
    assert.equals('/-/blob/', permalink.blob_segment 'gitlab.com')
  end)

  it('uses /-/blob/ (gitlab convention) for self-hosted gitlab domains', function()
    assert.equals('/-/blob/', permalink.blob_segment 'gitlab.example.com')
  end)
end)

describe('permalink.build_url', function()
  it('builds a github permalink', function()
    local url = permalink.build_url('git@github.com:ashvinsharma/dotfiles.git', 'abc123', '.config/nvim/init.lua', 225)
    assert.equals('https://github.com/ashvinsharma/dotfiles/blob/abc123/.config/nvim/init.lua#L225', url)
  end)

  it('builds a gitlab permalink', function()
    local url = permalink.build_url('git@gitlab.com:my-group/my-project.git', 'def456', 'lib/foo.rb', 10)
    assert.equals('https://gitlab.com/my-group/my-project/-/blob/def456/lib/foo.rb#L10', url)
  end)

  it('builds a gitlab permalink with subgroups', function()
    local url = permalink.build_url('https://gitlab.com/group/subgroup/repo.git', 'sha1', 'a/b.go', 1)
    assert.equals('https://gitlab.com/group/subgroup/repo/-/blob/sha1/a/b.go#L1', url)
  end)

  it('returns nil and an error message when the remote url cannot be parsed', function()
    local url, err = permalink.build_url('not-a-git-url', 'sha1', 'a/b.go', 1)
    assert.is_nil(url)
    assert.is_string(err)
  end)
end)
