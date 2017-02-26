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
    port: 'p'
  },
  boolean: [ 'help', 'version', 'node', 'chrome', 'firefox', 'safari', 'ie', 'opera' ],
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
  console.log('Usage:')
  console.log('')
  console.log('  elm-ordeal your/TestFile.elm [--compiler /path/to/elm-make]')
  console.log('')
  console.log('Options:')
  console.log('')
  console.log('  -h, --help', '    output usage information')
  console.log('  -V, --version', ' output the version number')
  console.log('  -c, --compiler', 'specify which elm-make to use')
  console.log('  -t, --timeout', ' how long to wait before failing a test, in ms [number, default 5000]')
  console.log('')
  console.log('Envs (browsers must already be installed):')
  console.log('')
  console.log('  --node')
  console.log('  --chrome')
  console.log('  --firefox')
  console.log('  --safari')
  console.log('  --ie')
  console.log('  --opera')
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

function runNode(ctx) {
  if (!args.node) { ctx.node = true; return ctx }

  return new Promise(function (resolve, reject) {
    var runner = helpers.worker(require(ctx.output), {
      timeout: args.timeout
    })

    var start
    var suites = []

    function pad() {
      return ' ' + suites.map(function () { return '  ' }).join('')
    }

    helpers.subscribe(helpers.port(runner, args.port), {
      onStarted: function onStarted(startReport) {
        console.log('')
        start = startReport
      },

      onSuiteStarted: function onSuiteStarted(name) {
        console.log(pad(), chalk.bold(name))
        suites.push(name)
      },

      onSuiteDone: function onSuiteDone(name) {
        suites.pop()
      },

      onTestStarted: function onTestStarted(name) {},

      onTestDone: function onTestDone(tested) {
        var color
        var symb

        if (tested.skipped) { color = chalk.yellow; symb = symbols.warning }
        else if (tested.success) { color = chalk.green; symb = symbols.success }
        else if (tested.timeout) { color = chalk.magenta; symb = symbols.error }
        else { color = chalk.red; symb = symbols.error }

        console.log(pad(), symb, color(tested.name), '('+ tested.duration +'ms)')
      },

      onDone: function onDone(end) {
        ctx.node = true
        console.log('')

        if (end.timeouts.length > 0) {
          ctx.node = false
          console.log('')
          console.log(' ', symbols.error, chalk.magenta(end.timeouts.length + ' of ' + start.tests + ' tests timeout:'))
          end.timeouts.forEach(function (tested) {
            console.log('')
            console.log(' ', tested.name)
          })
        }

        if (end.failures.length > 0) {
          ctx.node = false
          console.log('')
          console.log(' ', symbols.error, chalk.red(end.failures.length + ' of ' + start.tests + ' tests failed:'))
          end.failures.forEach(function (tested) {
            console.log('')
            console.log(' ', chalk.bold(tested.name))
            console.log('   ', tested.failure)
          })
        }

        if (ctx.node) {
          console.log('')
          console.log(' ', symbols.success, chalk.green('All ' + start.tests + ' tests passed'))
          if (end.skipped.length > 0) {
            console.log(' ', chalk.yellow('(but you skipped ' + end.skipped.length + ' of them)'))
          }
        }

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
