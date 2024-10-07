#!/bin/bash 

# Usage: ./script.sh <command> <hostname> <password> [file]
# Available commands: dl, ul, ulr, dlvrx, ulvrx, ulvrxr, dlwfbng, fonts, fontsiNAV, ulwfbng, ulwfbngr, rb, sysup, keysdlgs, keysdlcam,
#                    keysulgs, keysulcam, keysgen, UART0on, UART0off, extra, rswfb, rsmaj, binup, koup,
#                    shup, bindl, kodl, shdl, temp, rubyfw, wfbfw, offlinefw, msp0, msp2, mspgs, mav,
#                    dualosd, onboardrecon, onboardrecoff, mavgs, mavgs2

if [ "$#" -lt 3 ]; then
    echo "Usage: $0 <command> <hostname> <password> [file]"
    exit 1
fi
LOGFILE="command_log.log" # Ensure this is set to a valid log file path
TIMEOUT_DURATION="10s"  # Set the timeout duration, e.g., 10 seconds

COMMAND=$1
HOSTNAME=$2
PASSWORD=$3
FILE=$4

# Function to log messages
log() {
    if [ -z "$1" ]; then
        echo "***** Log message is empty!"
        return 1 # Return an error code if the message is empty
    fi

    #echo "***** Log message is: $1"
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOGFILE"
}

# Function to get the actual hostname from the remote device

get_remote_hostname() {
    log "sshpass -p '***' ssh -o StrictHostKeyChecking=no root@$HOSTNAME hostname"
    sshpass -p "$PASSWORD" timeout $TIMEOUT_DURATION ssh -o StrictHostKeyChecking=no root@"$HOSTNAME" "hostname"

    # Check the exit status of the timeout command
    if [ $? -eq 124 ]; then
        log "The sshpass command timed out."
        exit 1        
    fi

}

# Determine device type based on hostname
log "Getting device type..."
DEVICE_TYPE=$(get_remote_hostname | grep -E 'radxa|openipc-ssc338q' | awk '{if ($0 ~ /radxa/) print "radxa"; else if ($0 ~ /openipc-ssc338q/) print "camera";}')
log "Device type: $DEVICE_TYPE"

if [ -z "$DEVICE_TYPE" ]; then
    log "Failed to determine device type, make sure you are connected"
    exit 1
fi

if [ ! -e "$DEVICE_TYPE" ]; then
    mkdir $DEVICE_TYPE

    exit 1
fi


execute_command() {
    sshpass -p "$PASSWORD" ssh root@"$HOSTNAME" "$1"
}

transfer_file() {
    #log "sshpass -p \"$PASSWORD\" scp -O root@\"$HOSTNAME\":\"$1\" \"$2\""
    sshpass -p "$PASSWORD" scp -O root@"$HOSTNAME":"$1" "$DEVICE_TYPE/$2"
}


transfer_file_to_device() {
    local src_pattern="$1"  # The source file path pattern
    local dest_path="$2"    # The destination path on the remote device

    # Change to the directory containing the files
    local base_dir=$(dirname "$src_pattern")  # Get the directory of the source pattern
    cd "$DEVICE_TYPE/$base_dir" || exit 1      # Navigate to the source directory

    # Use a loop to handle multiple files
    for src_file in $(basename "$src_pattern"); do
        if [[ -f "$src_file" ]]; then
            # Get the full path of the source file
            local full_path=$(realpath "$src_file")

            sshpass -p "$PASSWORD" scp -O "$full_path" root@"$HOSTNAME":"$dest_path"
        else
            echo "Warning: File '$src_file' does not exist."
        fi
    done
}


# transfer_file_to_device() {
#     #log "sshpass -p \"$PASSWORD\" scp -O root@\"$HOSTNAME\":\"$1\" \"$2\""
#     sshpass -p "$PASSWORD" scp -O "$DEVICE_TYPE/$1" root@"$HOSTNAME":"$2"
# }
# Validate and execute command based on device type
validate_and_execute() {
    local client_type="$1"
    local command="$2"

    # Log the arguments
    log "Validating command for client type: '$client_type' with command: '$command'"

    if [[ "$DEVICE_TYPE" == "$client_type" ]]; then
        eval "$command"
    else
        echo "Command not allowed for device type '$DEVICE_TYPE'. Required: '$client_type'."
        exit 1
    fi
}

case "$COMMAND" in
    dl)
        log "Downloading files..."
        log "/etc/majestic.yaml"
        validate_and_execute "camera" "transfer_file '/etc/majestic.yaml' '.'"
        
        log "/etc/wfb.conf"
        validate_and_execute "camera" "transfer_file '/etc/wfb.conf' '.'"
        
        log "/etc/telemetry.conf"
        validate_and_execute "camera" "transfer_file '/etc/telemetry.conf' '.'"
        ;;
    ul)
        log "Uploading files..."
        log "majestic.yaml"
        validate_and_execute "camera" "transfer_file_to_device 'majestic.yaml' '/etc'"

        log "wfb.conf"
        validate_and_execute "camera" "transfer_file_to_device 'wfb.conf' '/etc'"

        log "telemetry.conf"
        validate_and_execute "camera" "transfer_file_to_device 'telemetry.conf' '/etc'"

        log "running dos2unix on files"
        execute_command "dos2unix /etc/wfb.conf /etc/telemetry.conf /etc/majestic.yaml"
        ;;
    ulr)
        log "Uploading files...and rebooting"
        log "majestic.yaml"
        validate_and_execute "camera" "transfer_file_to_device 'majestic.yaml' '/etc'"

        log "wfb.conf"
        validate_and_execute "camera" "transfer_file_to_device 'wfb.conf' '/etc'"

        log "telemetry.conf"
        validate_and_execute "camera" "transfer_file_to_device 'telemetry.conf' '/etc'"

        log "running dos2unix on files"
        execute_command "dos2unix /etc/wfb.conf /etc/telemetry.conf /etc/majestic.yaml"
        ;;
    dlvrx)
        validate_and_execute "camera" "transfer_file '/etc/vdec.conf' '.'"
        validate_and_execute "camera" "transfer_file '/etc/wfb.conf' '.'"
        validate_and_execute "camera" "transfer_file '/etc/telemetry.conf' '.'"
        ;;
    ulvrx)
        validate_and_execute "camera" "transfer_file_to_device 'vdec.conf' '/etc'"
        validate_and_execute "camera" "transfer_file_to_device 'wfb.conf' '/etc'"
        validate_and_execute "camera" "transfer_file_to_device 'telemetry.conf' '/etc'"
        execute_command "dos2unix /etc/wfb.conf /etc/telemetry.conf /etc/vdec.conf"
        ;;
    ulvrxr)
        validate_and_execute "camera" "transfer_file 'vdec.conf' '/etc'"
        validate_and_execute "camera" "transfer_file 'wfb.conf' '/etc'"
        validate_and_execute "camera" "transfer_file 'telemetry.conf' '/etc'"
        execute_command "dos2unix /etc/wfb.conf /etc/telemetry.conf /etc/vdec.conf"
        execute_command "reboot"
        ;;
    dlwfbng)
        validate_and_execute "radxa" "transfer_file '/etc/wifibroadcast.cfg' '.'"
        validate_and_execute "radxa" "transfer_file '/etc/modprobe.d/wfb.conf' '.'"
        validate_and_execute "radxa" "transfer_file '/home/radxa/scripts/screen-mode' '.'"
        ;;
    ulwfbng)
        validate_and_execute "radxa" "transfer_file_to_device 'wifibroadcast.cfg' '/etc'"
        validate_and_execute "radxa" "transfer_file_to_device 'wfb.conf' '/etc/modprobe.d/'"
        validate_and_execute "radxa" "transfer_file_to_device 'screen-mode' '/home/radxa/scripts/'"
        execute_command "dos2unix /etc/wifibroadcast.cfg /etc/modprobe.d/wfb.conf /home/radxa/scripts/screen-mode"
        ;;
    ulwfbngr)
        validate_and_execute "radxa" "transfer_file_to_device 'wifibroadcast.cfg' '/etc'"
        validate_and_execute "radxa" "transfer_file_to_device 'wfb.conf' '/etc/modprobe.d/'"
        validate_and_execute "radxa" "transfer_file_to_device 'screen-mode' '/home/radxa/scripts/'"
        execute_command "dos2unix /etc/wifibroadcast.cfg /etc/modprobe.d/wfb.conf /home/radxa/scripts/screen-mode"
        execute_command "reboot"
        ;;
    rb)
        validate_and_execute "radxa" "execute_command 'reboot'"
        ;;
    sysup)
        validate_and_execute "camera" "execute_command 'sysupgrade -k -r -n --force_ver'"
        ;;
    keysdlgs)
        validate_and_execute "radxa" "transfer_file '/root/drone.key' '.'"
        ;;
    keysdlcam)
        validate_and_execute "camera" "transfer_file '/etc/drone.key' '.'"
        ;;
    keysulgs)
        validate_and_execute "radxa" "transfer_file_to_device 'drone.key' '/etc'"
        execute_command "cp /etc/drone.key /etc/gs.key"
        ;;
    keysulcam)
        validate_and_execute "camera" "transfer_file_to_device 'drone.key' '/etc'"
        ;;
    keysgen)
        validate_and_execute "radxa" "execute_command 'wfb_keygen'"
        execute_command "cp /root/gs.key /etc/"
        ;;
    UART0on)
        validate_and_execute "radxa" "execute_command 'sed -i 's/console::respawn:\/sbin\/getty -L console 0 vt100 \# GENERIC_SERIAL/#console::respawn:\/sbin\/getty -L console 0 vt100 \# GENERIC_SERIAL/' /etc/inittab'"
        execute_command "reboot"
        ;;
    UART0off)
        validate_and_execute "radxa" "execute_command 'sed -i 's/#console::respawn:\/sbin\/getty -L console 0 vt100 \# GENERIC_SERIAL/console::respawn:\/sbin\/getty -L console 0 vt100 \# GENERIC_SERIAL/' /etc/inittab'"
        execute_command "reboot"
        ;;
    extra)
        validate_and_execute "radxa" "execute_command 'sed -i 's/mavfwd --channels \"$channels\" --master \"$serial\" --baudrate \"$baud\" -a \"$aggregate\" \\/mavfwd --channels \"$channels\" --master \"$serial\" --baudrate \"$baud\" -a \"$aggregate\" --wait 5 --persist 50 -t \\/' /usr/bin/telemetry'"
        execute_command "reboot"
        ;;
    rswfb)
        validate_and_execute "radxa" "execute_command 'wifibroadcast stop'"
        sleep 3
        execute_command "wifibroadcast start"
        ;;
    rsmaj)
        validate_and_execute "camera" "execute_command 'killall -1 majestic'"
        ;;
    binup)
        validate_and_execute "camera" "transfer_file_to_device '$FILE' '/etc/sensors/'"
        ;;
    koup)
        validate_and_execute "camera" "transfer_file_to_device '$FILE' '/lib/modules/4.9.84/sigmastar/'"
        ;;
    shup)
        validate_and_execute "radxa" "transfer_file_to_device '*.sh' '/root/'"
        validate_and_execute "radxa" "transfer_file_to_device 'channels.sh' '/usr/bin/'"
        execute_command "rm /root/channels.sh"
        execute_command "rm /root/816.sh"
        execute_command "rm /root/1080.sh"
        execute_command "rm /root/1080b.sh"
        execute_command "rm /root/1264.sh"
        execute_command "rm /root/3K.sh"
        execute_command "chmod +x /root/*.sh"
        ;;
    bindl)
        validate_and_execute "camera" "execute_command 'chmod +x /etc/sensors/*.sh'"
        ;;
    kodl)
        validate_and_execute "radxa" "execute_command 'killall -9 wifibroadcast'"
        ;;
    shdl)
        validate_and_execute "camera" "execute_command 'rm /etc/sensors/*.sh'"
        ;;
    temp)
        validate_and_execute "radxa" "execute_command 'cat /sys/class/thermal/thermal_zone0/temp'"
        ;;
    rubyfw)
        validate_and_execute "camera" "execute_command 'fw_setenv upgrade /tmp/uImage.$FILE /tmp/rootfs.squashfs.$FILE'"
        ;;
    wfbfw)
        validate_and_execute "camera" "execute_command 'fw_setenv upgrade /tmp/uImage.$FILE /tmp/rootfs.squashfs.$FILE'"
        ;;
    offlinefw)
        validate_and_execute "camera" "execute_command 'fw_setenv upgrade /tmp/uImage.$FILE /tmp/rootfs.squashfs.$FILE'"
        ;;
    msp0)
       
        log "Adjusting wifibroadcast service with msposd parameters..."
        validate_and_execute "camera" "execute_command 'sed -i \"s|echo \\\"Starting wifibroadcast service...\\\"|msp0 --master /dev/ttyS2 --baudrate 115200 --channels 8 --out 127.0.0.1:14555 -osd -r 20 --wait 5 --persist 50 -v \\& echo \\&L70 \\&F35 CPU:\\&C \\&B Temp:\\&T \\> /tmp/MSPOSD.msg \\&|\" /etc/init.d/S98datalink'"

        
        log "Modify sleep duration from 2 seconds to 5 seconds"
        # Modify sleep duration from 2 seconds to 5 seconds
        validate_and_execute "camera" "execute_command \"sed -i 's/sleep 2/sleep 5/' /etc/init.d/S98datalink\""

        log "Rebooting Camnera..."
        # Reboot the system after executing commands
        validate_and_execute "camera" "execute_command 'reboot'"
        ;;
    msp2)
        # Adjust the wifibroadcast service with msposd parameters
        log "Adjusting wifibroadcast service with msposd parameters..."
        validate_and_execute "camera" "execute_command 'sed -i \"s|echo \\\"Starting wifibroadcast service...\\\"|msposd --master /dev/ttyS2 --baudrate 115200 --channels 8 --out 127.0.0.1:14555 -osd -r 20 --wait 5 --persist 50 -v \\& echo \\&L70 \\&F35 CPU:\\&C \\&B Temp:\\&T \\> /tmp/MSPOSD.msg \\&|\" /etc/init.d/S98datalink'"

        log "Modify sleep duration from 2 seconds to 5 seconds"
        # Modify sleep duration from 2 seconds to 5 seconds
        validate_and_execute "camera" "execute_command \"sed -i 's/sleep 2/sleep 5/' /etc/init.d/S98datalink\""

        log "Rebooting Camnera..."
        # Reboot the system after executing commands
        validate_and_execute "camera" "execute_command 'reboot'"
        ;;


    mspgs)
        validate_and_execute "camera" "execute_command 'killall -1 msposd'"
        ;;
    mav)
        validate_and_execute "camera" "execute_command 'sed -i 's/ 2/ 0/' /etc/rc.local'"
        validate_and_execute "camera" "execute_command 'reboot'"
        ;;
    dualosd)
        validate_and_execute "camera" "execute_command 'sed -i '/startosd/!b;n;N;s/.*/&\n&/' /etc/init.d/S98datalink'"
        validate_and_execute "camera" "execute_command 'reboot'"
        ;;
    onboardrecon)
        validate_and_execute "camera" "execute_command 'systemctl enable onboardrecon'"
        validate_and_execute "camera" "execute_command 'reboot'"
        ;;
    onboardrecoff)
        validate_and_execute "camera" "execute_command 'systemctl disable onboardrecon'"
        validate_and_execute "camera" "execute_command 'reboot'"
        ;;
    mavgs)
        validate_and_execute "radxa" "execute_command 'killall -1 mavfwd'"
        ;;
    mavgs2)
        validate_and_execute "radxa" "execute_command 'killall -1 mavfwd'"
        ;;
    fonts)
        validate_and_execute "camera" "transfer_file_to_device '../fonts/betaflight/*.png' '/usr/bin/'"
        ;;
    fontsINAV)
        validate_and_execute "camera" "transfer_file_to_device '../fonts/inav/*.png' '/usr/bin/'"
        ;;

    *)
        echo "Invalid command: $COMMAND"
        exit 1
        ;;
esac
