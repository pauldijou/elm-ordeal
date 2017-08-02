#!/usr/bin/env node

process.title = 'elm-ordeal'

var path = require('path')
var compile = require('node-elm-compiler').compile
var Server = require('karma').Server

var moduleRoot = path.resolve(__dirname, '..')
var helpers = require(path.join(moduleRoot, 'cli', 'helpers.js'))
var files = require(path.join(moduleRoot, 'cli', 'files.js'))

var stdoutReporter = require(path.join(moduleRoot, 'cli', 'reporters', 'stdout.js'))

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
    keep: 'k'
  },
  boolean: [ 'help', 'version', 'keep', 'hard-keep', 'json', 'node', 'chrome', 'edge', 'firefox', 'safari', 'ie', 'opera' ],
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
  console.log('    -k, --keep', ' keep the last generated JS file so you can debug it')
  console.log('    --hard-keep', ' keep all generated JS file so you can debug them')
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

var cwd = process.cwd()
var cleanAtStart = !args['hard-keep']
var cleanAtEnd = !(args['hard-keep'] || args.keep)


var testFile = args._[0]

// Seriously, you need to specify which file to test
if (!testFile) {
  console.log('You need to specify which file to test as the first argument of the CLI')
  process.exit(1)
}

testFile = path.resolve(testFile)
var testDir = path.dirname(testFile)

while (!files.exists(path.join(testDir, 'elm-package.json'))) {
  testDir = path.join(testDir, '..')
}

if (testDir === path.join(testDir, '..')) {
  console.log('We want all the way up to the root dir and could not find an elm-package.json file')
  process.exit(1)
}

// Parsing some args
args.timeout = parseInt(args.timeout, 10)
if (isNaN(args.timeout)) {
  args.timeout = defaults.timeout
}

function doNothing(ctx) { return ctx }


// -----------------------------------------------------------------------------
// The trial by ordeal
Promise.resolve({
    sources: [ testFile ],
    silent: false,
    node: undefined,
    browsers: undefined
  })
  .then(cleanAtStart ? files.clean : doNothing)
  .then(function (ctx) {
    ctx.output = files.generateTmpPath(ctx)
    return ctx
  })
  .then(files.create)
  .then(compileTests)
  .then(runNode)
  .then(runBrowsers)
  .then(cleanAtEnd ? files.clean : doNothing)
  .then(files.check)
  .then(function (ctx) {
    process.exit(ctx.node && ctx.browsers ? 0 : 1)
  })
  .catch(function (e) {
    console.error(e)
    process.exit(1)
  })


// -----------------------------------------------------------------------------
// ELM
if (args.compiler === undefined) {
  var path1 = path.join(__dirname, '..', '..', '.bin', 'elm-make')
  var path2 = path.join(cwd, 'node_modules', '.bin', 'elm-make')
  var path3 = path.join(cwd, '..', 'node_modules', '.bin', 'elm-make')

  if (files.exists(path1)) {
    args.compiler = path1
  } else if (files.exists(path2)) {
    args.compiler = path2
  } else if (files.exists(path3)) {
    args.compiler = path3
  } else {
    args.compiler = 'elm-make'
  }
}

function compileTests(ctx) {
  var options = {
    output: ctx.output,
    verbose: false,
    yes: true,
    warn: false,
    debug: false,
    // report: 'json',
    cwd: testDir,
    pathToMake: args.compiler
  }

  return new Promise(function (resolve, reject) {
    compile(ctx.sources, options).on('close', function (exitCode) {
      if (exitCode !== 0) { return reject('Failed to compile tests') }
      resolve(ctx)
    })
  })
}


// -----------------------------------------------------------------------------
// NODE
function runNode(ctx) {
  if (!args.node) { ctx.node = true; return ctx }

  return new Promise(function (resolve, reject) {
    var runner = helpers.worker(require(ctx.output), {
      timeout: args.timeout
    })

    var reporter = stdoutReporter.init({
      silent: false,
      timeout: args.timeout,
      done: function (failed) {
        ctx.node = !failed
        resolve(ctx)
      }
    })

    helpers.subscribe(helpers.port(runner, args.port), reporter)
  })
}


// -----------------------------------------------------------------------------
// KARMA
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
