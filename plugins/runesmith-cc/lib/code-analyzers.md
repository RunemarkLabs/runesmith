# Code Analyzer Registry

Source of truth for per-language code analysis in `runesmith-cc:code-tech-debt`. Each language entry defines: detection signal, preferred analyzer tool, fallback heuristic, and findings categories covered.

This file is shipped as part of `runesmith-cc/lib/` and deployed alongside the `code-tech-debt` skill into `{PROJECT}.cc/.claude/skills/code-tech-debt/` by `runesmith-cc:head`. The skill reads from this registry to know which analyzers to run per detected language.

## Registry format

Each entry:

```
### {Language}

**Detection:** how the skill identifies this language in a repo
**Preferred tool:** the recommended analyzer + install/invoke command
**Fallback heuristic:** what to do when the tool isn't installed
**Categories:** which findings the analyzer surfaces (unused-export, unused-import, unreferenced-file, unused-dep, dead-branch, unused-component, unused-route)
**Cross-reference checks:** framework-specific patterns to verify a finding is truly unused
```

## Core languages (v1)

### TypeScript

**Detection:**
- `tsconfig.json` exists at repo root, OR
- `package.json` has `typescript` in `devDependencies` / `dependencies`, OR
- `.ts` / `.tsx` files comprise >10% of source files

**Preferred tool:** [`ts-prune`](https://github.com/nadeesha/ts-prune)
```
npx ts-prune
```
Reports unused exports across the project. Honors `tsconfig.json` paths.

**Fallback heuristic:**
For each `export` statement in `.ts` / `.tsx` files, grep for the exported name as an import token across the tree (excluding the defining file and node_modules). No external usage → flag as unused-export. Note: this misses dynamic imports.

**Categories:** unused-export, unused-import (with eslint), unreferenced-file

**Cross-reference checks:**
- Dynamic imports: `import(...)` with template strings - grep for the file basename as a string
- Re-exports through barrel `index.ts` files - trace the re-export chain before flagging
- Type-only exports used in `.d.ts` consumers - verify against declaration files

---

### JavaScript / Node.js

**Detection:**
- `package.json` exists with no `typescript` dep
- `.js` / `.mjs` / `.cjs` files comprise the bulk of source

**Preferred tool:** combination
- [`depcheck`](https://github.com/depcheck/depcheck) for unused dependencies
```
npx depcheck
```
- [`eslint`](https://eslint.org/) with `no-unused-vars` rule for unused imports/variables
```
npx eslint --rule '{"no-unused-vars":"warn"}' --no-eslintrc .
```

**Fallback heuristic:**
- Unused deps: parse `package.json` `dependencies` + `devDependencies`. For each, grep for `require('{name}')` and `import .* from '{name}'` across the source tree. No match → flag.
- Unused imports: regex `^import .* from` then check usage in the same file's body.

**Categories:** unused-dep, unused-import, unused-export (via eslint plugins), unreferenced-file

**Cross-reference checks:**
- `package.json` `scripts` may reference binaries from deps (e.g. `webpack`, `prettier`) - those deps are alive even without imports
- Runtime requires via dynamic strings - grep for the package name as a string in non-code config (`.env`, `webpack.config.js`)

---

### React

**Detection:**
- `react` or `react-dom` in `package.json` dependencies
- `.tsx` / `.jsx` files present

**Preferred tool:** combination of ts-prune (for exports) + custom AST walk via `@typescript-eslint/parser` for component-specific patterns

**Fallback heuristic:**
- For each `export` of a React component (PascalCase identifier returning JSX), grep for `<ComponentName` across `.tsx` / `.jsx` files and for `import ComponentName` references
- For component props interfaces, check if every defined prop is used in the component body

**Categories:** unused-component, unused-prop, unreferenced-component-file

**Cross-reference checks:**
- Components rendered dynamically via `React.createElement(ComponentMap[type], ...)` - grep for the component name as an object value
- Components passed as props (`<Parent renderItem={MyComponent} />`)
- Components exported from a barrel `index.ts` and consumed via `import { Foo } from './components'`

---

### Next.js

**Detection:**
- `next.config.{js,ts,mjs}` at repo root
- `next` in `package.json` dependencies

**Preferred tool:** custom analysis (no canonical tool; build heuristics from Next conventions)

**Fallback heuristic:**
- **Pages router (`pages/`)**: every `pages/*.tsx` / `pages/*.js` is implicitly a route. Files not imported anywhere AND not in `pages/` may be orphans.
- **App router (`app/`)**: every `app/**/page.{tsx,js}`, `layout.{tsx,js}`, `loading.{tsx,js}`, `error.{tsx,js}` is a framework-recognized file. Non-framework files in `app/` that aren't imported by a framework file may be orphans.
- **API routes (`pages/api/`, `app/api/**/route.{ts,js}`)**: framework-recognized. Files in these dirs that don't match the convention may be orphans.
- **Middleware** (`middleware.{ts,js}` at root): single instance; flag duplicates as orphans.
- **`getStaticProps` / `getServerSideProps`**: pages exporting these are alive (Next consumes them at build time).

**Categories:** unreferenced-page, unused-api-route, orphaned-layout, dead-middleware

**Cross-reference checks:**
- A `_app.tsx` / `_document.tsx` / `_error.tsx` is always alive (framework conventions)
- Files in `public/` are static assets, not code - skip
- `middleware.ts` matchers may reference paths not in the routing tree - surface as informational

---

### Python

**Detection:**
- `pyproject.toml`, `setup.py`, `setup.cfg`, `requirements.txt`, or `.python-version` at repo root
- `.py` files in source

**Preferred tool:** [`vulture`](https://github.com/jendrikseipp/vulture)
```
pip install vulture
vulture {repo-root}
```
Reports unused functions, classes, variables, and unreachable code.

**Fallback heuristic:**
- For each top-level function/class definition, grep for its name as a call (`name(`) or attribute access (`.name(`) elsewhere
- For imports (`import x`, `from y import x`), check usage in the same module
- Unused dependencies: parse `pyproject.toml` `[project.dependencies]` or `requirements.txt`; grep `import {pkg}` and `from {pkg} import` for each

**Categories:** unused-function, unused-class, unused-import, unreachable-module, unused-dep

**Cross-reference checks:**
- Decorators like `@app.route(...)` mark functions alive even if no direct call exists - recognize common framework decorators (Flask, FastAPI, Django views, Click commands)
- Dunder methods (`__init__`, `__str__`, etc.) are framework-called - don't flag
- Entry points declared in `pyproject.toml` `[project.scripts]` - those functions are alive
- Test discovery patterns (`test_*.py`, `*_test.py`) - pytest auto-discovers; functions starting with `test_` are alive

---

## Extension pattern

To register a new language (e.g. Go, Rust, Java, Ruby):

1. **Detection** - list the signals (config files, manifest entries, file extensions)
2. **Preferred tool** - name the analyzer, install command, invocation
3. **Fallback heuristic** - describe the grep/AST pattern for when tool missing
4. **Categories** - declare which findings categories the language supports
5. **Cross-reference checks** - list framework-specific aliveness patterns

Each new entry follows the same template. The `code-tech-debt` skill reads this registry on every run; no code change to the skill itself is needed for additive language support.

## Anti-patterns to avoid

- **Flagging without cross-reference.** Always run the per-language cross-reference checks before high-confidence flags. Framework conventions (Next.js routing, Flask decorators, Django settings) make many "unused" exports actually alive.
- **Auto-installing analyzers.** Recommend; never install. The user owns their environment.
- **Touching git history.** Stage deletions (`git rm`) - never commit, never push. The user decides when to commit.
- **Whole-tree scans on big repos.** Default to entry-point graph; surface `--deep` as an opt-in.
- **Treating absence of import as proof of unused.** Dynamic loaders (React lazy, Next.js dynamic, Python importlib) defeat static analysis. Always cross-reference before high-confidence flags.

## Findings categories (canonical names)

- `unused-export` - exported symbol with no importers
- `unused-import` - imported symbol unused in the file
- `unreferenced-file` - file with no incoming references
- `unused-dep` - package in manifest, no imports
- `dead-branch` - code after `return` / unreachable conditional
- `unused-component` - React component with no usages
- `unused-prop` - defined prop never read in component
- `unreferenced-page` - Next.js page outside the routing graph
- `unused-api-route` - Next.js API handler unreferenced
- `unused-function` - Python function with no callers
- `unused-class` - Python class never instantiated or imported
- `unreachable-module` - Python module no other module imports

Use these names consistently across analyzers so the skill's report format stays stable.
