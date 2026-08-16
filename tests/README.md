# Unit tests

Zero dependency bash unit tests: no framework, no network, no Xcode and no
Android NDK are needed, so the suite runs on both macOS and Linux.

```bash
./tests/run-tests.sh              # everything
./tests/run-tests.sh parse-arguments correct-pc   # only matching files
```

Each test function runs in its own temporary directory, in a subshell, with
external commands (`curl`, `unzip`, `pkg-config`, `sysctl`, `xcrun`, ...)
replaced by stubs placed at the front of `PATH`. Git operations are exercised
against local repositories created on the fly.

Layout:

| file | scope |
| --- | --- |
| `lib/harness.sh` | test runner, assertions, isolation |
| `lib/stubs.sh` | command stubs and fixture builders |
| `test-parse-arguments.sh` | `tools/parse-arguments.sh` |
| `test-prepare-build-workspace.sh` | `tools/prepare-build-workspace.sh` |
| `test-export-host-env.sh` | `tools/export-{apple,android}-host-env.sh` |
| `test-export-pkg-config-dir.sh` | `tools/export-{apple,android}-pkg-config-dir.sh` |
| `test-ffconfig-auto-detect.sh` | `configs/ffconfig/auto-detect-third-libs.sh` |
| `test-correct-pc.sh` | `do-install/correct-pc.sh` |
| `test-do-install.sh` | `do-install/*` |
| `test-do-init.sh` | `do-init/*` |

Adding a test: create `tests/test-<name>.sh` and define functions named
`test_*`; they are discovered automatically.
