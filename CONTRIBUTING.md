# Development

## Validation


Run `lua tests/plan.lua` for demand-allocation checks. `tools/stage-test.py` builds an isolated native fixture from the release package, with test-only code and a guaranteed-upgrade module. Its 42,120-tick run exercises the built-in editor, 26 targets, mixed qualities, legendary output, replenishment, blocked output, removal cleanup, and the shipped blueprint. Never enable QA fixtures in a production world.

After packaging, run `python3 tools/stage-test.py --mods /path/to/mods --data /path/to/factorio/data` and execute the printed Factorio commands. Add `--save /path/to/checkpoint.zip` to test migration from an existing save against that checkpoint. Staging leaves the supplied mod directory and save untouched; choose a fresh `--output` for each run.

