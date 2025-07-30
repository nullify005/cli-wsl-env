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

## Cleaning up

```shell
wsl --unregister <name>
```