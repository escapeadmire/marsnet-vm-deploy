# MarsNet VM Deploy

A public installer and Cloudflare-hosted setup page for an Ubuntu VM. The installer adds Tailscale with Tailscale SSH, Homebrew, GitHub CLI (`gh`), and OpenCode.

## Run from an Ubuntu VM

Use a normal sudo-capable Ubuntu user, not `root`. Download and review the public script before running it:

```bash
curl -fsSLo /tmp/marsnet-vm-install.sh https://vm-deploy.mars-net.ca/install.sh
cat /tmp/marsnet-vm-install.sh
bash /tmp/marsnet-vm-install.sh
```

The script requires an interactive terminal. It signs the VM into Tailscale by showing an authentication URL, enables Tailscale SSH, then opens OpenCode. Use `/connect` in OpenCode to authenticate with your provider. It does not store or request Tailscale, OpenCode, GitHub, or Cloudflare secrets, and it does not run `gh auth login`.

The script is designed to be rerun. It downloads the official Tailscale and Homebrew installer scripts over HTTPS at run time, then installs the current `gh` and OpenCode Homebrew packages.

## Security notes

- This repository and hosted installer are public. Review the script before running it.
- Tailscale SSH depends on your tailnet SSH/access policy. The script does not change that policy.
- After verifying Tailscale SSH access, restrict or close inbound TCP port 22 in the Azure Network Security Group. Do not remove your current access path until Tailscale is confirmed working.
- The Homebrew PATH setup is added idempotently to the user's `.bashrc` or `.zshrc`; start a new shell if `brew` is not available in another session.

## Cloudflare hosting

`wrangler.jsonc` configures an assets-only Worker named `marsnet-vm-deploy`, serving `public/` on the custom domain `vm-deploy.mars-net.ca`. Cloudflare must have an active `mars-net.ca` zone, and the hostname must not have a conflicting DNS record. The custom domain configuration lets Cloudflare create the required DNS record and TLS certificate when deployed.

After pushing this repository to GitHub, connect it in **Cloudflare Dashboard → Workers & Pages → Create application → Import a repository**. Use the repository root as the root directory, leave the build command blank, and use `npx wrangler deploy` as the deploy command. Select `main` as the production branch. Subsequent pushes to `main` will deploy the updated site and installer.

To check or run locally:

```bash
npm ci
npm run check
npm run dev
```

`npm run deploy` deploys to Cloudflare and requires an authenticated Cloudflare account with access to the `mars-net.ca` zone.
