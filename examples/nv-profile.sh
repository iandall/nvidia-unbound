#
function path_prepend(){
    local -n _path=$1
    shift
    local p
    local epath=:$_path:
    trap 'shopt -u extglob' RETURN
    shopt -s extglob
    for p; do
	[[ ${epath/:$p:} == ${epath} ]] && _path=${p}:${_path##+(:)}
    done
}


if [ -e /run/session-environment ]; then
    . /run/session-environment
    path_append PATH $NV_PATH
    path_append LD_LIBRARY_PATH $NV_LIBRARY_PATH
    if [[ -n $NV_MAJ ]]; then
	XORGCONFIG=/etc/X11/xorg-nvidia.conf
	export XORGCONFIG
    fi
    unset NV_PATH NV_LIBRARY_PATH NV_MAJ
    export PATH LD_LIBRARY_PATH
fi


