#!/bin/bash
#
# CS695 Conductor that manages containers 
# Author: <your-name>
#
echo -e "\e[1;32mCS695 Conductor that manages containers\e[0m"

set -o errexit
set -o nounset
umask 077

source "$(dirname "$0")/config.sh"

die()
{
    echo "$1" >&2
    exit 1
}

check_prereq()
{
    if [ "$EUID" -ne "0" ]; then
        die "This script needs root permissions to run."
    fi

    for t in $NEEDED_TOOLS; do
        which "$t" > /dev/null || die "Missing required tools: $t"
    done

    [ -d "$CONTAINERDIR" ] || mkdir -p "$CONTAINERDIR" || die "Unable to create state dir $CONTAINERDIR"

    [ -d "$IMAGEDIR" ] || mkdir -p "$IMAGEDIR" || die "Unable to create image dir $IMAGEDIR"

    [ -d "$EXTRADIR" ] || mkdir -p "$EXTRADIR" || die "Unable to create extras dir $EXTRADIR"
}

build()
{
    local NAME=${1:-}

    [ -z "$NAME" ] && die "Image name is required"

    [ -d "$IMAGEDIR/$NAME" ] && die "Image $NAME already exists"

    debootstrap bookworm "$IMAGEDIR/$NAME" https://deb.debian.org/debian || die "Failed to create image $NAME"
}

images()
{
    local IMAGES=$(ls -1 "$IMAGEDIR" 2>/dev/null || true)
    if [ -z "$IMAGES" ]; then
        echo -e "\e[1;31mNo images found\e[0m"
    else
        printf "%-20s %-10s %s\n" "Name" "Size" "Date"
        for i in $IMAGES; do
            local SIZE=$(du -sh "$IMAGEDIR/$i" | awk '{print $1}')
            local DATE=$(stat -c %y "$IMAGEDIR/$i" | awk '{print $1}')
            printf "%-20s %-10s %s\n" "$i" "$SIZE" "$DATE"
        done
    fi
}

remove_image()
{
    local NAME=${1:-}

    [ -z "$NAME" ] && die "Container name is required"

    [ -d "$IMAGEDIR/$NAME" ] || die "Image $NAME does not exist"
    rm -rf "$IMAGEDIR/$NAME"
    echo -e "\e[1;32m$NAME succesfully removed\e[0m"
}

run()
{
    local IMAGE=${1:-}
    local NAME=${2:-}

    [ -z "$NAME" ] && die "Container name is required"
    [ -z "$IMAGE" ] && die "Image name is required"

    [ -d "$IMAGEDIR/$IMAGE" ] || die "Image $IMAGE does not exist"
    [ -d "$CONTAINERDIR/$NAME" ] && die "Container $NAME already exists"

    mkdir -p "$CONTAINERDIR/$NAME/rootfs"
    cp -a "$IMAGEDIR/$IMAGE"/* "$CONTAINERDIR/$NAME/rootfs"

    shift 2
    local INIT_CMD_ARGS=${@:-/bin/bash}


    # mount -t proc none "$CONTAINERDIR/$NAME/rootfs/proc"
    # mount -t sysfs none "$CONTAINERDIR/$NAME/rootfs/sys"
    mount -o bind /dev "$CONTAINERDIR/$NAME/rootfs/dev"
    # unshare --uts --pid --net --mount --ipc --fork chroot "$CONTAINERDIR/$NAME/rootfs" /bin/bash -c "mount -t proc none /proc && mount -t sysfs none /sys && mount -o bind /dev /dev && chmod 755 / && /bin/bash"
    unshare --uts --pid --net --mount --ipc --mount-proc --fork --kill-child -R "$CONTAINERDIR/$NAME/rootfs"  /bin/bash -c "mount -t sysfs sysfs /sys && chmod 755 / && $INIT_CMD_ARGS"

}

show_containers()
{
    local CONTAINERS=$(ls -1 "$CONTAINERDIR" 2>/dev/null || true)

    if [ -z "$CONTAINERS" ]; then
        echo "No containers found"
    else
        printf "%-20s %-10s\n" "Name" "Date"
        for i in $CONTAINERS; do
            local DATE=$(stat -c %y "$CONTAINERDIR/$i" | awk '{print $1}')
            printf "%-20s %-10s\n" "$i" "$DATE"
        done
    fi
}

stop()
{
    local NAME=${1:-}

    [ -z "$NAME" ] && die "Container name is required"

    [ -d "$CONTAINERDIR/$NAME" ] || die "Container $NAME does not exist"

    local PID=$(ps -ef | grep "$CONTAINERDIR/$NAME/rootfs" | grep -v grep | awk '{print $2}')

    if [ -e "/sys/class/net/${NAME}-outside" ]; then
        ip link delete "${NAME}-outside"
    fi
    
    [ -z $PID ] || kill -9 $PID

    # kill -9 $PID
    umount "$CONTAINERDIR/$NAME/rootfs/proc" > /dev/null 2>&1 || :
    umount "$CONTAINERDIR/$NAME/rootfs/sys" > /dev/null 2>&1 || :
    umount "$CONTAINERDIR/$NAME/rootfs/dev" > /dev/null 2>&1 || :

    rm -rf "$CONTAINERDIR/$NAME"
    [ -z "$(ls -1 "$CONTAINERDIR" 2>/dev/null || true)" ] && rm -f "$EXTRADIR/.HIGHEST_NUM" &&  iptables -P FORWARD DROP && iptables -F FORWARD && iptables -t nat -F
    echo -e "\e[1;32m$NAME succesfully removed\e[0m"
}

exec()
{
    # not implemented properly yet
    local NAME=${1:-}

    [ -z "$NAME" ] && die "Container name is required"
    
    shift

    # if no command is given then substitute with /bin/bash
    local EXEC_CMD_ARGS=${@:-/bin/bash}

    [ -d "$CONTAINERDIR/$NAME" ] || die "Container $NAME does not exist"

    echo -e "\e[1;32mExecuting $CMD in $NAME container!\e[0m"

    local UNSHARE_PID=$(ps -ef | grep "$CONTAINERDIR/$NAME/rootfs" | grep -v grep | awk '{print $2}')
    
    [ -z "$UNSHARE_PID" ] && die "Cannot find container process"

    local CONTAINER_INIT_PID=$(pgrep -P $UNSHARE_PID | head -1)

    [ -z "$CONTAINER_INIT_PID" ] && die "Cannot find container process"

    nsenter --target $CONTAINER_INIT_PID -a -r -w $EXEC_CMD_ARGS
}

get_next_num()
{
    local NUM=1
    if [ -f "$EXTRADIR/.HIGHEST_NUM" ]; then
        NUM=$(( 1 + $(< "$EXTRADIR/.HIGHEST_NUM" )))
    fi

    echo $NUM > "$EXTRADIR/.HIGHEST_NUM"
    printf "%x" $NUM
}

wait_for_dev()
{
    local iface="$1"
    local in_ns="${2:-}"
    local retries=5 # max retries
    local nscmd=

    [ -n "$in_ns" ] && nscmd="ip netns exec $in_ns"
    while [ "$retries" -gt "0" ]; do
        if ! $nscmd ip addr show dev $iface | grep -q tentative; then return 0; fi
        sleep 0.5
        retries=$((retries -1))
    done
}

addnetwork()
{
    local NAME=${1:-}
    [ -z "$NAME" ] && die "Container name is required"
    local NETNSDIR="/var/run/netns"

    if [ ! -e $NETNSDIR ]; then
        mkdir -p $NETNSDIR
    fi

    local PID=$(ps -ef | grep "$CONTAINERDIR/$NAME/rootfs" | grep -v grep | awk '{print $2}')
    local CONDUCTORNS="/proc/$PID/ns/net"
    local NSDIR=$NETNSDIR/$NAME

    if [ -e CONDUCTORNS ]; then
	    rm $NSDIR
    fi
    ln -sf $CONDUCTORNS $NSDIR

    local NUM=$(get_next_num "$NAME")

    [ -z "$IP4_PREFIX" ] && IP4_PREFIX="${IP4_SUBNET}.$((0x$NUM))."

    INSIDE_IP4="${IP4_PREFIX}2"
    OUTSIDE_IP4="${IP4_PREFIX}1"
    INSIDE_PEER="${NAME}-inside"
    OUTSIDE_PEER="${NAME}-outside"

    ip link add dev "$OUTSIDE_PEER" type veth peer name "$INSIDE_PEER" netns "$NAME"

    echo 1 > /proc/sys/net/ipv4/ip_forward

    ip link set dev "$OUTSIDE_PEER" up
    ip -n "$NAME" link set dev lo up
    ip -n "$NAME" link set dev "$INSIDE_PEER" up

    ip addr add dev "$OUTSIDE_PEER" "${OUTSIDE_IP4}/${IP4_PREFIX_SIZE}"
    ip -n "$NAME" addr add dev "$INSIDE_PEER" "${INSIDE_IP4}/${IP4_PREFIX_SIZE}"
    ip -n "$NAME" route add "${IP4_SUBNET}/${IP4_FULL_PREFIX_SIZE}" via "$OUTSIDE_IP4" dev "$INSIDE_PEER"


    echo -n "Setting up network '$NAME' with peer ip ${INSIDE_IP4}." || echo "."
    echo " Waiting for interface configuration to settle..."
    echo ""
    wait_for_dev "$OUTSIDE_PEER" && wait_for_dev "$INSIDE_PEER" "$NAME"

    if [ "$INTERNET" -eq "1" ]; then
        ip -n "$NAME" route add default via "$OUTSIDE_IP4" dev "$INSIDE_PEER"
        iptables -t nat -A POSTROUTING -s "${INSIDE_IP4}/${IP4_PREFIX_SIZE}" -o ${DEFAULT_IFC} -j MASQUERADE

        iptables -A FORWARD -i ${DEFAULT_IFC} -o ${OUTSIDE_PEER} -j ACCEPT
        iptables -A FORWARD -i ${OUTSIDE_PEER} -o ${DEFAULT_IFC} -j ACCEPT

        cp /etc/resolv.conf /etc/resolv.conf.old
        echo "nameserver 8.8.8.8" > /etc/resolv.conf

    fi
    
    if [ "$EXPOSE" -eq "1" ]; then
        iptables -t nat -A PREROUTING -p tcp -i ${DEFAULT_IFC} --dport ${OUTER_PORT} -j DNAT --to-destination ${INSIDE_IP4}:${INNER_PORT}
         iptables -t nat -A OUTPUT -o lo -m addrtype --src-type LOCAL --dst-type LOCAL -p tcp --dport ${OUTER_PORT} -j DNAT --to-destination ${INSIDE_IP4}:${INNER_PORT}
        iptables -A FORWARD -p tcp -d ${INSIDE_IP4} --dport ${INNER_PORT} -m state --state NEW,ESTABLISHED,RELATED -j ACCEPT
        echo lol
    fi

    rm -rf $NETNSDIR
}

peer()
{
    local NAMEA=${1:-}
    local NAMEB=${2:-}
    [ -z "$NAMEA" ] && die "First Container name is required"
    [ -z "$NAMEB" ] && die "Second Container name is required"

    iptables -A FORWARD -i "${NAMEA}-outside" -o "${NAMEB}-outside" -j ACCEPT
    iptables -A FORWARD -i "${NAMEB}-outside" -o "${NAMEA}-outside" -j ACCEPT
}


usage()
{
    local FULL=${1:-}

    echo "Usage: $0 <command> [params] [options] [params]"
    echo ""
    echo "Commands:"
    echo "build <img>                           Build image for containers"
    echo "images                                List available images"
    echo "rmi <img>                             Delete image"
    echo "run <img> <cntr> -- [command <args>]  Runs [command] within a new container named <cntr> fron the image named <img>"            
    echo "                                      if no command is given it will run /bin/bash by default"
    echo "ps                                    Show all running containers"
    echo "stop <cntr>                           Stop and delete container"
    echo "exec <cntr> -- [command <args>]       Execute command (default /bin/bash) in a container"
    echo "addnetwork <cntr>                     Adds layer 3 networking to the container"
    echo "peer <cntr> <cntr>                    Allow to container to communicate with each other"
    echo ""

    if [ -z "$FULL" ] ; then
        echo "Use --help to see the list of options."
        exit 1
    fi

    echo "Options:"
    echo "-h, --help                Show this usage text"
    echo ""
    echo ""
    echo "-i, --internet            Allow internet access from the container."
    echo "                          Should be used allongwith addnetwork"
    echo "                          Otherwise makes no sense."
    echo ""
    echo "-e, --expose <inner-port>-<outer-port>"
    echo "                          Expose some port of container (inner)"
    echo "                          as the host's port (outter)"
    echo ""
    echo ""
    exit 1
}

OPTS="hie:"
LONGOPTS="help,internet,expose:"

OPTIONS=$(getopt -o "$OPTS" --long "$LONGOPTS" -- "$@")
[ "$?" -ne "0" ] && usage >&2 || true

eval set -- "$OPTIONS"


while true; do
    arg="$1"
    shift

    case "$arg" in
        -h | --help)
            usage full >&2
            ;;
        -i | --internet)
            INTERNET=1
            ;;
        -e | --expose)
            PORT="$1"
            INNER_PORT=${PORT%-*}
            OUTER_PORT=${PORT#*-}
            EXPOSE=1
            shift
            ;;
        -- )
            break
            ;;
    esac
done

[ "$#" -eq 0 ] && usage >&2

case "$1" in
    build)
        CMD=build
        ;;
    images)
        CMD=images
        ;;
    rmi)
        CMD=remove_image
        ;;
    run)
        CMD=run
        ;;
    ps)
        CMD=show_containers
        ;;
    stop)
        CMD=stop
        ;;
    exec)
        CMD=exec
        ;;
    addnetwork)
        CMD=addnetwork
        ;;
    peer)
        CMD=peer
        ;;
    "help")
        usage full >&2
        ;;
    *)
        usage >&2
        ;;
esac

shift
check_prereq
$CMD "$@"






