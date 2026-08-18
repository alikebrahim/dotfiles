# Diagnostic report — SSH key moved from 1Password to `~/.ssh/primary_key`

**Date:** 2026-08-15 · **Status:** SSH auth fixed; git commit signing still pending

## Summary

The ed25519 key moved out of 1Password into a plain file (`~/.ssh/primary_key`,
no passphrase, mode 600). The key itself is healthy and matches the configured
git signing key exactly. Two configs still referenced the 1Password SSH agent
(`~/.1password/agent.sock`, which no longer exists). The SSH client config has
been fixed; the git signing config has **not** — commits still fail.

## Findings

| # | Area | State | Evidence |
|---|---|---|---|
| 1 | SSH auth | ✅ **Fixed** — `~/.ssh/config` now uses `IdentityFile ~/.ssh/primary_key` + `IdentitiesOnly yes` on all hosts | `ssh git@netmaster` authenticates with no agent; `git ls-remote net-origin` works |
| 2 | Git commit signing | ❌ **Broken** — `~/.config/git/1password-signing.gitconfig` still sets `gpg.ssh.program=/opt/1Password/op-ssh-sign` and `user.signingkey` as a public-key *string* (agent-only) | `git commit` fails: `1Password: Could not connect to socket. Is the agent running?` |
| 3 | Signature verification | ⚠️ Optional — `gpg.ssh.allowedSignersFile` not set | `git log --show-signature` can't verify; not required to create signatures |

## Fix proven to work (throwaway-repo test)

```ini
[user]
    signingkey = /home/alikebrahim/.ssh/primary_key      # path, not key string
[gpg]
    format = ssh
[gpg "ssh"]
    program = /usr/bin/ssh-keygen
    allowedSignersFile = /home/alikebrahim/.ssh/allowed_signers   # optional
[commit]
    gpgsign = true
```

With these values, `git commit` produces a real SSH signature with no agent and
no passphrase (confirmed in the raw commit object). A `~/.ssh/allowed_signers`
file with one line (`* ssh-ed25519 AAAAC3…SFKWsV`) enables verification.

## Notes

- **Sandbox quirk:** in the dev sandbox, git's signing read-back fails when the
  buffer lives in `/tmp`; setting `TMPDIR` to a workspace dir fixes it. Not an
  issue on the host.
- **Dotfiles:** both configs are Stow/Syncthing-managed symlinks — edits
  propagate to all synced machines, each of which needs `~/.ssh/primary_key`.
- **Fallout:** the earlier prototype commit `ed72e42` is unsigned; re-sign with
  `git commit --amend -S` once finding #2 is fixed.
