# Personal Electronics & AI-EDA Repository Catalog

> Maintainer: `yniantongtian-oss`  
> Last reviewed: 2026-07-28  
> Purpose: organize recently added electronics, KiCad, PCB automation, component-library, and coding-agent repositories without mixing unrelated upstream codebases.

## Recommended working stack

Use the repositories in the following order when building an AI-assisted EDA workflow:

1. **Primary EDA agent:** [`eda-agent`](https://github.com/yniantongtian-oss/eda-agent)
2. **Compact KiCad-focused alternative:** [`kicad-mcp-1`](https://github.com/yniantongtian-oss/kicad-mcp-1)
3. **Broad KiCad feature reference:** [`KiCAD-MCP-Server`](https://github.com/yniantongtian-oss/KiCAD-MCP-Server)
4. **Manufacturing and panelization:** [`KiKit`](https://github.com/yniantongtian-oss/KiKit)
5. **Symbols, footprints, and 3D assets:** [`hardware-components`](https://github.com/yniantongtian-oss/hardware-components)
6. **Code-context retrieval for agents:** [`contextgraph`](https://github.com/yniantongtian-oss/contextgraph)

## Repository roles

| Repository | Role | Recommended status | Notes |
| --- | --- | --- | --- |
| [`eda-agent`](https://github.com/yniantongtian-oss/eda-agent) | Main AI-to-EDA control layer | **Primary / active evaluation** | Supports live Altium interaction and an additional KiCad backend. Keep this as the main integration candidate rather than merging every MCP implementation into it. |
| [`kicad-mcp-1`](https://github.com/yniantongtian-oss/kicad-mcp-1) | Focused KiCad MCP workflow | **Alternative / benchmark** | Smaller tool surface and a strong automated-test emphasis. The `-1` suffix is unclear; a future rename such as `kicad-mcp-blwfish-mirror` would make its origin and purpose easier to understand. |
| [`KiCAD-MCP-Server`](https://github.com/yniantongtian-oss/KiCAD-MCP-Server) | Large KiCad MCP implementation | **Feature reference / compatibility testbed** | Broad tool coverage. Keep separate from `kicad-mcp-1`; compare capabilities through adapters and tests instead of copying modules between the two projects. |
| [`KiKit`](https://github.com/yniantongtian-oss/KiKit) | Panelization and manufacturing automation | **Tooling dependency / reference** | Useful after PCB layout is complete: panelization, Gerber export, multi-board workflows, and repeatable fabrication output. |
| [`hardware-components`](https://github.com/yniantongtian-oss/hardware-components) | KiCad symbols, footprints, metadata, and 3D models | **Read-only asset mirror** | Very large generated asset repository. Avoid editing generated files manually and avoid embedding it directly inside another repository. Prefer sparse or filtered clones when possible. |
| [`contextgraph`](https://github.com/yniantongtian-oss/contextgraph) | Python code-graph retrieval for LLM agents | **Reusable foundation / active development** | Not an EDA application itself. It can provide focused repository context to coding agents working on the EDA projects. Keep its API generic and independent. |

## Do not merge these repositories directly

The three AI-EDA repositories overlap, but they represent different architectures and maintenance models:

- `eda-agent` is the best candidate for a unified user-facing control layer.
- `kicad-mcp-1` is useful as a compact, test-heavy KiCad implementation.
- `KiCAD-MCP-Server` is useful as a broad feature and protocol reference.

A safer integration model is:

```text
AI client
   |
   v
Unified command / evaluation layer
   |--------------------|----------------------|
   v                    v                      v
eda-agent          kicad-mcp-1        KiCAD-MCP-Server
   |
   v
KiCad / Altium projects
   |
   +--> KiKit manufacturing pipeline
   +--> hardware-components asset source
```

## Maintenance rules

### Upstream-derived repositories

- Preserve the original license, copyright notices, and attribution.
- Record the upstream repository URL in the README if it is not already obvious.
- Keep personal modifications on dedicated branches.
- Pull upstream changes before starting large local changes.
- Do not present an imported mirror as an independently authored project.

### Generated and large repositories

For `hardware-components`:

- Treat pipeline-generated commits and assets as immutable outputs.
- Put custom components in a separate small repository or clearly separated custom directory.
- Prefer `git clone --filter=blob:none` or sparse checkout when the full asset history is unnecessary.
- Do not commit temporary renders, caches, local KiCad rescue files, or editor backups.

### Naming

Current names mix `KiCAD`, `KiCad`, `kicad`, `main`, and `master`. For future original projects, use:

- Product spelling: **KiCad**
- Repository slugs: lowercase kebab-case, for example `kicad-agent-tools`
- Default branch: `main`
- Mirror suffix: `-mirror`
- Experimental fork suffix: `-lab`

## Suggested evaluation matrix

Before choosing one KiCad MCP implementation as the long-term base, test each project against the same board and score:

- Installation success on Windows
- KiCad version compatibility
- Schematic creation and modification
- PCB placement and routing
- DRC/ERC execution
- Symbol and footprint library handling
- Gerber, BOM, and manufacturing export
- Recovery after partial failure
- Test-suite quality
- Security boundaries for filesystem and subprocess access
- Documentation completeness

Store evaluation results in a separate `EDA_TOOL_EVALUATION.md` rather than editing upstream READMEs.

## Next cleanup actions

- [ ] Rename `kicad-mcp-1` to a descriptive mirror or lab name.
- [ ] Decide whether `eda-agent` is the main integration project.
- [ ] Add upstream metadata to every imported repository.
- [ ] Create one small repository for your own custom KiCad symbols and footprints.
- [ ] Keep `hardware-components` as an external asset source, not a normal development dependency.
- [ ] Add a shared benchmark board for comparing all EDA agents.
- [ ] Standardize CI, formatting, and security checks only in repositories you actively modify.

## Classification of the newly reviewed repositories

```text
AI / EDA control
├── eda-agent                 [primary candidate]
├── kicad-mcp-1               [compact alternative]
└── KiCAD-MCP-Server          [broad reference]

Manufacturing automation
└── KiKit

Component assets
└── hardware-components

Coding-agent infrastructure
└── contextgraph
```
