# WebTemplate

A Phoenix + Inertia.js (React, SSR) web app.

## Toolchain (mise)

Erlang, Elixir, and Node versions are pinned in `mise.toml`. Install
[mise](https://mise.jdx.dev), then from the repo root:

```bash
mise trust    # approve this repo's mise.toml (first time only)
mise install  # install the pinned Erlang, Elixir, and Node
```

With shell activation enabled (add `eval "$(mise activate zsh)"` to
`~/.zshrc`), mise switches to these versions automatically when you `cd`
into the repo.

## Getting started

To start your Phoenix server:

* Run `mix setup` to install and setup dependencies
* Start Phoenix endpoint with `mix phx.server` or inside IEx with `iex -S mix phx.server`

Now you can visit [`localhost:4000`](http://localhost:4000) from your browser.

Ready to run in production? Please [check our deployment guides](https://hexdocs.pm/phoenix/deployment.html).

## Learn more

* Official website: https://www.phoenixframework.org/
* Guides: https://hexdocs.pm/phoenix/overview.html
* Docs: https://hexdocs.pm/phoenix
* Forum: https://elixirforum.com/c/phoenix-forum
* Source: https://github.com/phoenixframework/phoenix
