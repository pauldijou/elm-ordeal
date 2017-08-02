var path = require('path')
var fs = require('fs')
var chalk = require('chalk')
var symbols = require('log-symbols')
var osTmpdir = require('os-tmpdir')

var tmpDir = path.resolve(osTmpdir())
var tmpFilePrefix = 'elm_ordeal_'
var tmpFileSuffix = '.test.js'

function prependZero(value) {
  if (value < 10) { value = '0' + value }
  return value
}

function generateTmpPath(ctx) {
  var now = new Date()
  var name = [
    tmpFilePrefix,
    now.getFullYear(), '-', prependZero(now.getMonth() + 1), '-', prependZero(now.getDate()),
    '_',
    prependZero(now.getHours()), '-', prependZero(now.getMinutes()), '-', prependZero(now.getSeconds()),
    '_',
    process.pid,
    '_',
    (Math.random() * 0x100000000 + 1).toString(36),
    tmpFileSuffix
  ].join('')

  return path.join(tmpDir, name)
}

function exists(filename) {
  try {
    fs.accessSync(filename)
    return true
  } catch (e) {
    return false
  }
}

function clean(ctx) {
  return list(ctx).then(function (files) {
    Promise.all(files.map(remove))
  }).then(function () { return ctx })
}

// https://nodejs.org/api/fs.html#fs_fs_open_path_flags_mode_callback
// flags : wx+
// Open file for reading and writing.
// The file is created (if it does not exist) or truncated (if it exists)
// Fails if path exists
//
// mode : 0o600
// execute = 1, write = 2, read = 4 => 6 == 2 + 4 == write & read
// 1st = user, 2nd = group, 3rd = others => 600 == only user
function create(ctx) {
  return new Promise(function (resolve, reject) {
    fs.open(ctx.output, 'wx+', 0o600, function (err, info) {
      if (err) reject(err)
      else resolve(ctx)
    })
  })
}

function list(ctx) {
  return new Promise(function (resolve, reject) {
    fs.readdir(tmpDir, function (err, files) {
      if (err) { return reject(err) }

      var ordealFiles = (files || []).filter(function (filePath) {
        return filePath.indexOf(tmpFilePrefix) === 0
      }).map(function (filePath) {
        return path.join(tmpDir, filePath)
      })

      resolve(ordealFiles)
    })
  })
}

function remove(filePath) {
  return new Promise(function (resolve, reject) {
    fs.unlink(filePath, function (err) {
      if (err) { reject(err) }
      else { resolve() }
    })
  })
}

function check(ctx) {
  if (ctx.silent) { return ctx }

  return list(ctx).then(function (files) {
    console.log('')
    if (files.length > 0) {
      console.log(
        ' ',
        symbols.warning,
        chalk.yellow(chalk.bold(files.length + ' file' + (files.length > 1 ? 's' : ''))
        + ' in your tmp directory.')
      )
      console.log('')
      files.forEach(function (filePath) {
        console.log(' ', ' -', filePath)
      })
    } else {
      console.log(' ', symbols.info, 'All temporary files have been removed.')
    }
    console.log('')

    return ctx
  })
}

module.exports = {
  generateTmpPath: generateTmpPath,
  create: create,
  exists: exists,
  list: list,
  clean: clean,
  check: check
}
