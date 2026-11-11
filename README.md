# Smart Quality Condenser

A standalone fork of [Quality condenser (forked)](https://mods.factorio.com/mod/quality-condenser-forked), originally created by [Quezler](https://mods.factorio.com/mod/quality-condenser). It upgrades items in bulk and adds automatic logistic stock targets.

## Use

1. Research and build a quality condenser. Add quality modules and power.
2. Craft **Condenser targets** and place it within 10 tiles of the machine, inside roboport logistic coverage.
3. Set item signals at the qualities and amounts to keep available in your logistic network.

For example, set rare beacons to 50, rare speed modules to 50, and uncommon gears to 100. Robots supply lower-quality items and collect finished products. Different items and different target qualities can run together, including multiple qualities of the same item.

There are no external chests, inserters, or circuit wires to configure. The controller contains a requester and an active-provider buffer; stacks move internally between those buffers and the machine. All deliveries to and from the factory use native logistic robots. Controller demand comes from actual inventories and robot reservations rather than saved running counters.

Higher available input qualities are used first. Requests remain visible when lower-quality stock is unavailable. Fulfilled or removed targets stop requesting, and leftovers return at their current quality. A full output pauses the machine to protect finished items. Only one target controller can own a machine.

The controller costs one constant combinator, one requester chest, and one active provider chest. The included `blueprint.txt` places a condenser, target controller, substation, and roboport; supply power and robots, then set your targets.

## Upgrade rules

The condenser retains the previous fork's power, recipe, module, research, spoilage, and upgrade-chance rules. Quality modules determine the upgrade yield. With a low upgrade chance, a small batch may be too small to produce even one upgraded item; the base machine then sleeps until its contents or setup changes. Normal-quality targets, locked quality tiers, and non-item signals are ignored. Robot delivery timing and mixed targets can produce small surpluses.

The configurable base quality, module slots, research bonuses, power consumption, and beacon modes remain available. This fork also retains the installed 2.1.3 beacon compatibility fixes.

## Existing saves

Disable **Quality condenser (forked)** when enabling this mod; they are alternative implementations and cannot run together. Existing condenser, item, recipe, startup-setting, and controller names are retained. The migration adopts existing inventories and rebuilds the previous fork's internal helpers, preserving machines, modules, contents, and blueprints. Existing ordinary condensers continue to work without a target controller.

## Credits and license

- Original Quality condenser: Patrick **Quezler** Mounier.
- Previous Factorio 2.1 fork: **doanbalat**.
- Graphics: **Hurricane046**; the upstream graphics integration credits **Xorimuth**.
- Smart logistics, integration, and maintenance of this fork: **Luan**.

Code is distributed under the upstream MIT license; see `LICENSE`. Upstream history and the original notes in `README_1.md` are retained.
