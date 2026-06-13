# Frontend Pages: SSR vs. Client

Every page component lives under `assets/js/pages/` in one of two strategy
directories:

| Directory | Rendering | Use for |
| --- | --- | --- |
| `pages/ssr/` | Server-rendered (Node), then hydrated | Public, no-auth, SEO / first-paint pages |
| `pages/client/` | Client-only (rendered in the browser) | Authenticated, interactive, heavy pages |

The strategy directory is **stripped** from the Inertia page name, so
controllers don't care where a page lives: `render_inertia(conn, "Dashboard")`
resolves to `pages/client/Dashboard.tsx`, and `render_inertia(conn, "Home")`
resolves to `pages/ssr/Home.tsx`.

## Why the split exists

The Inertia SSR server is a pool of Node.js workers (`Inertia.SSR`, started in
`application.ex`). Each worker loads the **entire** server bundle into its own
V8 heap. Without a split, that bundle contains every page — including
authenticated, interactive ones that drag in heavy client-only dependencies
(rich editors, charting, drag-and-drop, realtime widgets). Multiply that by the
worker count and the Node side dominates memory on a small instance, for pages
that don't even benefit from server rendering.

Server rendering earns its cost only on pages where first paint and SEO matter —
i.e. **public pages a logged-out visitor or crawler hits**. Authenticated pages
sit behind a login, aren't indexed, and are typically interactive, so rendering
them on the client is both cheaper and simpler. Hence the rule:

- **Public (no auth) page → `pages/ssr/`.** Server-rendered for fast first paint
  and crawlable HTML.
- **Authenticated page → `pages/client/`.** Kept out of the SSR bundle entirely.

This keeps the SSR bundle small (only public pages and their dependencies),
which is the single biggest lever on the Node workers' memory footprint. The two
other levers are env vars: `SSR_POOL_SIZE` (worker count, default `2`) and
`NODE_OPTIONS=--max-old-space-size=160` (per-worker heap cap, set in the
Dockerfile).

## How it works under the hood

`build/generate-ssr-pages.js` scans both directories and emits two registries
(both gitignored — never edit them by hand):

- **`_pages.ts`** — the **client** manifest. Every page (ssr *and* client) as a
  lazy `() => import()` loader keyed by Inertia page name. Lazy imports let
  esbuild code-split one chunk per page, so the browser only downloads the page
  it navigates to. `app.tsx` resolves pages through this.
- **`_ssr_pages.ts`** — the **SSR** manifest. Static imports for `ssr/` pages
  only (the CJS server bundle can't do dynamic `import()`), plus a
  `ssrClientOnly` set listing the client-only page names. `ssr.tsx` resolves
  pages through this: a `ssr/` page renders normally; a name in `ssrClientOnly`
  renders as a server-side no-op (`() => null`) so the client takes over instead
  of crashing the render; a genuinely unknown name still throws.

The generator runs before both esbuild bundles in `mix assets.build` /
`assets.deploy` (the client bundle imports `_pages.ts`, the SSR bundle imports
`_ssr_pages.ts`), and a dev watcher (`build/watch-ssr-pages.js`) regenerates
them whenever a page file is added or removed.

## Adding a page

1. Decide: is it reachable without logging in? → `pages/ssr/`. Otherwise →
   `pages/client/`.
2. Drop the `.tsx` file in that directory (subfolders are fine, e.g.
   `pages/ssr/Auth/Login.tsx` → page name `Auth/Login`).
3. Render it from a controller with `render_inertia(conn, "Auth/Login")` — the
   strategy dir is not part of the name.

The registries regenerate automatically; you never touch `_pages.ts` or
`_ssr_pages.ts`.
