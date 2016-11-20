
var _pauldijou$elm_ordeal$Native_Ordeal = function() {
  let runner
  if (typeof global === 'object' && global.ordeal && global.ordeal.runner) {
    runner = global.ordeal.runner
  } else if (typeof window === 'object' && window.ordeal && window.ordeal.runner) {
    runner = window.ordeal.runner
  }

  runner.ports.runnedTask.subscribe(function (task) {
    task.failure ? task.done.fail(task.failure) : task.done()
  })

  function $describe(name, fn) {
    describe(name, function () {
      return fn()
    })
  }

  function $test(name, fn) {
    it(name, function () {
      return fn()
    })
  }

  function $testTask(name, task) {
    it(name, function (done) {
      runner.ports.runTask.send({ task: task, done: done, failure: null })
    })
  }

  function $wrapExpectation(fn) {
    return F2(function (expectation, expected) {
      return expected[fn](expectation)
    })
  }

  return {
    describe: F2($describe),
    test: F2($test),
    testTask: F2($testTask),
    expect: expect,
    not: function (expected) { return expected.not },
    toBe: $wrapExpectation('toBe'),
    toEqual: $wrapExpectation('toEqual'),
    toMatch: $wrapExpectation('toMatch'),
    toBeDefined: $wrapExpectation('toBeDefined'),
    toContain: $wrapExpectation('toContain'),
    toBeLessThan: $wrapExpectation('toBeLessThan'),
    toBeGreaterThan: $wrapExpectation('toBeGreaterThan'),
  }
}()
