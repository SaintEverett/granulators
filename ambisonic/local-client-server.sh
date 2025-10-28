if [ $# -eq 0 ]; then
    echo "arguments are [wave file] [num of gran] [port (optional)]"
elif [ $# -eq 3 ]; then
    chuck recv_ambigranulator:$1:$2:$(hostname):$3 &
    chuck send_ambigranulator:$(hostname):$3:0
fi
