(function (window) {
  var helpers = window.ordeal

  window.__karma__.start = function () {
    var karma = window.__karma__

    var runner = helpers.worker(Elm, {
      timeout: 5000
    })

    helpers.subscribe(helpers.port(runner), {
      onStarted: function onStarted(started) {
        karma.info({
          total: started.tests,
          specs: []
        })
      },
      onTestDone: function onTestDone(tested) {
        karma.result({
          id: tested.name,
          description: tested.name,
          suite: tested.suites,
          log: tested.success ? [] : [ tested.timeout ? 'Timeout' : tested.failure ],
          success: tested.success,
          skipped: tested.skipped,
          time: tested.skipped ? 0 : tested.duration
        })
      },
      onDone: function onDone(report) {
        karma.complete({
          coverage: window.__coverage__
        })
      }
    })
  }
})(typeof window !== 'undefined' ? window : global)
