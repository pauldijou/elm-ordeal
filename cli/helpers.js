(function (window) {
  function worker(elmInstance, flags) {
    if (!elmInstance) { throw new Error('Could not find the Elm instance') }

    var keys = Object.keys(elmInstance)
    if (keys.length !== 1) {
      throw new Error('elm-ordeal can only run tests on a program with exactly one main function but your Elm instance have ' + keys.length + ' of them: ' + keys)
    }

    return elmInstance[keys[0]].worker(flags)
  }

  function port(runner, portName) {
    var ports = Object.keys(runner.ports || {})

    if (ports.length === 0) {
      throw new Error('You main test must expose a port for elm-ordeal to send events')
    } else if (ports.length === 1) {
      return runner.ports[ports[0]]
    } else {
      if (!portName) {
        throw new Error('You must specify a [port] among the CLI argument to specify which one is the correct port to use')
      }
      if (indexOf(ports, portName) < 0) {
        throw new Error('Your Elm port [' + portName + '] is not among the module ports: ' + ports)
      }

      return runner.ports[portName]
    }
  }

  function noop() {}

  function subscribe(elmPort, config) {
    elmPort.subscribe(function (event) {
      var fn

      if (event.target === 'test') {
        if (event.atStart) { fn = config.onTestStarted }
        else { fn = config.onTestDone }
      } else if (event.target === 'suite') {
        if (event.atStart) { fn = config.onSuiteStarted }
        else { fn = config.onSuiteDone }
      } else {
        if (event.atStart) { fn = config.onStarted }
        else { fn = config.onDone }
      }

      if (!fn) { fn = noop }
      fn(event.value)
    })
  }

  var ordeal = {
    worker: worker,
    port: port,
    subscribe: subscribe
  }

  if (typeof window !== 'undefined') {
    window.ordeal = ordeal
  }

  if (typeof module !== 'undefined' && typeof module.exports !== 'undefined') {
    module.exports = ordeal
  }
})(typeof window !== 'undefined' ? window : global)
