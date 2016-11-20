#!/usr/bin/env node

process.title = 'elm-ordeal'

const path = require('path')
const compile = require('node-elm-compiler').compile
const temp = require('temp').track()
const spawn = require('cross-spawn')
const Jasmine = require('jasmine')
const jasmine = new Jasmine()
const Server = require('karma').Server
const SpecReporter = require('jasmine-spec-reporter')

const moduleRoot = path.resolve(__dirname, '..')

global.ordeal = {}


// Handling args like a boss
const args = require('minimist')(process.argv.slice(2), {
  alias: {
    help: 'h',
    version: 'V',
    compiler: 'c'
  },
  boolean: [ 'help', 'version', 'node', 'chrome', 'firefox', 'safari', 'ie', 'opera' ],
  string: [ 'compiler' ]
})

if (args.version) {
  console.log(require(path.join(moduleRoot, 'package.json')).version)
  process.exit(0)
}

if (args.help) {
  console.log('Usage: elm-ordeal your/TestFile.elm [--compiler /path/to/elm-make]')
  console.log('')
  console.log('Options:')
  console.log('')
  console.log('  -h, --help', 'output usage information')
  console.log('  -V, --version', 'output the version number')
  console.log('  -c, --compiler', 'specify which elm-make to use')
  console.log('')
  console.log('Envs:')
  console.log('')
  console.log('  --node')
  console.log('  --chrome')
  console.log('  --firefox')
  console.log('  --safari')
  console.log('  --ie')
  console.log('  --opera')
  process.exit(1)
}


// Seriously, you need to specify which file to test
const testFile = args._[0]

if (!testFile) {
  process.exit(1)
}


// The trial by ordeal
createTmpFile()
  .then(getOutputPath)
  .then(compileTests)
  .then(executeJasmine)
  .then(startKarma)
  .then(function (ctx) {
    process.exit(ctx.jasmine && ctx.karma ? 0 : 1)
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
      else resolve(info)
    })
  })
}

function getOutputPath(info) {
  return path.relative(process.cwd(), info.path)
}

function compileTests(outputPath) {
  return new Promise(function (resolve, reject) {
    compile([ testFile ], {
      output: outputPath,
      verbose: false,
      yes: true,
      spawn: spawn,
      pathToMake: args.compiler,
      warn: false
    }).on('close', function (exitCode) {
      if (exitCode !== 0) reject('Failed to compile tests')
      else resolve({ output: outputPath, jasmine: undefined, karma: undefined })
    })
  })
}

function executeJasmine(ctx) {
  if (!args.node) { ctx.jasmine = true; return ctx }

  global.ordeal.runner = require(path.join(moduleRoot, 'build', 'runner.js')).Runner.worker()

  return new Promise(function (resolve, reject) {
    jasmine.onComplete(function(passed) {
      ctx.jasmine = passed
      resolve(ctx)
    })
    jasmine.env.clearReporters()
    jasmine.addReporter(new SpecReporter())
    jasmine.execute([ ctx.output ])
  })
}

function startKarma(ctx) {
  const browsers = []
  if (args.chrome) { browsers.push('Chrome') }
  if (args.firefox) { browsers.push('Firefox') }
  if (args.safari) { browsers.push('Safari') }
  if (args.ie) { browsers.push('IE') }
  if (args.opera) { browsers.push('Opera') }

  if (browsers.length === 0) { ctx.karma = true; return ctx }

  return new Promise(function (resolve, reject) {
    const server = new Server({
      port: 9876,
      frameworks: ['jasmine'],
      files: [
        path.resolve(moduleRoot, 'build', 'runner.js'),
        path.resolve(moduleRoot, 'scripts', 'worker.js'),
        ctx.output
      ],
      reporters: ['progress'],
      colors: true,
      browsers: browsers,
      autoWatch: false,
      singleRun: true,
      concurrency: Infinity
    }, function (exitCode) {
      // console.log('exited karma', exitCode)
    })

    server.on('run_complete', function (browsers, results) {
      ctx.karma = (results.failed === 0) && (!results.error) && (results.exitCode === 0)
      resolve(ctx)
    })

    server.start()
  })
}

// jasmine.addReporter({
//   jasmineStarted: function (result) {
//     console.log(result)
//   },
//   suiteStarted: function (result) {
//     console.log(result)
//   },
//   specStarted: function (result) {
//     console.log(result)
//   },
//   specDone: function (result) {
//     console.log(result)
//   },
//   suiteDone: function (result) {
//     console.log(result)
//   },
//   jasmineDone: function (result) {
//     console.log(result)
//   }
// });
