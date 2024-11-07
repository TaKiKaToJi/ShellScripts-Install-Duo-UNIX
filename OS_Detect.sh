platform_detect() {
    isRPM=1
    if ! (type lsb_release &>/dev/null); then
        distribution=$(grep '^NAME' /etc/*-release)
        release=$(grep '^VERSION_ID' /etc/*-release)
    else
        distribution=$(lsb_release -i | grep 'ID' | grep -v 'n/a')
        release=$(lsb_release -r | grep 'Release' | grep -v 'n/a')
    fi

    releaseVersion=${release//[!0-9.]/}
    
    case $distribution in
        *"Debian"*)
            platform='Debian_'; isRPM=0
            case $releaseVersion in
                8*) majorVersion='8' ;;
                9*) majorVersion='9' ;;
                10*) majorVersion='10' ;;
                11*) majorVersion='11' ;;
                12*) majorVersion='12' ;;
            esac
            ;;
        *"Ubuntu"*)
            platform='Ubuntu_'; isRPM=0
            if [[ $releaseVersion =~ ([0-9]+)\.(.*) ]]; then
                majorVersion="${BASH_REMATCH[1]}.04"
            fi
            ;;
        *"SUSE"* | *"SLES"*)
            platform='SuSE_'
            case $releaseVersion in
                12*) majorVersion='12' ;;
                15*) majorVersion='15' ;;
            esac
            ;;
        *"Oracle"*)
            platform='Oracle_OL'
            case $releaseVersion in
                6*) majorVersion='6' ;;
                7*) majorVersion='7' ;;
                8*) majorVersion='8' ;;
                9*) majorVersion='9' ;;
            esac
            ;;
        *"CentOS"*)
            platform='RedHat_EL'; runningPlatform='CentOS_'
            case $releaseVersion in
                6*) majorVersion='6' ;;
                7*) majorVersion='7' ;;
                8*) majorVersion='8' ;;
            esac
            ;;
        *"AlmaLinux"*)
            platform='RedHat_EL'; runningPlatform='AlmaLinux_'
            case $releaseVersion in
                8*) majorVersion='8' ;;
                9*) majorVersion='9' ;;
            esac
            ;;
        *"Rocky"*)
            platform='RedHat_EL'; runningPlatform='Rocky_'
            case $releaseVersion in
                8*) majorVersion='8' ;;
                9*) majorVersion='9' ;;
            esac
            ;;
        *"Amazon"*)
            platform='amzn'
            case $(uname -r) in
                *"amzn2023"*) majorVersion='2023' ;;
                *"amzn2"*) majorVersion='2' ;;
                *"amzn1"*) majorVersion='1' ;;
            esac
            ;;
        *"RedHat"* | *"Red Hat"*)
            platform='RedHat_EL'
            case $releaseVersion in
                6*) majorVersion='6' ;;
                7*) majorVersion='7' ;;
                8*) majorVersion='8' ;;
                9*) majorVersion='9' ;;
            esac
            ;;
        *)
            echo "[ERROR] Unsupported platform detected."
            exit 1
            ;;
    esac

    archType='i386'
    case $(arch) in
        *"x86_64"*) archType='x86_64' ;;
        *"aarch64"*) archType='aarch64' ;;
    esac

    if [[ ${archType} == 'i386' ]]; then
        echo "[ERROR] Unsupported architecture detected."
        exit 1
    fi

    linuxPlatform="${platform}${majorVersion}/${archType}/"
    echo "Detected platform: ${linuxPlatform}"
}

platform_detect
