# The Vessel

**The Vessel** is a user-controlled dynamic onchain NFT system built around programmable payloads, modular Machines, curated Relics, and secondary outputs like Sequences.

Rather than treating an NFT as a fixed media object, The Vessel treats each token as a living container of state, behavior, and interpretation. A craft can hold its own payload, delegate control, route through Machines, read from Relics, and expose its resulting data to renderers and other contracts.

---

## Core idea

The Vessel is built around a simple but flexible premise:

- a token can hold or point to data
- that data can be changed, interpreted, or generated through different systems
- renderers and downstream contracts can read that data and turn it into visual, sonic, or temporal outputs

This makes the NFT less like a static collectible and more like a programmable instrument.

---

## System overview

### Token contract
The main ERC-721 contract is the center of the system.

It manages:
- minting / claiming
- token ownership
- token state
- payload storage and retrieval
- selection or routing of Machines
- interaction rules for holders and delegates
- the main read surface for renderers and connected systems

In practice, the token contract is the primary source of truth.

### Machines
Machines are modular contracts that generate, transform, interpret, or route payload data.

A Machine can:
- create net new data or patterns
- process token state
- process external onchain data
- reinterpret an existing payload
- provide a live or dynamic output based on tokenId, block context, or other logic

Machines let a craft become more than stored bytes. They allow behavior.

### Relics
Relics are curated external entries that can be read by the token system.

Unlike holder-controlled token state, Relics allow specific outputs or payload references to be maintained externally and intentionally. They act more like authored or curated anchors inside the broader system.

### Renderer
The renderer reads from the token contract and turns resolved payload data into an output format.

Depending on the piece, that output may be:
- image
- interactive media
- HTML
- audio
- metadata for downstream interpretation

The renderer is not the source of the work. It is the interpreter of the token’s current state.

### Sequences
Sequences are on a secondary ERC-1155 layer tied to timing and state inside the main 721 system.

Rather than existing as a separate disconnected collection, Sequences reads from Vessel state and extends the ecosystem into additional works with their own rendering logic.

---

## Mental model

A simplified flow looks like this:

`holder / delegate / system choice -> token state -> machine or relic resolution -> craftToPayload() -> renderer or downstream reader`

Another way to think about it:

- **the token contract** decides what a craft currently is
- **Machines and Relics** shape what data is returned
- **renderers and Sequences** decide how that data is experienced

---

## What makes The Vessel different

The Vessel is not just a collection of tokens with metadata.

It is a contract system for:
- user-influenced dynamic media
- modular generative logic
- composable payload-based art
- onchain interpretation layers
- connected outputs across multiple contracts

The emphasis is on dynamic art, programmable media and evolving onchain state rather than static collectible objects.

---

## Repository structure

Current core contracts:

- `vessel_token.sol` — main ERC-721 token contract, storage, logic, and read surface
- `vessel_machine_entropy.sol` — example / current Machine implementation
- `vessel_relics.sol` — Relic storage and retrieval layer
- `vessel_renderer.sol` — rendering contract that interprets token state
- `vessel_sequences.sol` — secondary ERC-1155 system tied to Vessel data
- `LibString.sol` — string utilities
- `base64.sol` — base64 encoding utilities

As the system grows, this repo may expand to include more Machines, renderers, and documentation.

---

## How to read the system

A good order for understanding the contracts is:

1. `vessel_token.sol`
2. `vessel_relics.sol`
3. `vessel_machine_entropy.sol`
4. `vessel_renderer.sol`
5. `vessel_sequences.sol`

Start with the token contract first. It defines the primary structure the other parts plug into.

---

## Design principles

The Vessel is guided by a few core ideas:

- **state matters**  
  The current output of a token is a function of real contract state, not just a fixed asset.

- **users can participate**  
  Holders are not only viewers. In many cases they help determine what a craft becomes.

- **modularity matters**  
  Machines should be swappable, extensible, and capable of very different behaviors.

- **onchain media can be programmable**  
  Art and music onchain do not need to be static files. They can be systems.

- **rendering is interpretation**  
  A payload is not the final artwork by itself. It becomes artwork through a renderer or reader.

---

## Status

The Vessel is an evolving contract ecosystem.

This repository contains the core architecture for:
- the main token system
- machine routing / generation logic
- relic-based external entries
- rendering
- sequence-based secondary outputs

Some parts are canonical core infrastructure, while other parts may remain experimental as the system develops.

---

## Development

This repo is currently focused on the contracts themselves.

Planned improvements to the public repo include:
- expanded documentation
- architecture diagrams
- tests
- deployment scripts
- network addresses
- example Machine implementations
- clearer build / verification instructions

---

## Roadmap for the repo

Near-term goals for improving this repository:

- better formatting and documentation across all contracts
- public explanation of the Machine patterns
- examples for writing new Machines
- explanation of how payload resolution works
- tests for key token / machine / relic behavior
- published addresses and versioned releases

---

## Contributing / following along

This repo is currently best understood as the core public codebase for The Vessel.

As documentation improves, it will become easier for:
- collectors to understand the system
- developers to inspect architecture
- artists to study or build related patterns
- collaborators to extend the Machine model

---

## License

To be added.

---

## Contact

Built by dav / @producedbydav

More documentation and examples coming soon.
