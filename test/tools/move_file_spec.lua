local lu = require('luaunit')
local tools = require('chat.tools')
local config = require('chat.config')

TestMoveFile = {}

function TestMoveFile:setUp()
  self.test_dir = vim.fs.normalize(vim.fn.getcwd()) .. '/test_temp_files'
  if vim.fn.isdirectory(self.test_dir) == 0 then
    vim.fn.mkdir(self.test_dir, 'p')
  end

  config.setup({
    allowed_path = vim.fs.normalize(vim.fn.getcwd()),
  })
end

function TestMoveFile:tearDown()
  if self.test_dir and vim.fn.isdirectory(self.test_dir) == 1 then
    vim.fn.delete(self.test_dir, 'rf')
  end
end

-- ============================
-- Basic Move Tests
-- ============================

function TestMoveFile:testMoveFileBasic()
  local source = self.test_dir .. '/source.lua'
  local dest = self.test_dir .. '/dest.lua'
  vim.fn.writefile({ 'hello world' }, source)

  local result = tools.call('move_file', {
    source = source,
    destination = dest,
  }, { cwd = vim.fs.normalize(vim.fn.getcwd()) })

  lu.assertNotNil(result)
  lu.assertNotNil(
    result.content,
    'Expected content, got error: ' .. (result.error or 'unknown')
  )
  lu.assertStrContains(result.content, 'Successfully moved')
  lu.assertEquals(vim.fn.filereadable(dest), 1)
  lu.assertEquals(vim.fn.filereadable(source), 0)

  local lines = vim.fn.readfile(dest)
  lu.assertEquals(lines[1], 'hello world')
end

function TestMoveFile:testMoveFileRelativePath()
  local source = self.test_dir .. '/rel_source.lua'
  local dest = self.test_dir .. '/rel_dest.lua'
  vim.fn.writefile({ 'relative' }, source)

  local cwd = vim.fs.normalize(vim.fn.getcwd())
  local result = tools.call('move_file', {
    source = 'test_temp_files/rel_source.lua',
    destination = 'test_temp_files/rel_dest.lua',
  }, { cwd = cwd })

  lu.assertNotNil(result)
  lu.assertNotNil(result.content)
  lu.assertStrContains(result.content, 'Successfully moved')
  lu.assertEquals(vim.fn.filereadable(dest), 1)
  lu.assertEquals(vim.fn.filereadable(source), 0)
end

function TestMoveFile:testMoveFileToSubdirectory()
  local subdir = self.test_dir .. '/subdir'
  vim.fn.mkdir(subdir, 'p')

  local source = self.test_dir .. '/file_to_move.lua'
  local dest = subdir .. '/moved.lua'
  vim.fn.writefile({ 'subdir content' }, source)

  local result = tools.call('move_file', {
    source = source,
    destination = dest,
  }, { cwd = vim.fs.normalize(vim.fn.getcwd()) })

  lu.assertNotNil(result)
  lu.assertNotNil(result.content)
  lu.assertStrContains(result.content, 'Successfully moved')
  lu.assertEquals(vim.fn.filereadable(dest), 1)
  lu.assertEquals(vim.fn.filereadable(source), 0)

  local lines = vim.fn.readfile(dest)
  lu.assertEquals(lines[1], 'subdir content')
end

-- ============================
-- Directory Move Tests
-- ============================

function TestMoveFile:testMoveDirectory()
  local source = self.test_dir .. '/source_dir'
  local dest = self.test_dir .. '/dest_dir'
  vim.fn.mkdir(source, 'p')
  vim.fn.writefile({ 'file A' }, source .. '/a.lua')
  vim.fn.writefile({ 'file B' }, source .. '/b.lua')

  local result = tools.call('move_file', {
    source = source,
    destination = dest,
  }, { cwd = vim.fs.normalize(vim.fn.getcwd()) })

  lu.assertNotNil(result)
  lu.assertNotNil(result.content)
  lu.assertStrContains(result.content, 'Successfully moved')
  lu.assertEquals(vim.fn.isdirectory(dest), 1)
  lu.assertEquals(vim.fn.isdirectory(source), 0)
  lu.assertEquals(vim.fn.filereadable(dest .. '/a.lua'), 1)
  lu.assertEquals(vim.fn.filereadable(dest .. '/b.lua'), 1)

  local lines_a = vim.fn.readfile(dest .. '/a.lua')
  lu.assertEquals(lines_a[1], 'file A')
end

function TestMoveFile:testMoveDirectoryWithSubdirectories()
  local source = self.test_dir .. '/nested_src'
  local dest = self.test_dir .. '/nested_dst'
  vim.fn.mkdir(source .. '/inner', 'p')
  vim.fn.writefile({ 'top' }, source .. '/top.lua')
  vim.fn.writefile({ 'inner' }, source .. '/inner/deep.lua')

  local result = tools.call('move_file', {
    source = source,
    destination = dest,
  }, { cwd = vim.fs.normalize(vim.fn.getcwd()) })

  lu.assertNotNil(result)
  lu.assertNotNil(result.content)
  lu.assertStrContains(result.content, 'Successfully moved')
  lu.assertEquals(vim.fn.isdirectory(dest), 1)
  lu.assertEquals(vim.fn.isdirectory(dest .. '/inner'), 1)
  lu.assertEquals(vim.fn.filereadable(dest .. '/top.lua'), 1)
  lu.assertEquals(vim.fn.filereadable(dest .. '/inner/deep.lua'), 1)

  local lines = vim.fn.readfile(dest .. '/inner/deep.lua')
  lu.assertEquals(lines[1], 'inner')
end

-- ============================
-- Overwrite Tests
-- ============================

function TestMoveFile:testMoveFileOverwriteExisting()
  local source = self.test_dir .. '/overwrite_src.lua'
  local dest = self.test_dir .. '/overwrite_dst.lua'
  vim.fn.writefile({ 'source content' }, source)
  vim.fn.writefile({ 'old dest content' }, dest)

  local result = tools.call('move_file', {
    source = source,
    destination = dest,
    overwrite = true,
  }, { cwd = vim.fs.normalize(vim.fn.getcwd()) })

  lu.assertNotNil(result)
  lu.assertNotNil(result.content)
  lu.assertStrContains(result.content, 'Successfully moved')
  lu.assertEquals(vim.fn.filereadable(dest), 1)
  lu.assertEquals(vim.fn.filereadable(source), 0)

  local lines = vim.fn.readfile(dest)
  lu.assertEquals(lines[1], 'source content')
end

function TestMoveFile:testMoveFileNoOverwriteExisting()
  local source = self.test_dir .. '/no_overwrite_src.lua'
  local dest = self.test_dir .. '/no_overwrite_dst.lua'
  vim.fn.writefile({ 'source' }, source)
  vim.fn.writefile({ 'dest' }, dest)

  local result = tools.call('move_file', {
    source = source,
    destination = dest,
  }, { cwd = vim.fs.normalize(vim.fn.getcwd()) })

  lu.assertNotNil(result)
  lu.assertNotNil(result.error)
  lu.assertStrContains(result.error, 'already exists')
  -- Both files should still exist
  lu.assertEquals(vim.fn.filereadable(source), 1)
  lu.assertEquals(vim.fn.filereadable(dest), 1)
end

function TestMoveFile:testMoveDirectoryOverwriteExisting()
  local source = self.test_dir .. '/dir_overwrite_src'
  local dest = self.test_dir .. '/dir_overwrite_dst'
  vim.fn.mkdir(source, 'p')
  vim.fn.writefile({ 'new' }, source .. '/file.lua')
  vim.fn.mkdir(dest, 'p')
  vim.fn.writefile({ 'old' }, dest .. '/old_file.lua')

  local result = tools.call('move_file', {
    source = source,
    destination = dest,
    overwrite = true,
  }, { cwd = vim.fs.normalize(vim.fn.getcwd()) })

  lu.assertNotNil(result)
  lu.assertNotNil(result.content)
  lu.assertStrContains(result.content, 'Successfully moved')
  lu.assertEquals(vim.fn.isdirectory(dest), 1)
  lu.assertEquals(vim.fn.isdirectory(source), 0)
  lu.assertEquals(vim.fn.filereadable(dest .. '/file.lua'), 1)
  -- Old file should be gone (overwritten)
  lu.assertEquals(vim.fn.filereadable(dest .. '/old_file.lua'), 0)
end

-- ============================
-- Error Cases
-- ============================

function TestMoveFile:testMoveFileSourceNotExist()
  local result = tools.call('move_file', {
    source = self.test_dir .. '/nonexistent.lua',
    destination = self.test_dir .. '/dest.lua',
  }, { cwd = vim.fs.normalize(vim.fn.getcwd()) })

  lu.assertNotNil(result)
  lu.assertNotNil(result.error)
  lu.assertStrContains(result.error, 'does not exist')
end

function TestMoveFile:testMoveFileMissingSource()
  local result = tools.call('move_file', {
    destination = self.test_dir .. '/dest.lua',
  }, { cwd = vim.fs.normalize(vim.fn.getcwd()) })

  lu.assertNotNil(result)
  lu.assertNotNil(result.error)
  lu.assertStrContains(result.error, 'source')
end

function TestMoveFile:testMoveFileMissingDestination()
  local source = self.test_dir .. '/missing_dest_src.lua'
  vim.fn.writefile({ 'content' }, source)

  local result = tools.call('move_file', {
    source = source,
  }, { cwd = vim.fs.normalize(vim.fn.getcwd()) })

  lu.assertNotNil(result)
  lu.assertNotNil(result.error)
  lu.assertStrContains(result.error, 'destination')
end

function TestMoveFile:testMoveFileEmptySource()
  local result = tools.call('move_file', {
    source = '',
    destination = self.test_dir .. '/dest.lua',
  }, { cwd = vim.fs.normalize(vim.fn.getcwd()) })

  lu.assertNotNil(result)
  lu.assertNotNil(result.error)
  lu.assertStrContains(result.error, 'source')
end

function TestMoveFile:testMoveFileEmptyDestination()
  local source = self.test_dir .. '/empty_dest_src.lua'
  vim.fn.writefile({ 'content' }, source)

  local result = tools.call('move_file', {
    source = source,
    destination = '',
  }, { cwd = vim.fs.normalize(vim.fn.getcwd()) })

  lu.assertNotNil(result)
  lu.assertNotNil(result.error)
  lu.assertStrContains(result.error, 'destination')
end

function TestMoveFile:testMoveFileMissingCwd()
  local source = self.test_dir .. '/no_cwd.lua'
  vim.fn.writefile({ 'content' }, source)

  local result = tools.call('move_file', {
    source = source,
    destination = self.test_dir .. '/dest.lua',
  }, { cwd = '' })

  lu.assertNotNil(result)
  lu.assertNotNil(result.error)
  lu.assertStrContains(result.error, 'cwd')
end

-- ============================
-- Security Tests
-- ============================

function TestMoveFile:testMoveFileSecuritySourceOutsideCwd()
  local result = tools.call('move_file', {
    source = '../../../etc/passwd',
    destination = self.test_dir .. '/dest.lua',
  }, { cwd = vim.fs.normalize(vim.fn.getcwd()) })

  lu.assertNotNil(result)
  lu.assertNotNil(result.error)
  lu.assertStrContains(result.error, 'Security')
end

function TestMoveFile:testMoveFileSecurityDestinationOutsideCwd()
  local source = self.test_dir .. '/security_src.lua'
  vim.fn.writefile({ 'content' }, source)

  local result = tools.call('move_file', {
    source = source,
    destination = '../../../tmp/malicious.lua',
  }, { cwd = vim.fs.normalize(vim.fn.getcwd()) })

  lu.assertNotNil(result)
  lu.assertNotNil(result.error)
  lu.assertStrContains(result.error, 'Security')
end

function TestMoveFile:testMoveFileSecurityNotAllowedPath()
  local temp_dir = vim.fn.tempname()
  vim.fn.mkdir(temp_dir, 'p')
  local temp_source = temp_dir .. '/source.lua'
  local temp_dest = temp_dir .. '/dest.lua'
  vim.fn.writefile({ 'content' }, temp_source)

  local result = tools.call('move_file', {
    source = temp_source,
    destination = temp_dest,
  }, { cwd = temp_dir })

  lu.assertNotNil(result)
  lu.assertNotNil(result.error)
  lu.assertStrContains(result.error, 'allowed_path')

  vim.fn.delete(temp_dir, 'rf')
end

-- ============================
-- Multi-line File Move Test
-- ============================

function TestMoveFile:testMoveFileMultilineContent()
  local source = self.test_dir .. '/multiline_src.lua'
  local dest = self.test_dir .. '/multiline_dst.lua'
  local content = {
    'local M = {}',
    '',
    'function M.test()',
    '  return "hello"',
    'end',
    '',
    'return M',
  }
  vim.fn.writefile(content, source)

  local result = tools.call('move_file', {
    source = source,
    destination = dest,
  }, { cwd = vim.fs.normalize(vim.fn.getcwd()) })

  lu.assertNotNil(result)
  lu.assertNotNil(result.content)
  lu.assertStrContains(result.content, 'Successfully moved')

  local lines = vim.fn.readfile(dest)
  lu.assertEquals(#lines, 7)
  lu.assertEquals(lines[1], 'local M = {}')
  lu.assertEquals(lines[4], '  return "hello"')
  lu.assertEquals(lines[7], 'return M')
end

-- ============================
-- Scheme and Info Tests
-- ============================

function TestMoveFile:testMoveFileScheme()
  local move_file = require('chat.tools.move_file')
  local scheme = move_file.scheme()

  lu.assertNotNil(scheme)
  lu.assertEquals(scheme.type, 'function')
  lu.assertEquals(scheme['function'].name, 'move_file')
  lu.assertNotNil(scheme['function'].parameters)
  lu.assertEquals(scheme['function'].parameters.type, 'object')

  -- Check required fields
  local required = scheme['function'].parameters.required
  lu.assertTrue(vim.tbl_contains(required, 'source'))
  lu.assertTrue(vim.tbl_contains(required, 'destination'))
end

function TestMoveFile:testMoveFileInfo()
  local move_file = require('chat.tools.move_file')
  local info = move_file.info(
    '{"source":"./a.lua","destination":"./b.lua"}',
    { cwd = '/test' }
  )

  lu.assertNotNil(info)
  lu.assertStrContains(info, 'move_file')
  lu.assertStrContains(info, 'a.lua')
  lu.assertStrContains(info, 'b.lua')
end

function TestMoveFile:testMoveFileInfoWithOverwrite()
  local move_file = require('chat.tools.move_file')
  local info = move_file.info(
    '{"source":"./a.lua","destination":"./b.lua","overwrite":true}',
    { cwd = '/test' }
  )

  lu.assertNotNil(info)
  lu.assertStrContains(info, 'overwrite')
end

function TestMoveFile:testMoveFileInfoInvalidJson()
  local move_file = require('chat.tools.move_file')
  local info = move_file.info('invalid json', { cwd = '/test' })
  lu.assertEquals(info, 'move_file')
end

-- ============================
-- Tool Registration Test
-- ============================

function TestMoveFile:testMoveFileRegistered()
  local available = tools.available_tools()
  local tool_names = {}
  for _, tool in ipairs(available) do
    table.insert(tool_names, tool['function'].name)
  end

  lu.assertTrue(
    vim.tbl_contains(tool_names, 'move_file'),
    'move_file should be in available_tools'
  )
end

return TestMoveFile

