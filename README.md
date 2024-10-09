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
	versions of Nvidia's drivers
  * kernel modules must be the same version as the user libraries 
  * different Nvidia chip families require different drivers
  * some Nvidia drivers may exhibit problems with some chips or cards, so that
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
The _Nvidia Unbound_ installer installs eveything possible, including
kernel modules in its own directory tree (by default
`/opt/ndvidia/<release>`). The correct kernel modules can be loaded
with a helper script and a drop-in file in `/etc/modprobe.d`. The
correct Xorg driver module can be loaded by executing Xorg via a
wrapper which sets `-modulepath`, an alternate Xorg.conf can be used
by setting the `XORGCONFIG` environment variable and the correct
client libraries can be loaded by setting `LD_LIBRARY_PATH`.

This seems complicated, but works quite reliably in practice.

## Building and Installing ##

The latest version of this software can be obtained from
[GitHub](https://github.com/iandall/nvidia-unbound). Either clone the
repository or download and unpack a [ZIP
archive](https://github.com/iandall/nvidia-unbound/archive/refs/heads/master.zip).

The command `make install` will, by default, build and  install the
`nvidia-unbound` script and documentation under
`/usr/local`. Or:

    make
    make install

Alternate locations can be specified with
`prefix=<location`. Rebuilding the man page requires
[`help2man`](ftp://ftp.gnu.org/gnu/help2man/), however a pre-built man
page is included. Rebuilding the manpage can be suppressed (and the
dependency on `help2man` avoided) with `enable_documentation=no`.

Note that `prefix` here refers to the location where _Nvidia Unbound_
itself is installed and has no bearing on the locaton where the Nivida
driver components will eventually be stored.

_Nvidia Unbound_ is implemented as as shell script and for
testing purposes can be invoked stand alone (without installation).

## Installing Nvidia driver components ##
Firstly download the desired driver archive from [the Nvidia web
site](https://www.nvidia.com/en-us/drivers/) which will result in a
file normally of the form `NVIDIA-Linux-<arch>-<version>.run`.

Installation can be as simple as `nvidia-unbound
NVIDIA-Linux-<arch>-<version>.run`. This will unpack the Nividia
driver archive into a temporary directory and install the driver
according to the default options.

There are a plethora of options (see `man 1 nvidia-unbound` or `nvidia-unbound --help`).
To minimise confusion, options with a similary effect to options in the Nvidia installer have the same name.
The effective configuration (default configuration plus administrator configuration
plus command line options) is given by `nvidia-unbound --dump-config`.

The default configuration can be overridden by a configuration file
(by default `/usr/local/etc/nvidia-unbound.conf`). Most long command
line options, with the `--` prefix removed, can be used as
configuration parameters. The exceptions are:
dry-run, trace, quiet, dump-config, check, info, version and help.

A desired set of options can be made the default by
```
	nvidia-unbound [OPTIONS] --dump > /usr/local/etc/nvidia-unbound.conf
```
Initially it may be wise to run
```
	nvidia-unbound --trace --dry-run
```
to see what action _Nvidia Unbound_ will take.

### What goes Where? ###
The Nvidia driver installs many files which Ndivia categorises in 56
types (probably not an exhaustive list and more may be added). All
files the Nvidia installer creates are listed in a manifest file
(`.manifest` in the unpacked Nvidia driver archive). Each entry in the
manifest has a Source location, Mode and Type. Each Type has its own,
potentially different install location and other fields define
sub-directories, symbolic link targets etc. Nvidia Unbound parses the
manifest file and the target locations can be customised for each
Type.

Some files do not need to be installed at all and are excluded by default.

With respect to the goals of this project, files can be categorised.

1) Those files which can be installed in a per release tree
(`/opt/ndvidia/<release>` by default) pose no problems.

2) Those files which must be installed at a well known location but
have a release number somewhere in the full pathname (for example
`/lib/firmware/nvidia/560.35.03/gsp_ga10x.bin`), pose no problem for
some use cases, such as a root files system which is mutable but
requires multiple releases to be installed. For immutable root files
systems, additional configuration is required. For example:

   ```
        mkdir -p /opt/ndvidia/lib/firmware
        cp -ar /lib/firmware/nvidia /opt/ndvidia/lib/firmware
        rm -rf /lib/firmware/nvidia
        ln -s /opt/ndvidia/lib/firmware/nvidia /lib/firmware/nvidia
   ```
   can be done once (when the immutable root filesystem is created). Thereafter,
   it should be possible to install new releases without touching the root file system.
   
3) Those files which must be installed in a well known location and do _not_
have a release number in the full pathnames (for example
`/etc/OpenCL/vendors/nvidia.icd`) pose additional problems. These
files do not generally change from release to release. _Nvidia Unbound_
uses a replace-if-newer strategy for these files

Some files are not needed at all and are not installed by default. These are (with the effective option [like-so]):
*  [no-install-compat32-libs] 32 bit compatability libraries (for 32 bit applications)
*  [no-nvidia-modprobe] a suid executable to install kernel modules
*  [no-wine-files] files to support ngx under WINE
*  [no-dkms] dynamic kernel modules support. DKMS can be made to work with something like
   ```
         dkms  --force --dkmstree /opt/nvidia/dkms --sourcetree /opt/nvidia-test/<release>/src -m nvidia/<release>
   ```
   but might as well just put `nvidia-unbound -K -k KERNEL_VERSION` in an `/etc/kernel-install.d`
   drop-in file. The kernel modules of old releases very often won't compile with new kernels so either approach it of very limited practical use.
*  [no-kernel-module-source] the source files to compile the kernel module and would mainly be of use with DKMS.
*  [no-libglx-indirect] `libGLX_indirect.so` is just a symlink to
   `libGLX_nvidia.so.<version>` and appears not required with glvnd
*  [no-install-libglvnd] these are the vendor neutral wrappers and
   dispatch libraries, not normally needed at they are part of current
   distributions
*  [no-install-libegl] this is the vendor neutral EGL library and
   associated symbolic links, not normally needed at they are part of
   current distributions
*  [no-install-libgl] these are the old libGL, libGLX and associated
   symbolic links, incompatible with glvnd. If installed they will go
   in `/opt/nvidia/<release>` and can coexist with the
   coresponding libraries in `/usr/lib64` irrespective of whether those
   are glvnd versions or not.

The installation location can be overridden on a per type basis with

```
	--override-file-type-destination=<FILE_TYPE>:<destination>
```
options and file types can be excluded with

```
	--exclude=<FILE_TYPE>[,<FILE_TYPE>...]
```

If no options to exclude groups or types of files are in effect, all
files in the manifest are installed (or attempted subject to
permissions, media etc). so that

## System Configuration ##
Some system configuration is unavoidable if the driver installed by
_Nvidia Unbound_ is to be used transparently. Currently,
_Nvidia Unbound_ does not attempt automatic system configuration,
however sample configuration files are included in the source as
`examples/*', which can be modified used to suit local requirements.

| *Example code*         | *Install location*       | *Description*                                                                                      |
|------------------------|--------------------------|----------------------------------------------------------------------------------------------------|
| nv-class               | /usr/local/sbin          | Lookup nv-table to map hardware to Nvidia driver release number [Identification](#identification)  |
| nv-table               | /usr/local/lib           | Table of Vendor/Device Codes and required release numbers [Identification](#identification)        |
| nv-environment         | /etc/systemd             | A script to cache dynamically generated environment variables [Paths](#paths)                      |
| nv-environment.service | /etc/systemd/system      | A systemd service to invoke nv-environment on boot  [Paths](#paths)                                |
| nv-profile.sh          | /etc/profile.d           | Set environment variables for shell  [Paths](#paths)                                               |
| nv-environment.sh      | /etc/X11/xinit/xinitrc.d | Set environment variables for Xsession [Xsession](#xsession)                                       |
| nvidia-modules.conf    | /etc/modprobe.d          | How to install and remove nvidia modules [Kernel module loading](#kernel_module_loading)           |
| nv-loadmod             | /usr/local/sbin          | Helper script for nvidia-modules.conf [Kernel module loading](#kernel_module_loading)              |
| Xserver-start          | /usr/local/bin           | A wrapper for Xserver to establish environment arguments and modify arguments [Xserver](#xsession) |
| xorg-nvidia.conf       | /etc/X11                 | An xorg.conf to load nvidia driver [Xserver](#xserver)                                             |


The intention is that system configuration modifications on the root
file system be minimal and only be required once, when the immutable
filessystem (if using) is built.  If necessary, overlayfs, bind mounts
and symbolic links, perhaps set up in initrd can be used to obviate
the need to modify the root file system at all.

### Identification ###
It is necessary to identify the correct (or preferred) Nvidia driver
release for the hardware present. The approach used by `nv-class` is
to parse the output of `lspci` for "Vendor" and "Device" codes and use
that to lookup release numbers in `nv-table`.

### Paths ###
The PATH and LD_LIBRARY_PATH environment variables need to be set to
include the locations of the correct release. Instead of running
nv-class every time this is required, `nv-environment` saves some
values in /run/session which can be trivially parsed by a shell. In
systems using systemd, `nv-environment.service` is used to invoke
`nv-environment` during in the boot process. In non-systemd systems, this
could be run from `rc.local`.

### Xsession ###
Depending on the system, `/etc/profile` and associated drop-in files
might not be sourced before the display manager, window manager and
other X clients are started. The nv-environment.sh drop-in file
performs this function on Fedora. Other systems may vary.

### Kernel module loading ###
Loading the correct kernel module is achieved by `nv-loadmod`. The
`nvidia-modules.conf` drop-in file ensures that the correct kernel
module is loaded.  It may be necessary to blacklist nouveau by putting
`modprobe.blacklist=nouveau` on the kernel command line.

### Xserver ###
The Xserver (`X` or `Xorg`) needs to be started with the
LD_LIBRARY_PATH set so it can find a number of Nvidia release
dependent libraries. It also needs to be able to find the Xserver
modules `nvidia_drv.so` and `libglxserver_nvidia.so`. Finally,
xorg.conf needs to specify the nvidia driver.

This can be accomplished with a wrapper (`Xserver-start`) and a
specific config file `xorg-nvidia.conf`. There will need to be some
other configuration to ensure that `Xserver-start` is executed by the
display manager, rather than `xorg`.

For example, if using the `kdm` display manager, set
```
	ServerCmd=/usr/local/bin/Xserver-start
```
in `/etc/kde/kdm/kdmrc`.

An alternative is to rename xorg to xorg.real, call the wrapper script
xorg and have the wrapper execute xorg.real. The problem is that this
is likely to be undone the next time xorg is upgraded.

## Known Limitations and Issues ##

* The Ndvida drivers apparently support Wayland and _Nvidia Unbound_
installs the necessary components but this is untested. In particular,
any changes required to Wayland configuration have not been
investigated.

* While _Nvidia Unbound_ allows one image to contain multiple releases
  of the Nividia driver, only one can be selected at a time. This is
  limitation of the kernel modules and not within the scope of this
  project to fix. If you need multiple Nvidia graphics cards, they all
  need to have the same compatible driver release.

* Uncooperative applications which reset LD_LIBRARY_PATH instead of
  pre-pending to it. The only instance I am aware of is (or was) the
  Zoom video converencing application for Linux. It works by having
  `ZoomLauncher` mangle the execution environment before executing the
  real `zoom` application. The trick was to rename `zoom` to
  `zoom.real` and create a small `zoom` shell script wrapper which set
  the `LD_LIBRARY_PATH` and executed `zoom.real`.
  
  Such lengths are rarely necessary.

## Bugs ##

Report bugs at <https://github.com/iandall/nvidia-unbound/issues>
