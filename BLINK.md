# BearClawiOS Blink Status

BearClawiOS does not currently have a project-local `blink.toml`.

## Current State

- Build and test happen through Xcode and the local Apple toolchain.
- Deployment is currently an app distribution problem, not a Blink-managed service deployment.
- The mobile app depends on the Blink-managed homelab edge exposed by Tardigrade, BearClaw, and BearClawWeb.

## What This Means

- There is no project-local Blink build, deploy, rollback, or verify pipeline today.
- This file exists so the repo still fits the shared documentation contract and accurately states that Blink is an external dependency rather than a local deployment tool here.
