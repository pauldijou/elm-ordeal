var chalk = require('chalk')
var symbols = require('log-symbols')

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

module.exports = {
  formatDuration: formatDuration,
  print: {
    success: { color: chalk.green,  symb: symbols.success },
    error:   { color: chalk.red,    symb: symbols.error },
    skipped: { color: chalk.blue,   symb: symbols.info },
    timeout: { color: chalk.yellow, symb: symbols.warning }
  }
}
