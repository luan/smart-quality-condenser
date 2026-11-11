# Smart Quality Condenser

Upgrade items in bulk and keep a chosen stock of higher-quality items available through logistic robots.

## How to use

1. Research and build a quality condenser. Supply power and quality modules, and place it in roboport logistic coverage.
2. Open the condenser and select **Targets**.
3. Click an empty slot, choose an item and quality, and enter the **Stock to keep**. Press **Enter** or **Confirm**.

Each slot shows the item, quality badge, and stock amount. Click a slot to edit it, or right-click to remove it. Each condenser has its own targets, which also copy with blueprints and settings copy/paste.

For example, **50 rare beacons** keeps 50 rare beacons available in the logistic network. Robots deliver lower-quality beacons and collect the finished ones. Taking finished items from storage creates demand again. Multiple items and qualities can run together.

## Requirements and behavior

- Logistic robots, lower-quality items in provider, storage, or eligible buffer chests, and room to store finished items.
- No external combinators, chests, inserters, or circuit wires are needed.
- Quality modules determine the upgrade yield. A small batch with a low upgrade chance may need more items before it can produce an upgrade.
- Targets must use an unlocked quality above Normal. Full output storage pauses the condenser; robot delivery timing can produce small surpluses.
- Turn **Automatic logistics** off to use the condenser manually.

## Existing saves

This is a standalone fork of [Quality condenser (forked)](https://mods.factorio.com/mod/quality-condenser-forked). Disable that mod when enabling this one. Existing condensers, inventories, modules, and blueprints are preserved.

Upgrading from 0.1.0 moves target-combinator settings into the paired condenser and refunds the retired combinator's ingredients.

## Credits

- Original Quality condenser: Patrick **Quezler** Mounier.
- Previous Factorio 2.1 fork: **doanbalat**.
- Graphics: **Hurricane046**; upstream graphics integration: **Xorimuth**.
- Smart logistics and maintenance: **Luan**.

Code is distributed under the upstream MIT license. See `LICENSE`.
