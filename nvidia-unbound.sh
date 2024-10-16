#!/bin/bash

# Install
VERSION=@@VERSION@@
CONFIG='@@CONFIG_DIR@@/nvidia-unbound.conf'

# Copyright (C) Ian Dall 2024
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 3, or (at your option)
# any later version.

# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.

# You should have received a copy of the GNU General Public License
# along with this program; if not, see <https://www.gnu.org/licenses/>.

COPYRIGHT="\
Copyright (C) Ian Dall 2024
This is free software; see the source for copying conditions.  There is NO
warranty; not even for MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
"

AUTHOR="Written by: Ian Dall <ian@beware.dropbear.id.au>"
PROG=${0##*/}

USAGE="\
Usage:  $PROG [OPTION] ARCHIVE
   or:  $PROG [-h|--help|-u <path>|--use <path>|d|--dump]

An alternative installer for Nvidia Linux drivers.

Options:

Mandatory arguments to long options are mandatory for short options
too. The case interdependent values True, t, Yes, Y, 1 and \"\" are all
equivalent for BOOL argument. Any other value is false. A
\"--no-\" prefix complements BOOL. Thus --option=f is equivalaent to
--no-option=t or --no-option, and --option is equivalent to
--no-option=f (not recommended). The equal sign may be omitted (getopt(1)).

        -c, --config=FILE
                    configuation FILE

        -q, --quiet equivalent to --verbose=0

        -u, --use=PATH
                    use existing unpacked package at PATH

        -v, --verbose[=LEVEL]
                    set verbosity 0 < LEVEL < 10. With no argument, increment verbosity

        -t, --trace trace commands which modify the filesystem. Use with --dry-run to
                    preview actions which would be taken.

        -P, --prefix=PREFIX
                    installation path prefix (default /opt/nvidia)

        -K, --kernel-modules-only
                    compile and install kernel modules only (no userland)

        -k, --kernel-name KERNEL_VERSION
                    compile specified kernel module only. Otherwise do all installed kernels

        -M, --kernel-module-type=KERNEL_MODULE_TYPE
		    whether to build the \"open\" or \"proprietary\" drivers. If argument is \"\"
                    prefer \"open\" if available, otherwise \"proprietary\".

        -U, --no-kernel-modules[=BOOL}
                    install utilities and user libraries only

        -D, --no-set-default[=BOOL]
                    don't create symlinks to make this Nvidia release the default

        --check    check an existing installation.

        --dry-run   don't actually run comands which modify the installation

        --install-compat32-libs[=BOOL]
                    whether to install x86 32bit compability libraries

        --nvidia-modprobe[=BOOL]
                    whether to install setuid executable to load kernel modules

        --wine-files[=BOOL]
                    whether to install dll to support ngx under WINE

        --kernel-module-source[=BOOL]
                    whether to install kernel module source files. May be required for DKMS

        --dkms[=BOOL]
                    whether to install DKMS configuration file. Also whether to use DKMS
                    to build kernel modules

        --libglx-indirect[=BOOL]
                    whether to install a libGLX-indirect.so.0 link

        --install-libglvnd[=BOOL]
                    whether to install libglvnd client libraries

        --install-libegl[=BOOL]
                    whether to install libegl client libraries

        --install-libgl[=BOOL]
                    whether to install libgl client libraries

        --override-file-type-destination=TYPE_DEST
                    where TYPE_DEST=<FILE_TYPE>:<DESTINATION>. Install all files of type
                    FILE_TYPE in DESTINATION. This option may be given multiple times.

	--exclude=FILE_TYPES
                    where FILE_TYPES is a comma separated list of file types to exclude from installation.

        -d, --dump-config
                    dump effective configuration

        -I, --info
                    print information (meta-data) from the Nvidida driver archive

        -V, --version
                    print the $PROG version and exit (c.f. --info)

        -h|--help)
                    print this text and exit

ARCHIVE is a self unpacking Nvidia driver archive, typically of the form
NVIDIA-Linux-<arch>-<version>.run.
"

export TMPDIR=/var/tmp

# Defaults so logging to stderr works immediately
logfile=/dev/stderr
declare -A arg_map
arg_map[verbose]=1

function error(){
    echo "Error: $*" >>${logfile}
    if [[ ${logfile} != "/dev/stderr" ]]; then
	echo "$*" >&${stderr}
    fi
}
function warn(){
    if (( ${arg_map[verbose]} > 0 )); then
	echo "Warning: $*" >>${logfile}
	if [[ ${logfile} != "/dev/stderr" ]]; then
	    echo "$*" >&${stderr}
	fi
    fi
}

function info(){
    if (( ${arg_map[verbose]} > 1 )); then
	echo "$*" >>${logfile}
	if [[ ${logfile} != "/dev/stderr" ]]; then
	    echo "$*" >&${stderr}
	fi
    fi
}


function info_level(){
    if (( ${arg_map[verbose]} >= $1 )); then
	shift
	echo "$*" >>${logfile}
	if [[ ${logfile} != "/dev/stderr" ]]; then
	    echo "$*" >&${stderr}
	fi
    fi
}

function cmd(){
    [[ ${arg_map[trace]} == t ]] && info_level 1 "$*"
    [[ ${arg_map[dry-run]} == t ]] || "$@"
}

function simple_cmd(){
    local res
    res=$(cmd "$@" 2>&1) || { error $res; return 1;}
}

exec -- {stderr}>&2


function binary_long_opts_gen(){
    declare -a opts
    for opt in "$@"; do
	opts+=($opt::)
	opts+=(no-$opt)
    done
    local IFS=,
    echo -n "${opts[*]}"
}

function param_long_opts_gen(){
    declare -a opts=("$@")
    local IFS=,
    echo -n "${opts[*]/%/:}"
}

function make_set(){
    declare -n _set=$1
    shift
    for item in "$@"; do
	_set[$item]=
    done
}

# Only optons in binary_long_opt_map or param_long_opt_map are permitted in config files

# These otions can take a --no-option form and an optional argument
binary_long_opts="kernel-modules kernel-modules-only install-compat32-libs nvidia-modprobe wine-files kernel-module-source dkms drm libglx-indirect install-libglvnd install-libegl install-libgl systemd set-default"
declare -A binary_long_opt_map
make_set binary_long_opt_map $binary_long_opts

# These options require an argument
param_long_opts="config prefix log-path kernel-name exclude use kernel-module-type"
declare -A param_long_opt_map
make_set param_long_opt_map $param_long_opts verbose



args=$(getopt -o 'c:dqu:v::tP:K::k:M:l:U::D::IVh'\
	      -l $(param_long_opts_gen $param_long_opts)\
	      -l $(binary_long_opts_gen $binary_long_opts)\
	      -l 'override-file-type-destination:,dry-run,trace,quiet,verbose::,dump-config,check,info,version,help'\
	      -- "$@")

if [ $? -ne 0 ]; then
    error "$USAGE"
    exit 1
fi

function split(){
    declare -n var=$1
    local IFS=$2
    var=($3)
}

function trim_str(){
    if [[ "$1" =~ [[:space:]]*([^[:space:]]+|[^[:space:]]+.*[^[:space:]]+)[[:space:]]* ]]; then
	echo -n "${BASH_REMATCH[1]}"
	return 0
    else
	echo -n "$1"
	return 1
    fi
}

function istrue(){
    case ${1@L} in
	t|true|1|yes|y)
	    true;;
	*) false;;
    esac
}

function binary_opt_istrue(){
    local invert value
    [[ ${1#--no-} == $1 ]]; invert=$?
    istrue "$2" || [[ -z $2 ]]; value=$?
    (( (invert ^ value) == 0 ))
}

function set_binary_opt(){
    local val
    local opt=${1#--}
    opt=${opt#no-}

    if binary_opt_istrue "$2" "$3"; then
	val=t
    else
	val=f
    fi
    arg_map[$opt]="$val"
}



declare -A override
function override_file_type(){
    local -a fields
    local type=${1%%:*}
    local dest=${1#*:}
    override[$type]=$dest
}



function read_config(){
    local line
    while read line; do
	local eq=
	local key=${line%%=*}
	local value=
	local opt
	if [[ $key != $line ]]; then
	    value=${line#*=}
	    eq=t
	fi
	key=$(trim_str "$key")

	# skip if comment or emty line
	{ [[ ${key#\#} != $key ]] || [[ $key == "" ]];} && continue
	opt=${key#--}
	opt=${opt#no-}
	value=$(trim_str "$value")
	if [[ $opt == override-file-type-destination ]]; then
	    # handle specially
	    override_file_type "$value"
	    continue
	elif [[ -n ${binary_long_opt_map[$opt]+t} ]]; then
	    # A permitted binary opt
	    if binary_opt_istrue --"$key" "$value"; then
		value=t
	    else
		value=f
	    fi
	elif [[ -n ${param_long_opt_map[$opt]+t} ]]; then
	    # A required parameter opt
	    if [[ $eq != t ]]; then
		# If there was no "=" there is no value, not even an empty string
		warn "Option $opt expects a parameter: $line in config"
		continue
	    fi
	else
	    warn "Unknown parameter $opt: $line in config"
	    continue
	fi
	arg_map[$opt]="$value"
    done
}

# Default configuration
read_config <<-EOF
	config=$CONFIG
	log-path=/var/log/nvidia-installer
	prefix=/opt/nvidia
	no-install-compat32-libs
	no-nvidia-modprobe
	no-wine-files
	no-kernel-module-source
	kernel-modules
	kernel-module-type=
	no-dkms
	drm
	no-libglx-indirect
	no-install-libglvnd
	no-install-libegl
	no-install-libgl
	no-systemd
	set-default
	verbose=1
	exclude=INSTALLER_BINARY
EOF

eval set -- "$args"
while [ $# -gt 0 ]; do
    case $1 in
	-c|--config)
	    shift
	    arg_map[config]=$1
	    ;;
    esac
    shift
done

if [[ -f "${arg_map[config]}" ]]; then
    read_config < "${arg_map[config]}"
fi

eval set -- "$args"

while [ $# -gt 0 ]; do
    opt=${1#--}
    opt=${opt#no-}
    if [[ -n $opt && -n ${binary_long_opt_map[$opt]+t} ]]; then
	if binary_opt_istrue $1 $2; then
	    arg_map[$opt]=t
	else
	    arg_map[$opt]=f
	fi
	shift 2
	continue
    fi

    case $1 in
	-c|--config)
	    # already set previously
	    shift
	    ;;
	-d|--dump-config)
	    arg_map[dump-config]=t
	    ;;
	-u|--use)
	    shift
	    arg_map[use]=$1
	    ;;
	-v|--verbose)
	    if [[ -z "$2" ]]; then
		((arg_map[verbose]++))
	    else
		arg_map[verbose]=$2
	    fi
	    shift
	    ;;
	-q|--quite)
	    arg_map[verbose]=0
	    ;;
	-t|--trace)
	    arg_map[trace]=t
	    ;;
	-P|--prefix)
	    shift
	    arg_map[prefix]=$1
	    ;;
	-K)
	    set_binary_opt --kernel-modules-only $2
	    shift
	    ;;
	-k|--kernel-name)
	    shift
	    arg_map[kernel-name]=$1
	    ;;
	-M|--kernel-module-type)
	    shift
	    [[ $1 == open || $1 == proprietary ]] || { error Invalid option kernel-module-type=$1; exit 1;}
   	    arg_map[kernel-module-type]=$1
	    ;;
	-U)
	    set_binary_opt --no-kernel-modules $2
	    shift
	    ;;
	-V|--version)
	    echo ${VERSION}$'\n\n'${COPYRIGHT}$'\n\n'${AUTHOR}
	    exit 0
	    ;;
	-D)
	    set_binary_opt --no-set-default $2
	    shift
	    ;;
	--check)
	    arg_map[check]=t
	    ;;
	--dry-run)
	    arg_map[dry-run]=t
	    ;;
	-l|--log-path)
	    shift
	    arg_map[log-path]=$1
	    ;;
	-I|--info)
	    arg_map[info]=t
	    ;;
	--exclude)
	    shift
	    arg_map[exclude]=$1
	    ;;
	--override-file-type-destination)
	    shift
	    override_file_type "$1"
	    ;;
	-h|--help)
	   echo "$USAGE"
	   exit 0
	   ;;
	--)
	    shift; break
	    ;;
	-*)
	    error "Unknown option $1"$'\n'"$USAGE"
	    exit 1
	    ;;
	*)
	    error "Something is wrong!: ${1@Q}"
	    break
	    ;;
    esac
    shift
done

[[ ${arg_map[dump-config]} == t ]] && {
    unset arg_map[dump-config]
    for key in "${!arg_map[@]}"; do
	value=${arg_map[$key]}
	echo "$key = $value"
    done | sort -k 1,1
    for arg in ${override[@]}; do
	echo "overide-file-type-destination = $arg"
    done
    
    exit 0
}

case $# in
    0)
	[[ -z ${arg_map[use]} ]] && {
	    error "Require archive file [..]/NVIDIA-Linux-<version>.run"
	    error "or --use <existing>".
	    error "USAGE"
	    exit 1
	}
	;;
    1)
	[[ -n  ${arg_map[use]} ]] && {
	    error "Archive $1 and --use ${arg_map[use]} are incompatible "
	    error "USAGE"
	    exit 1
	}
	;;
    *)
	error "Extra arguments: $@"
	error "USAGE"
	exit 1
	;;
esac

simple_cmd mkdir -p ${arg_map[log-path]}

if [[ -n ${arg_map[log-path]} ]]; then
    logfile=${arg_map[log-path]}/common.log
fi


if [[ -z ${arg_map[use]} ]]; then
    [[ -r $1 ]] || { error Cannot access $1; exit 1;}

    NVIDIA=$(mktemp -t -d NVIDIA.XXXXXXXX) || { error "$PROG Cannot allocate temporary directory";}

    trap "[[ -n \${manifest_fd} ]] &&  exec -- {manifest_fd}<&-; /bin/rm -rf ${NVIDIA}" EXIT

    pushd $NVIDIA; simple_cmd /bin/sh $1 -x; popd

    NVIDIA_ROOT=$(echo $NVIDIA/*)
else
    NVIDIA_ROOT=${arg_map[use]}
    [[ -d ${NVIDIA_ROOT} ]] || { error "Missing ${NVIDIA_ROOT}"; exit 1;}
fi
cd "$NVIDIA_ROOT"

eval $( sed -n \
	-e '1s/\(.*\)/nvidia='\''\1'\''/p'\
	-e '2s/\(.*\)/release='\''\1'\''/p'\
	-e '4s/\(.*\)/modules='\''\1'\''/p'\
	"$NVIDIA_ROOT/.manifest" )

if [[ ${arg_map[info]} == t ]]; then
    echo "$nvidia"
    echo "$release"
    exit 0
fi


VPREFIX=${arg_map[prefix]}/${release}

# Not sure how useful dkms is with nvidia-unbound
# dkms command line options to specify alternate trees, e.g:
#
#     dkms  --force --dkmstree /opt/nvidia-test/dkms --sourcetree /opt/nvidia-test/560.35.03/src -m nvidia/560.35.03 --verbose build
#
# but you can't put them in the dkms.conf file. You can specify in the /etc/dkms/framework.conf, but that applies to all dkms modules, not just these ones.
# You could specify in the command line that in a /etc/kernel-install.d file, but then
# might as well just put nvidia-unbound -K -k KERNEL_VERSION
function dkms_conf(){
    local -i i=0
	cat - <<-EOF
		PACKAGE_NAME="nvidia"
		PACKAGE_VERSION="$release"
		AUTOINSTALL="yes"

		# By default, DKMS will add KERNELRELEASE to the make command line; however,
		# this will cause the kernel module build to infer that it was invoked via
		# Kbuild directly instead of DKMS. The dkms(8) manual page recommends quoting
		# the 'make' command name to suppress this behavior.
		MAKE[0]="'make' -j`nproc` IGNORE_PREEMPT_RT_PRESENCE=1 NV_EXCLUDE_BUILD_MODULES='__EXCLUDE_MODULES' KERNEL_UNAME=\${kernelver} modules"

		# The list of kernel modules will be generated by nvidia-installer at runtime.
	EOF
	for module in "$@"; do
	    echo BUILT_MODULE_NAME[$i]="$module"
	    echo DEST_MODULE_LOCATION[$i]="/kernel/drivers/video"
	    i+=1
	done
}

if [[ ${arg_map[kernel-modules-only]} != t ]]; then
    declare -a exclude_list	# A list of exclude patterns

    declare -A extra_exclusions; make_set extra_exclusions ${arg_map[exclude]//,/ }
    
    function exclude_test(){
	declare -n _entry=$1
	declare -a pattern
	if [[ ${extra_exclusions[${_entry[2]}]+t} ]]; then
	    info "Excluding by exclude ${_entry[2]} option: ${_entry[*]}"
	    return 0
	fi
	
	for p in "${exclude_list[@]}"; do
	    eval pattern=\($p\)

	    # If any of Filename, Type, Additional-Path, or Module don't match
	    # then try next pattern
	    if [[ ${_entry[0]} != ${pattern[1]} ]] ||
		    [[ ${_entry[2]} != ${pattern[2]} ]] ||
		    [[ ${_entry[3]} != ${pattern[3]} ]] ||
		    [[ ${_entry[-1]} != ${pattern[4]} ]]; then
		continue
	    else
		# All fields match
		info "Excluding by ${pattern[0]}=${arg_map[${pattern[0]}]}: ${_entry[*]}"
		return 0
	    fi
	done
	return 1
    }

    function exclude(){
	if [[ ${arg_map[$1]} != t ]]; then
	    exclude_list+=("${*@Q}")
	fi
    }

    # Objects are excluded if the controlling option is false and all fields match the corresponding patternn
    #
    #	    Controlling								Additional
    #	    Option			File		Type			Path		Module
    # ------------------------------------------------------------------------------------------------
    exclude install-compat32-libs	"*"		"*" 			COMPAT32	"*"
    exclude nvidia-modprobe 		"*"		NVIDIA_MODPROBE*	"*"		"*"
    exclude wine-files			"*"		WINE_LIB		"*" 		"*"
    exclude kernel-module-source	"*"		KERNEL_MODULE_SRC	"*"		"*"
    exclude dkms	 		"*"		DKMS_CONF*		"*"		"*"
    exclude drm 			"*"		"*"			"*"		MODULE:nvidia_drm
    exclude libglx-indirect	   libGLX_indirect.so.0	OPENGL_SYMLINK		"*"		"*"
    exclude install-libglvnd		"*"		GLVND_LIB		"*"		"*"
    exclude install-libglvnd		"*"		GLVND_SYMLINK		"*"		"*"
    exclude systemd			"*"		SYSTEMD_*		"*"		"*"
    exclude install-libegl		"*"		EGL_CLIENT_*		"*"		"*"
    exclude install-libgl		"*"		GLX_CLIENT_*		"*"		"*"

    opt=${arg_map[prefix]}/${release}
    NATIVE=lib64
    COMPAT32=lib
    utils_path=$opt/bin

    declare -A actions

    function encode(){ echo "${@@Q}";}

    function inherit_path(){
	declare -i depth=${1#*:}
	declare -a src_path
	local src="${2%/*}"
	split src_path / "${src##/}"
	for ((j=0; j < depth; j++))
	do
            unset src_path[j];
	done;
	local IFS=/
	echo -n "${src_path[*]}"
    }

    for action_type in \
	CUDA_LIB \
	    EGL_CLIENT_LIB \
	    ENCODEAPI_LIB \
	    GLVND_LIB \
	    GLX_CLIENT_LIB \
	    NVCUVID_LIB \
	    OPENCL_LIB \
	    OPENCL_WRAPPER_LIB \
	    OPENGL_LIB \
	    TLS_LIB \
	    UTILITY_LIB \
	    VDPAU_LIB \
	    WINE_LIB \
	; do
	actions[$action_type]=$(encode copy "$opt")
    done
    actions[GLX_MODULE_SHARED_LIB]=$(encode copy "$opt/lib64/xorg/modules")
    actions[INTERNAL_UTILITY_LIB]=$(encode copy /usr/lib/nvidia "" /32)
    actions[UTILITY_BINARY]=$(encode copy $opt "" "" /bin)
    actions[XMODULE_SHARED_LIB]=$(encode copy "$opt/lib64/xorg/modules")

    for action_type in \
	CUDA_SYMLINK \
	    EGL_CLIENT_SYMLINK \
	    ENCODEAPI_LIB_SYMLINK \
	    GBM_BACKEND_LIB_SYMLINK \
	    GLVND_SYMLINK \
	    GLX_CLIENT_SYMLINK \
	    NVCUVID_LIB_SYMLINK \
	    OPENCL_LIB_SYMLINK \
	    OPENCL_WRAPPER_SYMLINK \
	    OPENGL_SYMLINK \
	    UTILITY_LIB_SYMLINK \
	    VDPAU_SYMLINK \
	; do
	actions[$action_type]=$(encode symlink "$opt")
    done
    actions[GLX_MODULE_SYMLINK]=$(encode symlink "$opt/lib64/xorg/modules")
    actions[SYSTEMD_UNIT_SYMLINK]=$(encode symlink "/usr/lib/systemd/system")
    actions[UTILITY_BINARY_SYMLINK]=$(encode symlink "$opt/bin")
    actions[APPLICATION_PROFILE]=$(encode copy /usr/share/ndivia )
    actions[CUDA_ICD]=$(encode copy-update /etc/OpenCL/vendors)
    actions[DKMS_CONF]=$(encode dkms-copy $opt/src/nvidia-${release})
    actions[DOCUMENTATION]=$(encode copy "$opt/share/doc")
    actions[DOT_DESKTOP]=$(encode dot-desktop-copy "/usr/local/share/applications")
    actions[EGL_EXTERNAL_PLATFORM_JSON]=$(encode copy-update /usr/share/egl/egl_external_platform.d)
    actions[FIRMWARE]=$(encode copy "/lib/firmware/nvidia/${release}")
    actions[GLVND_EGL_ICD_JSON]=$(encode copy-update /usr/share/glvnd/egl_vendor.d)
    actions[ICON]=$(encode copy "$opt/share/icons/hicolor")
    actions[INSTALLER_BINARY]=$(encode noop)
    actions[INTERNAL_UTILITY_BINARY]=$(encode copy /usr/lib/nvidia "" /32)
    actions[INTERNAL_UTILITY_DATA]=$(encode copy /usr/lib/nvidia)
    actions[KERNEL_MODULE_SRC]=$(encode copy $opt/src/nvidia-${release})
    actions[MANPAGE]=$(encode copy "$opt/share/man")
    actions[NVIDIA_MODPROBE]=$(encode copy)
    actions[NVIDIA_MODPROBE_MANPAGE]=$(encode copy "$opt/share/man")
    actions[OPENGL_DATA]=$(encode copy)
    actions[SYSTEMD_SLEEP_SCRIPT]=$(encode copy /usr/lib)
    actions[SYSTEMD_UNIT]=$(encode copy /usr/lib/systemd/system)
    actions[VULKAN_ICD_JSON]=$(encode copy-update /etc/vulkan)
    actions[VULKANSC_ICD_JSON]=$(encode copy-update /etc/vulkansc)
    actions[WINE_LIB]=$(encode copy /usr/lib/nvidia/wine)
    actions[XORG_OUTPUTCLASS_CONFIG]=$(encode copy-update /usr/share/X11/xorg.conf.d)


    # mkdir -p $VPREFIX/lib/firmware || {
    # 	echo Cannot create $VPREFIX/lib/firmware >&2
    #     exit 1
    # }

    # [[ -d /lib/firmware/nvidia/${release} ]] || \
    # 	ln -s $VPREFIX/lib/firmware /lib/firmware/nvidia/${release} || {
    # 	    echo "Failed to create link /lib/firmware/nvidia/${release} -> $VPREFIX/lib/firmware" >&2
    #         exit 1
    # 	}
    # ${NVIDIA_ROOT}/nvidia-installer ${nvidia_core_args[@]} --no-kernel-modules  --log-file-name=$LOG_PATH/common.log

    while read -a fields; do
	if exclude_test fields; then
	    continue
	fi

	# We want this field, now do stuff!

	module=${fields[-1]}
	unset fields[-1]
	action_type=${fields[2]}
	if [[ -z $action_type ]]; then
	    warn "Parse error in manifest"$'\n'"${fields[*]}"$'\n'"Skipping..."
	    continue
	fi
	action_encoded=${actions[$action_type]}
	if [[ -z $action_encoded ]]; then
	    warn "Unknown action type: $action_type. Skipping..."
	    continue
	fi

	eval action=($action_encoded)
	work=${action[0]}
	if [[ $work == noop ]]; then
	    warn "Support for $action_type unimplemented. Skipping..."
	    continue
	fi

	src=${fields[0]}
	mode=${fields[1]}
	declare -i i=3
	
	dst=${action[1]}
	if [[ -n ${override[$action_type]} ]]; then
	    dst=${override[$action_type]}
	    info "Overriding destination for $src by \"override-file-type-destination=$action_type:$dst\" option: ${fields[*]}" 
	fi
	
	
	part=${action[4]:+${action[4]}} # Default
	case ${fields[3]} in
	    NATIVE)
		part=${action[2]}
		if [[ -z $part && ${#action[@]} -le 2 ]]; then
		    part=$NATIVE
		fi
		i+=1
		;;
	    COMPAT32)
		part=${action[3]}
		if [[ -z $part  && ${#action[@]} -le 3 ]]; then
		    part=$COMPAT32
		fi
		i+=1
		;;
	    INHERIT_PATH_DEPTH:*)
		part=$(inherit_path ${fields[3]} "$src")
		i+=1
		;;
	    '')
		:
		;;
	    *)
		part=${fields[3]}
		i+=1
		;;
	esac

	info_level 9 "Part=${part@Q}"
	part=${part#/}
	part=${part%/}
	dst+=${part:+/${part}}/

	remaining=$(( ${#fields[@]} - i ))
	info_level 9 "Remaing fields: $remaining"

	if (( remaining == 1 )); then
	    dst+=${fields[i]#/}
	fi

	if (( remaining == 2 )); then
	    a=${fields[i]#/}
	    a=${a%/}
	    dst+=${a:+$a/}${fields[i+1]#/}
	fi

	if (( remaining > 2 )); then
	    warn "HELP too many fields"$'\n'"${fields[*]}"
	fi

	target=${dst%/*}/${src##*/}

	if [[ ${arg_map[check]} == t ]]; then
	    failed=
	    if [[ ! -e $target ]]; then
		warn $target not found
		failed=t
	    else
		mode=$(stat -L --printf '%#a' $target)
		case $work in
		    copy|copy-update|dkms-copy)
			[[ ! -L $target && -f $target ]] || { warn $target not a regular file; failed=t;}
			[[ ${fields[1]} == $mode ]] || { warn $target does not have mode $mode; failed=t;}
			;;
		    symlink)
			[[ -L $target ]] || { warn $target is not a symlink; failed=t;}
			[[ $(realpath $target) == $(realpath $dst) ]] || { warn $target not a link to $dst; failed=t;}
			;;
		esac
	    fi
	    if [[ $failed == t ]]; then
		info_level 1 ${fields[@]} $module
		info_level 1 "# fields = ${#fields[@]}, i = $i"
	    fi
	else
	    cmd mkdir -p ${dst%/*} || continue
	    case $work in
		copy)
		    simple_cmd cp $src $dst
		    ;;
		copy-update)
		    simple_cmd cp --update $src $dst
		    ;;
		symlink)
		    simple_cmd ln -sf $dst ${target}
		    ;;
		dkms-copy)
		    res=$(cmd  dkms_conf $modules > $target 2>&1)  || { error $res; false;}
		    ;;
		dot-desktop-copy)
		    if [[ $src -nt $target ]]; then
			res=$(cmd sed "s/__UTILS_PATH__/$utils_path/" "$src" > "$target" 2>&1) || { error $res; false;}
		    fi
		    ;;
		*)
		    warn Unknown action $work
		    ;;
	    esac
	fi

    done < <(sed -n '9,$p' "$NVIDIA_ROOT/.manifest" )
fi

if [[ "${arg_map[kernel-modules]}" == t ]]; then
    build_dir=kernel-open
    case ${arg_map[kernel-module-type]} in
	open)
	    build_dir=kernel-open
	    ;;
	proprietary)
	    build_dir=kernel
	    ;;
	'')
	    [[ -d $NVIDIA_ROOT/$build_dir ]] || build_dir=kernel
	    ;;

	esac

    [[ -d $NVIDIA_ROOT/$build_dir ]] || { error cd:  $NVIDIA_ROOT/$build_dir: no such file or directory; exit 1;}
    cd $NVIDIA_ROOT/$build_dir

    kernel_mod_success=
    for kernel_modlib in /lib/modules/${arg_map[kernel-name]:-*}; do
	kernel_version=${kernel_modlib##*/}
	if [[ -n ${arg_map[log-path]} ]]; then
	    logfile=${arg_map[log-path]}/$kernel_version
	fi
	dest=$VPREFIX/lib64/modules/$kernel_version/kernel/drivers/video/
	simple_cmd mkdir -p $dest || continue

	IGNORE_CC_MISMATCH=t cmd make KERNEL_MODLIB=$kernel_modlib -j $(nproc) clean module >> $logfile 2>&1 || {
	    echo "Failure to build kernel modules for kernel $kernel_version. Check $logfile for details." >&2
            continue
	}
	cmd cp -pv *.ko $dest && kernel_mod_success=t
    done

    # Create a link, eg from 560 -> 560.35.100  and from 5XX -> 560.35.100.
    # This allows for LD_LIBRARY_PATH=/opt/nvidia/5XX to always get
    # the latest driver for this hardware.
    #
    # Any failure is most likely in kernel module generation, so only
    # create the links if the kernel modules were sucessfully built
    # for at least one kernel

    if [[ "${arg_map[set-default]}" == t  && $kernel_mod_success == t ]]; then
	cmd ln -snf ${release} ${arg_map[prefix]}/${release%%.*}
	cmd ln -snf ${release} ${arg_map[prefix]}/${release:0:1}XX
    fi
fi
