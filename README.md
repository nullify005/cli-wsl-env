# cli-wsl-env

## Overview

A collection of script & ansible files which build + manage an Ubuntu based WSL development
environment on windows.

Traditionally I would use something like Vagrant for this, but WSL seems fairly light and
has decent integration with the host system.

## Using

```shell
.\WSL-Ubuntu-Setup.ps1 -Action install -Name <name>
```

## Syncing the dotfiles

```shell
chezmoi init https://github.com/nullify005/dotfiles.git
bw login nullify005@gmail.com
```

Set the session as stated

```shell
chezmoi diff
chezmoi apply
. ~/.zshrc
```

Then reset the chezmoi remote git to be `git@github.com:nullify005/dotfiles.git` so that it
starts using the ssh keys.

## Cleaning up

```shell
wsl --unregister <name>
```

## Updating WSL

```shell
wsl --update
```
