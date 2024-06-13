# Craft
Craft is a turn-based resource management and crafting strategy game on the Ethereum blockchain. Players begin by manually acquiring simple resources from the world around them and progress through the game by developing the technology required to craft resources of increasing complexity. Craft is based on the [progression of technological development in prehistory](https://en.wikipedia.org/wiki/Timeline_of_historic_inventions) and influenced by turn-based strategy games like Civilization.

## Status

Craft is currently in the early stages of development. The game is not yet fully playable, but maps and resources can be generated for a user's Ethereum address.

## Components

- **Resource**: ERC721 tokens modeling items in the Craft world. Resources come in three types: simple materials that require no pre-requisites, complex materials that are crafted from other resources, and tools that assist in the production and acquisition of other resources.
- **Maps**: A 2D grid of hexagonal tiles representing the Craft world. Each tile has a type (e.g. "forest", "mountain", "river") and a set of resources that may be acquired from it.
- **Technology**: Soulbound ERC721 tokens that model the knowledge required to craft a complex resource or associated process.
- **XP**: ERC20 token acquired from interacting with the Craft world. $XP is used to develop **technology**.
- **Epoch**: A window of time (currently 12 hours) during which all players may submit their actions for the in-game turn. In each turn, a player may perform up to one resource action (e.g. "forage", "hunt", "mine") and one craft or develop action (e.g. "craft stone axe", "develop weaving").

![Craft Map](./etc/example-map.svg)
