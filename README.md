# Smart Quality Condenser

A standalone fork of [Quality condenser (forked)](https://mods.factorio.com/mod/quality-condenser-forked), originally created by [Quezler](https://mods.factorio.com/mod/quality-condenser). It upgrades items in bulk and adds automatic logistic stock targets.

## Use

1. Research and build a quality condenser. Add quality modules and power, and place it inside roboport logistic coverage.
2. Open the condenser and select its **Targets** tab.
3. Click **Add target**, choose an item and its desired quality, and enter the **Stock to keep**. Choosing an upgraded quality enables **Automatic logistics**.

For example, set rare beacons to 50, rare speed modules to 50, and uncommon gears to 100. Robots supply lower-quality items and collect finished products. Different items and target qualities run together, including multiple qualities of the same item. Each condenser has its own targets.

The stock target is the amount available in that logistic network, not a lifetime production count. Taking items from storage creates demand again. Lower-quality inputs must be available to robots in provider, storage, or eligible buffer chests; the mod does not pull from belts or ordinary chests. Make room in logistic storage for finished items.

No external combinators, chests, inserters, or circuit wires are needed. The condenser owns hidden requester and active-provider buffers. Stacks move internally between those buffers and the machine; native logistic robots handle factory deliveries. Demand comes from actual inventories and robot reservations rather than saved running counters.

Higher available input qualities are used first. Requests remain visible when lower-quality stock is unavailable. Fulfilled or removed targets stop requesting, and leftovers return at their current quality. A full output pauses the machine to protect finished items. Turn **Automatic logistics** off to stop requests and use the condenser manually.

Targets are saved with the world, copied by blueprints and cloning, and can be copied between condensers with the standard copy/paste settings controls. The included `blueprint.txt` places a condenser, substation, and roboport. Supply power and robots, then set targets in the condenser.

Upgrading from 0.1.0 automatically moves target-combinator settings into the paired condenser, preserves its inventories and buffers, removes the old combinator, and refunds its three ingredients through the output buffer. The retired controller recipe is hidden; old blueprints containing it are still adopted when built near a condenser.

## Upgrade rules

The condenser retains the previous fork's power, recipe, module, research, spoilage, and upgrade-chance rules. Quality modules determine the upgrade yield. With a low upgrade chance, a small batch may be too small to produce even one upgraded item; the base machine then sleeps until its contents or setup changes. Normal-quality targets, locked quality tiers, and non-item signals are ignored. Robot delivery timing and mixed targets can produce small surpluses.

The configurable base quality, module slots, research bonuses, power consumption, and beacon modes remain available. This fork also retains the installed 2.1.3 beacon compatibility fixes.

## Existing saves

Disable **Quality condenser (forked)** when enabling this mod; they are alternative implementations and cannot run together. Existing condenser, item, recipe, startup-setting, and legacy controller names are retained. The migration adopts existing inventories and rebuilds the previous fork's internal helpers, preserving machines, modules, contents, and blueprints. Existing ordinary condensers continue to work without a target controller.

## Credits and license

- Original Quality condenser: Patrick **Quezler** Mounier.
- Previous Factorio 2.1 fork: **doanbalat**.
- Graphics: **Hurricane046**; the upstream graphics integration credits **Xorimuth**.
- Smart logistics, integration, and maintenance of this fork: **Luan**.

Code is distributed under the upstream MIT license; see `LICENSE`. Upstream history and the original notes in `README_1.md` are retained.
