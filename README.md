# SH4 DevEnv (GitPod / CodeSpace)
testing some full devenv with docker

## Usage
`docker pull pho3be/sh4devenvgitpod`

Once in, you'll be logged as "dev" user. You can there clone your repo and build it using make.
`sh4-elf-gcc` and `sh4eb-nofpu-elf-gcc` are included, along side with the HHK SDK (in /opt/cross) 

> Note: You can go sudo it you need to. Pass is `dev`

Alternatively you can rebuild it. If you setup a codespace with 8procs It'll build in 5 minutes

