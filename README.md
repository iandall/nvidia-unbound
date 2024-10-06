# Nvidia Unbound - an alternative Nvidia driver installer for Linux #

## Introduction ##
To use Nvidia graphics on Linux, there are a number of options. There
is the open source driver *nouveau* which may lack features or support
for some chips or there are the proprietary drivers available from
Nvidia. Confusingly, Nvidia now offer an "open source" driver however,
it is just the kenel module which is open source. It still requires
user applications to link with proprietary, binary only, libraries to
perform *OpenGL* rendering.

Nvidia offer a linux driver installer which can be downloaded from
<https://www.nvidia.com/en-us/drivers/>. Many linux distributions or
3rd party providers package the Nvidia drivers essentially duplicating
the effect of downloading and running the Nvidia installer but more
conveniently. So why the need for another installer?

* Nvidia drivers don't like to co-exist with *nouveau* or even other
  versions of Nvidia drivers
* kernel modules must be the same version as the user libraries 
* different Nvidia chips require different drivers
* some Nvidia drivers may exhibit problems with some chips, so that
  the best driver depends on the chip
* the kernel modules for some Nvidia drivers won't build with current kernels
* `libGL.so` may be specific to various vendor drivers and have to be
  replaced when changing graphics cards or switching between *nouveau*
  and proprietary drivers. This last issue has been largely solved
  with the the advent of *glvnd*, a vendor neutral dispatch library, and *vulkan*.

If you need to support a variety of graphics chips, from the same
filesystem image, or from an immutable root file system, you need
another solution.

## Approach ##
The `nvidia-unbound` installer installs eveything possible, including
kernel modules in its own directory tree (by default
`/opt/ndvidia/<release>`). The correct kernel modules can be loaded
with a helper script and a drop in file in `/etc/modprobe.d`. The
correct Xorg driver module can be loaded by executing Xorg via a
wrapper which sets `-modulepath`, an alternate Xorg.conf can be used
by setting the `XORGCONFIG` environemnt variable and the correct
client libraries can be loaded by setting `LD_LIBRARY_PATH`.

This seems complicated, but works quite reliably in practice.

## Installation ##
Obtaining
Building
Installing
`nvidia-unbound` is implemented as as shell script and can be invoked stand alone (without installaton), 


