# wrapper-guard fixtures

These files back the `test-wrapper-guards` workflow's manifest-downgrade
demonstration. GitHub serves them over https at
`raw.githubusercontent.com/<repo>/<sha>/ci/wrapper-guard-fixtures/...`, which is
what the dk0 wrapper accepts as a base URL.

- `ok/manifest-2.4.3.20.txt` (+ `.sig`) is the genuine signed dk engine manifest
  for version 2.4.3.20, fetched from the dk-dist registry. The green case pins
  2.4.3.20 and reads it, so the downgrade guard accepts a matching version.
- `downgrade/manifest-2.4.3.21.txt` (+ `.sig`) is the same genuine 2.4.3.20
  manifest under the 2.4.3.21 filename. The red case pins 2.4.3.21 and points the
  base URL here, so the wrapper fetches a manifest whose signature verifies but
  whose `version=` is 2.4.3.20, and the downgrade guard refuses it.

The signature stays valid because the manifest bytes are unchanged; only the
filename differs, which is the exact rollback the guard exists to catch.
