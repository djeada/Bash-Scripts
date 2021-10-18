#!/usr/bin/env bash

main() {

    echo -e "Memory usage: \n$(free -h)"
    echo -e "\nDisk usage: \n$(df -h)"
    echo -e "\nUptime: $(uptime)"

}

main "$@"
