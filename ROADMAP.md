# Roadmap

- Use effect module to handle internal events
- Rewrite reporters in Elm, listening to effect module, no more ports for user
- `outputFile` config
- `watch` config
- `maxWorkers` config
- `notify` config
- Support glob pattern and multiple files
- Test orchestration in parallel
- Full dependency tree to run only tests depending on edited file
- Support multiple `only` and run only those
- Add hints to tests, display them in reports
- `Suite { name: String, only: Bool, tests: List Test }`
- `Test { name: String, only: Bool, hint: Maybe String, expectation: Expectation }`
