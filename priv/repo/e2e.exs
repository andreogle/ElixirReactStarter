# =============================================================================
# E2E fixture & cleanup script.
#
# Run by the Playwright global setup (assets/e2e/global-setup.ts) before the
# suite. It is *separate from* seeds.exs because it knows about test artefacts
# and is happy to DELETE them — seeds.exs must stay safe to run in any
# environment, including production, and must never destroy data.
#
# This template's flows don't need persistent fixtures: the registration spec
# signs up a fresh user through the UI, and the other specs mint their own
# confirmed users via `POST /dev/e2e/users` (a unique email per call). So all
# this script does is wipe per-run users left over from prior runs — anything
# matching the `e2e-test-...` pattern the dev endpoint and helpers use — so
# reruns start from a clean slate. Deleting a user cascades to their tokens.
#
# If your app grows fixtures that every spec relies on (an admin account,
# reference data, …), create them here idempotently (get-or-create).
#
# Refuses to run outside dev/test, and additionally requires :dev_routes (the
# same flag that exposes /dev/e2e/users) — so a misconfigured prod release
# can't reach this destructive code path even with MIX_ENV set wrongly.
# =============================================================================

unless Mix.env() in [:dev, :test] do
  raise """
  priv/repo/e2e.exs is a destructive fixture script and must NEVER run in \
  production. Refusing to run in MIX_ENV=#{Mix.env()}.
  """
end

unless Application.get_env(:elixir_react_starter, :dev_routes, false) do
  raise """
  priv/repo/e2e.exs requires :dev_routes to be enabled (the same config that \
  exposes the /dev/e2e/users provisioning endpoint). Refusing to run.
  """
end

import Ecto.Query

alias ElixirReactStarter.Accounts.User
alias ElixirReactStarter.Repo

require Logger

# Per-run E2E accounts always look like `e2e-test-...@...`. The cleanup
# refuses to touch anything outside this pattern so a misconfigured run can't
# wipe real dev data.
test_user_email_pattern = "e2e-test-%@%"

{users_deleted, _} =
  Repo.delete_all(from u in User, where: like(u.email, ^test_user_email_pattern))

Logger.info("E2E reset: cleared #{users_deleted} per-run test user(s).")
