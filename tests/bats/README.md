# Vendored bats-core

Pinned copy of [bats-core](https://github.com/bats-core/bats-core) v1.13.0, MIT licensed.
See `LICENSE.md`.

Only `bin/`, `libexec/`, and `lib/` are vendored — the rest of the upstream tree
(tests, docs, docker, install scripts) is not needed at runtime.

## Upgrading

```bash
tmp=$(mktemp -d)
git clone --depth 1 --branch v<NEW_VERSION> https://github.com/bats-core/bats-core.git "$tmp"
rm -rf tests/bats/bin tests/bats/libexec tests/bats/lib
cp -r "$tmp/bin" "$tmp/libexec" "$tmp/lib" tests/bats/
cp "$tmp/LICENSE.md" tests/bats/LICENSE.md
rm -rf "$tmp"
```

Then update this file with the new version and run `./tests/bats/bin/bats tests/bash tests/contracts`.
