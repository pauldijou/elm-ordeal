var chalk = require('chalk')
var symbols = require('log-symbols')
var helpers = require('./helpers.js')

var print = helpers.print
var formatDuration = helpers.formatDuration

var status

function init(config) {
  status = {
    silent: config.silent,
    timeout: config.timeout,
    done: config.done,
    startedAt: Date.now(),
    suites: []
  }

  return {
    onStarted: onStarted,
    onSuiteStarted: onSuiteStarted,
    onSuiteDone: onSuiteDone,
    onTestStarted: onTestStarted,
    onTestDone: onTestDone,
    onDone: onDone
  }
}

function pad() {
  return ' ' + status.suites.map(function () { return '  ' }).join('')
}

function onStarted(startReport) {
  status.start = startReport
}

function onSuiteStarted(name) {
  !status.silent && console.log(pad(), chalk.bold(name))
  status.suites.push(name)
}

function onSuiteDone(name) {
  status.suites.pop()
}

function onTestStarted(name) {}

function onTestDone(tested) {
  var color
  var symb

  if (tested.skipped) { color = print.skipped.color; symb = print.skipped.symb }
  else if (tested.success) { color = print.success.color; symb = print.success.symb }
  else if (tested.timeout) { color = print.timeout.color; symb = print.timeout.symb }
  else { color = print.error.color; symb = print.error.symb }

  !status.silent && console.log(pad(), symb, color(tested.name), '('+ formatDuration(tested.duration) +')')
}

function onDone(end) {
  var failed = end.timeouts.length > 0 || end.failures.length > 0

  console.log('')

  if (end.timeouts.length > 0) {
    console.log('')
    console.log(' ', print.timeout.symb, print.timeout.color(end.timeouts.length + ' of ' + status.start.tests + ' tests timeout after', formatDuration(status.timeout), ':'))
    end.timeouts.forEach(function (tested) {
      console.log('')
      console.log(' ', tested.name)
    })
  }

  if (end.failures.length > 0) {
    console.log('')
    console.log(' ', print.error.symb, print.error.color(end.failures.length + ' of ' + status.start.tests + ' tests failed:'))
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
    console.log(' ', print.error.symb, print.error.color('Failure:'), msg)
  } else {
    console.log('')
    console.log(' ', print.success.symb, print.success.color('All ' + status.start.tests + ' tests passed'))
    if (end.skipped.length > 0) {
      console.log(' ', print.skipped.color('(but you skipped ' + end.skipped.length + ' of them)'))
    }
  }

  status.endedAt = new Date()
  console.log('')
  console.log(' ', chalk.bold('Duration:'), formatDuration(status.endedAt - status.startedAt))

  status.done(failed)
}

module.exports = {
  init: init
}
