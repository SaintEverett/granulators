if [ $# -eq 0 ]; then
    echo "arguments are [wave file] [port] [device (optional)]"
elif [ $# -eq 2 ]; then
    chuck recv_granu_nchan:$1:$(hostname):$2 &
    chuck send_granu_nchan:$(hostname):$2:0
elif [ $# -eq 3 ]; then
    chuck recv_granu_nchan:$1:$(hostname):$2 &
    chuck send_granu_nchan:$(hostname):$2:$3
fi
