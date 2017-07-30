#!/usr/bin/env node

process.title = 'elm-ordeal'

var path = require('path')
var fs = require('fs')
var compile = require('node-elm-compiler').compile
var temp = require('temp').track()
var spawn = require('cross-spawn')
var Server = require('karma').Server
var chalk = require('chalk')
var symbols = require('log-symbols')

var moduleRoot = path.resolve(__dirname, '..')
var helpers = require(path.join(moduleRoot, 'cli', 'helpers.js'))

var defaults = {
  timeout: 5000
}

// Handling args like a boss
var args = require('minimist')(process.argv.slice(2), {
  alias: {
    help: 'h',
    version: 'V',
    compiler: 'c',
    timeout: 't',
    port: 'p',
    json: 'j',
  },
  boolean: [ 'help', 'version', 'node', 'chrome', 'edge', 'firefox', 'safari', 'ie', 'opera' ],
  string: [ 'compiler', 'timeout', 'port' ],
  default: {
    timeout: '' + defaults.timeout
  }
})

if (args.version) {
  console.log(require(path.join(moduleRoot, 'package.json')).version)
  process.exit(0)
}

if (args.help) {
  console.log('  Usage:')
  console.log('')
  console.log('    elm-ordeal your/TestFile.elm [--compiler /path/to/elm-make]')
  console.log('')
  console.log('  Options:')
  console.log('')
  console.log('    -h, --help', '    output usage information')
  console.log('    -V, --version', ' output the version number')
  console.log('    -c, --compiler', 'specify which elm-make to use')
  console.log('    -t, --timeout', ' how long to wait before failing a test, in ms [number, default 5000]')
  console.log('    -j, --json', ' export result as a JSON string')
  console.log('    -p, --port', ' the name of the Elm port to use from your main test program')
  console.log('')
  console.log('  Envs (browsers must already be installed):')
  console.log('')
  console.log('    --node')
  console.log('    --chrome')
  console.log('    --edge')
  console.log('    --firefox')
  console.log('    --safari')
  console.log('    --ie')
  console.log('    --opera')
  console.log('')
  process.exit(0)
}


// Seriously, you need to specify which file to test
var testFile = args._[0]

if (!testFile) {
  process.exit(1)
}

testFile = path.resolve(testFile)
var testDir = path.dirname(testFile)

while (!fileExists(path.join(testDir, 'elm-package.json'))) {
  testDir = path.join(testDir, '..')
}

function fileExists(filename) {
  try {
    fs.accessSync(filename)
    return true
  } catch (e) {
    return false
  }
}

// Parsing some args
args.timeout = parseInt(args.timeout, 10)
if (isNaN(args.timeout)) {
  args.timeout = defaults.timeout
}

// The trial by ordeal
createTmpFile()
  .then(compileTests)
  .then(runNode)
  .then(runBrowsers)
  .then(function (ctx) {
    process.exit(ctx.node && ctx.browsers ? 0 : 1)
  })
  .catch(function (e) {
    console.error(e)
    process.exit(1)
  })


// Where the magic happen
function createTmpFile() {
  return new Promise(function (resolve, reject) {
    temp.open({ prefix: 'elm_ordeal_', suffix: '.test.js' }, function (err, info) {
      if (err) reject(err)
      else resolve(info.path)
    })
  })
}

function compileTests(outputPath) {
  return new Promise(function (resolve, reject) {
    compile([ testFile ], {
      output: outputPath,
      verbose: false,
      yes: true,
      spawn: function (cmd, arg, options) {
        options = options || {}
        options.cwd = testDir
        return spawn(cmd, arg, options)
      },
      pathToMake: args.compiler,
      warn: false
    }).on('close', function (exitCode) {
      if (exitCode !== 0) reject('Failed to compile tests')
      else resolve({ output: outputPath, node: undefined, browsers: undefined })
    })
  })
}

var colors = {
  success: { color: chalk.green, symb: symbols.success },
  error: { color: chalk.red, symb: symbols.error },
  skipped: { color: chalk.blue, symb: symbols.info },
  timeout: { color: chalk.yellow, symb: symbols.warning }
}

var oneSecond = 1000
var oneMinute = 60 * oneSecond
var oneHour = 24 * oneMinute

function formatDuration(ms) {
  if (ms === 0) { return '0ms' }

  var hours = 0
  var minutes = 0
  var seconds = 0

  if (ms > oneHour) {
    hours = Math.floor(ms / oneHour)
    ms = ms % oneHour
  }

  if (ms > oneMinute) {
    minutes = Math.floor(ms / oneMinute)
    ms = ms % oneMinute
  }

  if (ms > oneSecond) {
    seconds = Math.floor(ms / oneSecond)
    ms = ms % oneSecond
  }

  return (
    (hours ? hours + ' hours ' : '') +
    (minutes ? minutes + ' minutes ' : '') +
    (seconds ? seconds + ' seconds ' : '') +
    (ms ? ms + 'ms' : '')
  )
}

var shouldPrint = !args.json

function runNode(ctx) {
  if (!args.node) { ctx.node = true; return ctx }

  return new Promise(function (resolve, reject) {
    var runner = helpers.worker(require(ctx.output), {
      timeout: args.timeout
    })

    var start
    var startedAt
    var suites = []

    function pad() {
      return ' ' + suites.map(function () { return '  ' }).join('')
    }

    helpers.subscribe(helpers.port(runner, args.port), {
      onStarted: function onStarted(startReport) {
        shouldPrint && console.log('')
        start = startReport
        startedAt = Date.now()
      },

      onSuiteStarted: function onSuiteStarted(name) {
        shouldPrint && console.log(pad(), chalk.bold(name))
        suites.push(name)
      },

      onSuiteDone: function onSuiteDone(name) {
        suites.pop()
      },

      onTestStarted: function onTestStarted(name) {},

      onTestDone: function onTestDone(tested) {
        var color
        var symb

        if (tested.skipped) { color = colors.skipped.color; symb = colors.skipped.symb }
        else if (tested.success) { color = colors.success.color; symb = colors.success.symb }
        else if (tested.timeout) { color = colors.timeout.color; symb = colors.timeout.symb }
        else { color = colors.error.color; symb = colors.error.symb }

        shouldPrint && console.log(pad(), symb, color(tested.name), '('+ formatDuration(tested.duration) +')')
      },

      onDone: function onDone(end) {
        var failed = end.timeouts.length > 0 || end.failures.length > 0
        ctx.node = failed

        if (args.json) {
          console.log(end)
          return resolve(ctx)
        }

        console.log('')

        if (end.timeouts.length > 0) {
          ctx.node = false
          console.log('')
          console.log(' ', colors.timeout.symb, colors.timeout.color(end.timeouts.length + ' of ' + start.tests + ' tests timeout after', formatDuration(args.timeout), ':'))
          end.timeouts.forEach(function (tested) {
            console.log('')
            console.log(' ', tested.name)
          })
        }

        if (end.failures.length > 0) {
          ctx.node = false
          console.log('')
          console.log(' ', colors.error.symb, colors.error.color(end.failures.length + ' of ' + start.tests + ' tests failed:'))
          end.failures.forEach(function (tested) {
            console.log('')
            console.log(' ', chalk.bold(tested.name))
            console.log('   ', tested.failure)
          })
        }

        console.log('')
        console.log(' -------------------------------------------------------------')

        if (failed) {
          var msg = ''
          if (end.failures.length > 0) {
            msg += end.failures.length + ' failed test' + (end.failures.length > 1 ? 's' : '')
          }
          if (end.timeouts.length > 0) {
            if (msg) { msg += ', ' }
            msg += end.timeouts.length + ' timeout' + (end.timeouts.length > 1 ? 's' : '')
          }
          console.log('')
          console.log(' ', colors.error.symb, colors.error.color('Failure:'), msg)
        } else {
          console.log('')
          console.log(' ', colors.success.symb, colors.success.color('All ' + start.tests + ' tests passed'))
          if (end.skipped.length > 0) {
            console.log(' ', colors.skipped.color('(but you skipped ' + end.skipped.length + ' of them)'))
          }
        }

        var endedAt = new Date()
        console.log('')
        console.log(' ', chalk.bold('Duration:'), formatDuration(endedAt - startedAt))

        console.log('')
        resolve(ctx)
      }
    })
  })
}

function runBrowsers(ctx) {
  var browsers = []
  var plugins = []
  if (args.chrome) { browsers.push('Chrome'); plugins.push('karma-chrome-launcher') }
  if (args.edge) { browsers.push('Edge'); plugins.push('karma-edge-launcher') }
  if (args.firefox) { browsers.push('Firefox'); plugins.push('karma-firefox-launcher') }
  if (args.safari) { browsers.push('Safari'); plugins.push('karma-safari-launcher') }
  if (args.ie) { browsers.push('IE'); plugins.push('karma-ie-launcher') }
  if (args.opera) { browsers.push('Opera'); plugins.push('karma-opera-launcher') }

  if (browsers.length === 0) { ctx.browsers = true; return ctx }

  return new Promise(function (resolve, reject) {
    var server = new Server({
      port: 9876,
      frameworks: [],
      files: [
        {pattern: path.join(__dirname, '..', 'cli', 'helpers.js'), included: true, served: true, watched: false},
        {pattern: path.join(__dirname, '..', 'cli', 'karma-ordeal.js'), included: true, served: true, watched: false},
        ctx.output
      ],
      reporters: ['progress'],
      browsers: browsers,
      plugins: plugins,
      colors: true,
      autoWatch: false,
      singleRun: true,
      concurrency: Infinity
    }, function (exitCode) {
      // console.log('exited karma', exitCode)
    })

    server.on('run_complete', function (browsers, results) {
      ctx.browsers = (results.failed === 0) && (!results.error) && (results.exitCode === 0)
      resolve(ctx)
    })

    server.start()
  })
}
