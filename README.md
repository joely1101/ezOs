```
There are many build environment such as buildroot,yocto,openwrt,nxp lsdk.
We can use docker to create the OS.
But it is not eazy for new docker user.
Create a wrap script for ezsy use docker.
setup:

mkdir -p ~/.local/bin
git -C ~/.local/ clone https://github.com/joely1101/ezOs.git
ln -sf ~/.local/bin/ ~/.local/ezOs/ezOs
#note: CAN NOT USE COPY, MUST symbolic link
sudo ln -sf ~/.local/ezOs/ezOs.bash_complete /etc/bash_completion.d/ezOs.bash_complete

usage:
#ezOs update  
#ezOs ls
ubuntu
buildroot
#ezOs login buildroot


2.if you want docker to emulate other cpu(arm64/mips...), please enable qemu static
sudo apt-get install -y qemu-user-static
docker run --rm --privileged multiarch/qemu-user-static --reset -p yes

```
