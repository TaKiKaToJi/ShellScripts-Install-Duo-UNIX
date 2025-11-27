#!/bin/bash


# Function to print messages in red
print_red() {
  echo -e "\033[31m$1\033[0m"
}

# Function to print messages in green
print_green() {
  echo -e "\033[32m$1\033[0m"
}

# Function to print messages in yellow
print_yellow() {
  echo -e "\033[33m$1\033[0m"
}


# Function to show a loading progress bar with a percentage
show_progress_bar() {
    local total=50       # Total number of segments in the progress bar
    local duration=$1    # Duration for the entire progress (in seconds)
    local increment=$((duration * 10 / total)) # Time to sleep for each segment

    for ((i = 1; i <= total; i++)); do
        # Calculate the percentage
        local percent=$(( i * 100 / total ))
        
        # Create the progress bar with '=' and '>' for the current position
        local bar=$(printf "%-${total}s" "=" | sed "s/ /=/g")
        bar="${bar:0:i}>"

        # Display the progress bar with percentage
        printf "\r%3d%%[%-${total}s]" "$percent" "$bar"

        # Sleep for the calculated increment time
        sleep 0.$((increment * 10))
    done
    printf "\n" # New line after the progress bar completes
}

# Call the function with the duration you want the progress bar to run (e.g., 5 seconds)
# show_progress_bar 5


# Function to show a loading animation
show_loading_animation() {
    local chars='|/-\'  # Animation characters
    local delay=0.1     # Delay between frames (in seconds)
    local duration=$1   # Duration for how long the animation should run (in seconds)
    local end_time=$((SECONDS + duration))
    
    while [ $SECONDS -lt $end_time ]; do
        for (( i = 0; i < ${#chars}; i++ )); do
            printf "\r%s" "${chars:$i:1}"  # Print character with carriage return
            sleep $delay                  # Pause for specified delay
        done
    done
    printf "\r"  # Clear the animation character
}

# Call the function with the duration you want the animation to run (e.g., 5 seconds)
# show_loading_animation 5


check_internet_install_duo_pam() {
    echo "Checking internet connection..."

    # Check 1: Internet connectivity test using ping and port checks
    echo "Check 1: Testing internet connectivity with ping..."
    if ping -c 1 www.google.com > /dev/null 2>&1; then
        echo "Check 1 passed: Internet is connected (via ping)."

        # Check if ports 80 and 443 are reachable
        echo "Checking connectivity to port 80..."
        if nc -z -w 5 www.google.com 80 > /dev/null 2>&1; then
            echo "Port 80 is reachable."
        else
            echo -e "\033[0;31mPort 80 is not reachable\033[0m"
        fi

        echo "Checking connectivity to port 443..."
        if nc -z -w 5 www.google.com 443 > /dev/null 2>&1; then
            echo "Port 443 is reachable."
        else
            echo -e "\033[0;31mPort 443 is not reachable\033[0m"
        fi

        check_os_version_pam_install
        return
    else
        echo -e "\033[0;31mCheck 1 failed: Internet connectivity unsuccessful (via ping)\033[0m"
    fi

    # Check 2: Using curl to fetch Google
    echo "Check 2: Testing with curl to Google..."
    if curl -s --head http://www.google.com | head -n 1 | grep "HTTP/1.[01] [23].." > /dev/null; then
        echo "Check 2 passed: Internet is connected (via curl)."
        check_os_version_pam_install
        return
    else
        echo -e "\033[0;31mCheck 2 failed: Unable to connect via curl\033[0m"
    fi

    # Check 3: Using wget to download headers from Google
    echo "Check 3: Testing with wget to Google..."
    if wget --spider -q http://www.google.com; then
        echo "Check 3 passed: Internet is connected (via wget)."
        check_os_version_pam_install
        return
    else
        echo -e "\033[0;31mCheck 3 failed: Unable to connect via wget\033[0m"
    fi

    # If all checks failed, prompt to bypass
    echo -e "\033[0;31mAll internet checks failed.\033[0m"
    while true; do
        read -p "Do you want to bypass the internet check and continue? (Y/n): " choice
        case "$choice" in
            [Yy]* )
                echo "Bypassing internet check and proceeding with installation..."
                check_os_version_pam_install
                return
                ;;
            [Nn]* )
                echo "Exiting to main menu. Please check your internet connection."
                main_menu
                return
                ;;
            * )
                echo "Please answer Y (yes) or N (no)."
                ;;
        esac
    done
}

# Check OS version
check_os_version_pam_install() {
    echo "Checking OS version, hostname, and IP address"

    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS_INFO="$ID $VERSION_ID"
    else
        OS_INFO="Unable to detect OS: /etc/os-release not found."
    fi

    HOSTNAME=$(hostname 2>/dev/null || echo "Hostname command not found")
    IP_ADDRESS=$(hostname -I | awk '{print $1}')
    [ -z "$IP_ADDRESS" ] && IP_ADDRESS="IP Address not found"

    print_green "OS version: $OS_INFO"
    print_green "Hostname: $HOSTNAME"
    print_green "IP Address: $IP_ADDRESS"

    # Adjust case for supported OS names
    case "$ID" in
        centos)
            OS_NAME="CentOS"
            ;;
        fedora)
            OS_NAME="Fedora"
            ;;
        centosstream)
            OS_NAME="CentOSStream"
            ;;
        rhel)
            OS_NAME="RedHatEnterprise"
            ;;
        *)
            print_red "Not supported yet: $ID"
            read -p "Press Enter to return to the menu..."
            main_menu  # Clear and return to menu
            ;;
    esac

    create_duo_repo "$OS_NAME"
}

# Create duosecurity.repo for yum-based systems
create_duo_repo() {
    local os="$1"
    echo "Creating /etc/yum.repos.d/duosecurity.repo for Duo installation..."
    cat <<EOF >/etc/yum.repos.d/duosecurity.repo
[duosecurity]
name=Duo Security Repository
baseurl=http://pkg.duosecurity.com/${os}/\$releasever/\$basearch
enabled=1
gpgcheck=0
EOF

    install_duo_unix_pam
}

# Install Duo Unix package
install_duo_unix_pam() {
    print_green "Importing Duo GPG key and installing duo_unix..."
    rpm --import https://duo.com/DUO-GPG-PUBLIC-KEY.asc
    yum install duo_unix -y

    configure_duo_unix_pam
}

# Configure pam_duo.conf using nano
configure_duo_unix_pam() {
    echo "Configuring Duo Unix..."
    
    # Check for pam_duo.conf and edit using nano
    if [ -f /etc/duo/pam_duo.conf ]; then
        nano /etc/duo/pam_duo.conf
    elif [ -f /etc/pam_duo.conf ]; then
        nano /etc/pam_duo.conf
    else
        print_red "Error: pam_duo.conf file not found in /etc/duo or /etc."
        exit 1
    fi

    # Show Duo PAM configuration for SSH
    show_duo_pam_config

    # Edit SSH configuration
    echo "Editing SSH configuration..."
    cd /etc/ssh
    if [ -x "$(command -v nano)" ]; then
        nano sshd_config
    else
        vi sshd_config
    fi

    # Clear the screen after editing
    clear

    show_duo_pam_sshd_config

    # Edit SSHD PAM.D configuration
    echo "Editing SSHD PAM configuration..."
    cd /etc/pam.d
    if [ -x "$(command -v nano)" ]; then
        nano sshd
    else
        vi sshd
    fi

    clear

    # Restart SSH service
    restart_ssh_service
}


# Show Duo PAM configuration for SSH
show_duo_pam_sshd_config() {
    clear
    echo ""
    echo "--------------------------------------------"
    echo ""
    echo -e "\e[38;2;0;255;0m\e[1m auth       required     pam_duo.so\e[0m"
    echo ""
    echo "--------------------------------------------"
    echo "Please manually update the sshd_config as needed."
    read -p "Press Enter to continue..."
    clear
}

# Show Duo PAM configuration for SSH
show_duo_pam_config() {
    clear
    echo ""
    echo "--------------------------------------------"
    echo ""
    echo -e "\e[38;2;0;255;0m\e[1m ChallengeResponseAuthentication yes\e[0m"
    echo ""
    echo "--------------------------------------------"
    echo "Please manually update the sshd_config as needed."
    read -p "Press Enter to continue..."
    clear
}



# Function to detect OS
# Function to check OS version, hostname, and IP address
check_os_version() {
  echo "Checking OS version, hostname, and IP address"

  # Detect OS information across both modern and legacy distributions
  if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS_INFO="${NAME:-$ID} ${VERSION:-$VERSION_ID}"
  elif command -v lsb_release >/dev/null 2>&1; then
    OS_INFO="$(lsb_release -sd 2>/dev/null)"
  else
    for release_file in /etc/centos-release /etc/redhat-release /etc/system-release /etc/issue /etc/*release* /etc/*version*; do
      if [ -f "$release_file" ]; then
        OS_INFO="$(head -n 1 "$release_file" 2>/dev/null)"
        [ -n "$OS_INFO" ] && break
      fi
    done
    [ -z "$OS_INFO" ] && OS_INFO="Unable to detect OS information."
  fi

  # Retrieve the hostname
  HOSTNAME=$(hostname 2>/dev/null || echo "Hostname command not found")

  # Retrieve IP address (fallback for older iproute-less hosts)
  if command -v hostname >/dev/null 2>&1 && hostname -I >/dev/null 2>&1; then
    IP_ADDRESS=$(hostname -I | awk '{print $1}')
  else
    IP_ADDRESS=$(ip addr show 2>/dev/null | awk '/inet / && $2 !~ /^127/ {print $2; exit}' | cut -d'/' -f1)
  fi
  [ -z "$IP_ADDRESS" ] && IP_ADDRESS="IP Address not found"

  # Display the results
  print_green "OS version: $OS_INFO"
  print_green "Hostname: $HOSTNAME"
  print_green "IP Address: $IP_ADDRESS"
}


# Function to clean package caches based on OS type
clean_package_cache() {
  detect_os  # Ensure OS is detected and set

  if [ "$OS" == "Red Hat-Based" ]; then
    print_yellow "Cleaning yum cache..."
    sudo yum clean all
  elif [ "$OS" == "Debian-Based" ]; then
    print_yellow "Cleaning apt cache..."
    sudo apt-get clean
    sudo apt-get autoclean
  else
    print_red "Unsupported OS: $OS"
    exit 1
  fi
}



# Function to detect OS and set the OS variable
detect_os() {
  if [ -f /etc/redhat-release ]; then
    OS="Red Hat-Based"
    INSTALL_COMMAND="sudo yum install"  # Red Hat-based installation command
  elif [ -f /etc/debian_version ]; then
    OS="Debian-Based"
    INSTALL_COMMAND="sudo apt-get install"
  else
    OS="Unsupported"
  fi
}


# Function to check and install a package based on OS type
check_install_package() {
  PACKAGE_NAME=$1

  # Call detect_os function to set the OS variable if not already set
  if [ -z "$OS" ]; then
    detect_os
  fi

  # Check if OS is unsupported before proceeding
  if [ "$OS" == "Unsupported" ]; then
    print_red "Unsupported OS."
    return 1
  fi

  # Check the package manager command dynamically based on the OS
  if [ "$OS" == "Red Hat-Based" ]; then
    COMMAND_CHECK="rpm -q $PACKAGE_NAME"
  elif [ "$OS" == "Debian-Based" ]; then
    COMMAND_CHECK="dpkg -l | grep '^ii' | grep $PACKAGE_NAME"
  fi

  # Check if the package is installed
  if eval "$COMMAND_CHECK" &> /dev/null; then
    print_green "$PACKAGE_NAME is already installed.  ✓ "
    return 0
  else
    print_yellow "$PACKAGE_NAME not found. Installing $PACKAGE_NAME..."
    if eval "$INSTALL_COMMAND -y $PACKAGE_NAME"; then
      print_green "$PACKAGE_NAME installed successfully."
      return 0
    else
      echo "----------------------------------"
      print_red "Failed to install $PACKAGE_NAME."
      echo "----------------------------------"
      echo "You may try to manually run:"
      echo ""
      print_red "$INSTALL_COMMAND $PACKAGE_NAME"
      echo ""
      echo "----------------------------------"
      return 1
    fi
  fi
}

# Function to check tools
check_tools_and_install() {
  detect_os  # Ensure OS is detected and set
  clean_package_cache  # Run clean package cache only once

  show_loading_animation 3  # Wait before proceeding

  # Define tool lists based on detected OS
  if [ "$OS" == "Red Hat-Based" ]; then
    TOOLS=("gcc" "openssl-devel" "wget" "make" "nano" "curl" "tar" "coreutils" "util-linux")
  elif [ "$OS" == "Debian-Based" ]; then
    TOOLS=("build-essential" "libssl-dev" "wget" "make" "nano" "curl" "tar" "coreutils" "util-linux")
  else
    print_red "Unsupported OS: $OS"
    exit 1
  fi

  ALL_INSTALLED=true
  INSTALLATION_OCCURRED=false  # Flag to track if any installation occurred
  OK_COUNT=0
  MISSING_COUNT=0
  TOOL_STATUS_LINES=()

  echo ""
  echo "┌───────────────────────────────────┐"
  print_green "│     Checking required tools       │"
  echo "└───────────────────────────────────┘"

  for TOOL in "${TOOLS[@]}"; do
    check_install_package "$TOOL"
    if [ $? -ne 0 ]; then
      ALL_INSTALLED=false
      INSTALLATION_OCCURRED=true  # Mark that something has been installed or attempted
      MISSING_COUNT=$((MISSING_COUNT+1))
      TOOL_STATUS_LINES+=("$TOOL\tMISSING")
    else
      OK_COUNT=$((OK_COUNT+1))
      TOOL_STATUS_LINES+=("$TOOL\tOK")
    fi
  done

  if [ "$ALL_INSTALLED" = true ]; then
    print_green "All tools are already installed."
  elif [ "$INSTALLATION_OCCURRED" = true ]; then
    print_yellow "Some tools were missing."
  fi

  echo "--------------------------------------------"
  if [ ${#TOOL_STATUS_LINES[@]} -gt 0 ]; then
    if command -v column >/dev/null 2>&1; then
      printf "%b\n" "Tool\tStatus" | column -t
      printf "%b\n" "----\t------" | column -t
      printf "%b\n" "${TOOL_STATUS_LINES[@]}" | column -t
    else
      printf "%b\n" "Tool\tStatus"
      printf "%b\n" "----\t------"
      printf "%b\n" "${TOOL_STATUS_LINES[@]}"
    fi
    echo "--------------------------------------------"
  fi
  print_green "OK: $OK_COUNT"
  if [ "$MISSING_COUNT" -gt 0 ]; then
    print_yellow "Missing: $MISSING_COUNT"
  else
    print_green "Missing: $MISSING_COUNT"
  fi
}

# Function to install Duo
run_install_duo() {
  show_loading_animation 3
  echo "----------------------------------"
  
  check_tools_and_install  # Call the function to check tools and install
  
  # Skip Duo installation if any tools were missing and installed
  if [ "$INSTALLATION_OCCURRED" = true ]; then
    print_yellow "Some Tools were missing. Skipping Duo installation for now."
   # main_menu  # Return to main menu after checking tools
  else
    print_yellow "Installing Duo..."
    show_loading_animation 5
    echo "----------------------------------"
    install_duo  # Call to the Duo installation function
  fi
}


# Function to check tools
check_tools() {
  detect_os  # Ensure OS is detected and set

# Call the function with the duration you want (e.g., 5 seconds)
show_loading_animation 3  # Wait before proceeding

  if [ "$OS" == "Red Hat-Based" ]; then
    TOOLS=("gcc" "openssl-devel" "wget" "make" "nano" "curl" "tar" "coreutils" "util-linux")
  elif [ "$OS" == "Debian-Based" ]; then
    TOOLS=("build-essential" "libssl-dev" "wget" "make" "nano" "curl" "tar" "coreutils" "util-linux")
  else
    print_red "Unsupported OS: $OS"
    exit 1
  fi

  ALL_INSTALLED=true
  INSTALLATION_OCCURRED=false  # Flag to track if any installation occurred
  OK_COUNT=0
  MISSING_COUNT=0
  TOOL_STATUS_LINES=()

  echo ""
  echo "┌───────────────────────────────────┐"
  print_green "│     Checking required tools       │"
  echo "└───────────────────────────────────┘"

  for TOOL in "${TOOLS[@]}"; do
    check_install_package "$TOOL"
    if [ $? -ne 0 ]; then
      ALL_INSTALLED=false
      INSTALLATION_OCCURRED=true  # Mark that something has been installed
      MISSING_COUNT=$((MISSING_COUNT+1))
      TOOL_STATUS_LINES+=("$TOOL\tMISSING")
    else
      OK_COUNT=$((OK_COUNT+1))
      TOOL_STATUS_LINES+=("$TOOL\tOK")
    fi
  done

  if [ "$ALL_INSTALLED" = true ]; then
    print_green "All tools are already installed."
  elif [ "$INSTALLATION_OCCURRED" = true ]; then
  
    print_yellow "Some tools were missing"
  fi

  echo "--------------------------------------------"
  if [ ${#TOOL_STATUS_LINES[@]} -gt 0 ]; then
    if command -v column >/dev/null 2>&1; then
      printf "%b\n" "Tool\tStatus" | column -t
      printf "%b\n" "----\t------" | column -t
      printf "%b\n" "${TOOL_STATUS_LINES[@]}" | column -t
    else
      printf "%b\n" "Tool\tStatus"
      printf "%b\n" "----\t------"
      printf "%b\n" "${TOOL_STATUS_LINES[@]}"
    fi
    echo "--------------------------------------------"
  fi
  print_green "OK: $OK_COUNT"
  if [ "$MISSING_COUNT" -gt 0 ]; then
    print_yellow "Missing: $MISSING_COUNT"
  else
    print_green "Missing: $MISSING_COUNT"
  fi

  # main_menu  # Return to main menu after checking tools
}

check_internet_install_duo() {
    echo "Checking internet connection..."

  # Check 1: Internet connectivity test using ping and port checks
    echo "Check 1: Testing internet connectivity with ping..."
    if ping -c 1 www.google.com > /dev/null 2>&1; then
        echo "Check 1 passed: Internet is connected (via ping)."

        # Check if ports 80 and 443 are reachable
        echo "Checking connectivity to port 80..."
        if nc -z -w 5 www.google.com 443 > /dev/null 2>&1; then
            echo "Port 80 is reachable."
        else
            echo -e "\033[0;31mPort 80 is not reachable\033[0m"
        fi

        echo "Checking connectivity to port 443..."
        if nc -z -w 5 www.google.com 80 > /dev/null 2>&1; then
            echo "Port 443 is reachable."
        else
            echo -e "\033[0;31mPort 443 is not reachable\033[0m"
        fi

        run_install_duo
        return
    else
        echo -e "\033[0;31mCheck 1 failed: Internet connectivity unsuccessful (via ping)\033[0m"
    fi

    # Check 2: Using curl to fetch Google
    echo "Check 2: Testing with curl to Google..."
    if curl -s --head http://www.google.com | head -n 1 | grep "HTTP/1.[01] [23].." > /dev/null; then
        echo "Check 2 passed: Internet is connected (via curl)."
        run_install_duo
        return
    else
        echo -e "\033[0;31mCheck 2 failed: Unable to connect via curl\033[0m"
    fi

    # Check 3: Using wget to download headers from Google
    echo "Check 3: Testing with wget to Google..."
    if wget --spider -q http://www.google.com; then
        echo "Check 3 passed: Internet is connected (via wget)."
        run_install_duo
        return
    else
        echo -e "\033[0;31mCheck 3 failed: Unable to connect via wget\033[0m"
    fi

    # If all checks failed, prompt to bypass
    echo -e "\033[0;31mAll internet checks failed.\033[0m"
    while true; do
        read -p "Do you want to bypass the internet check and continue? (Y/n): " choice
        case "$choice" in
            [Yy]* )
                echo "Bypassing internet check and proceeding with installation..."
                run_install_duo
                return
                ;;
            [Nn]* )
                echo "Exiting to main menu. Please check your internet connection."
                main_menu
                return
                ;;
            * )
                echo "Please answer Y (yes) or N (no)."
                ;;
        esac
    done
}

#======================================================================
#menu Settings

# Global variable to store the selected version
SELECTED_VERSION="duo_unix-2.2.2.tar.gz"

# Return expected sha256 checksum for known tarballs
get_expected_checksum() {
  local filename="$1"
  case "$filename" in
    duo_unix-2.2.2.tar.gz)
      echo "99c3fdf33905c82fd681217db6abe48a6be2ae36aacc0735043c20a7defa2913"
      ;;
    duo_unix-2.2.1.tar.gz)
      echo "e376be0585b3c3d113a588f19525e357cdee246d69aeb8e860cbf4fddbf900ca"
      ;;
    duo_unix-2.2.0.tar.gz)
      echo "a399b2014836b5ff98bbbb41f77114fe06641801d8b6b121eb3c82895276a666"
      ;;
    duo_unix-2.1.0.tar.gz)
      echo "42917ea997827789fb03e765eded0a7f0a50f8220922835931a7c43f3d83b629"
      ;;
    duo_unix-2.0.4.tar.gz)
      echo "3fb2155f8472304476057f7d149520bf6259c7b29d764b62275d35ad3249c264"
      ;;
    duo_unix-2.0.3.tar.gz)
      echo "3b4e262e613f03a8264b504b6753270cd4dea2a06490527fd0663dcc6c970de1"
      ;;
    duo_unix-2.0.2.tar.gz)
      echo "ee1b9677bd527674ded5e7fc3a81e040a8d840a56913c93fa0d4fb6c0f8e251d"
      ;;
    duo_unix-2.0.1.tar.gz)
      echo "3a2f123df3da192dc84e044e36deb43cbcb707d40809e0c3c88b0ffa20694269"
      ;;
    duo_unix-2.0.0.tar.gz)
      echo "0f90f748974ac6fe6271c372a5fb2172fae71dd9360fe87c7351a79bcee5ce06"
      ;;
    *)
      echo ""
      ;;
  esac
}

# Compute sha256 of a file using available tool (sha256sum or shasum)
compute_sha256() {
  local filepath="$1"
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$filepath" | awk '{print $1}'
  elif command -v shasum >/dev/null 2>&1; then
    shasum -a 256 "$filepath" | awk '{print $1}'
  else
    echo ""
  fi
}

# Prompt with Y/N and 5-second countdown auto-bypass to Yes
prompt_bypass_with_timeout() {
  local seconds=60
  local answer=""
  while [ $seconds -gt 0 ]; do
    printf "\rChecksum verification failed. Continue anyway? (Y/n) Auto-continue in %ds: " "$seconds"
    # Read a single character with 1-second timeout
    read -t 1 -n 1 answer 2>/dev/null
    if [ $? -eq 0 ]; then
      echo ""
      break
    fi
    seconds=$((seconds - 1))
  done
  echo ""
  if [[ -z "$answer" || "$answer" =~ ^[Yy]$ ]]; then
    return 0
  else
    return 1
  fi
}

# Function to fetch and display release notes from GitHub
fetch_release_notes() {
    local VERSION_TAG=$1
    local USER="duosecurity"
    local REPO="duo_unix"
    local API_URL="https://api.github.com/repos/$USER/$REPO/releases/tags/$VERSION_TAG"

    echo "Fetching release notes for $VERSION_TAG..."

    # Fetch release notes with curl, checking for network and API errors
    HTTP_RESPONSE=$(curl -s -w "%{http_code}" -o response.json "$API_URL")

    if [ "$HTTP_RESPONSE" -ne 200 ]; then
        echo "Error: Failed to fetch release notes (HTTP Status: $HTTP_RESPONSE)."
        rm -f response.json
        return
    fi

    # Extract release notes from the JSON response
    RELEASE_NOTES=$(grep -oP '"body":\s*"\K[^"]+' response.json)

    # Check if release notes are empty or null
    if [ -z "$RELEASE_NOTES" ]; then
        echo "No release notes found for $VERSION_TAG."
    else
        print_green "Release Notes for $VERSION_TAG:"
        echo "--------------------------------------------"
        echo ""
        print_green "$RELEASE_NOTES"
        echo ""
        echo "--------------------------------------------"
    fi

    # Clean up the temporary file
    rm -f response.json
}



# Function for the settings menu
settings() {
    echo "Settings Menu - Choose a Duo Unix version to download:"
    echo "1) Duo unix 2.2.2 (Default)"
    echo "2) Duo unix 2.2.1"
    echo "3) Duo unix 2.2.0"
    echo "4) Duo unix 2.0.4"
    echo "5) Duo unix 2.0.3"
    echo "6) Duo unix 2.0.2"
    echo "7) Duo unix 2.0.1"
    echo "8) Duo unix 2.0.0"
    echo "99) Duo unix latest (duo_unix-latest.tar.gz)"
    echo "0) Return to main menu"
    read -p "Choose a version (1-8 or 99): " CHOICE

    case $CHOICE in
        1) SELECTED_VERSION="duo_unix-2.2.2.tar.gz"; fetch_release_notes "duo_unix-2.2.2";;
        2) SELECTED_VERSION="duo_unix-2.2.1.tar.gz"; fetch_release_notes "duo_unix-2.2.1";;
        3) SELECTED_VERSION="duo_unix-2.2.0.tar.gz"; fetch_release_notes "duo_unix-2.2.0";;
        4) SELECTED_VERSION="duo_unix-2.0.4.tar.gz"; fetch_release_notes "duo_unix-2.0.4";;
        5) SELECTED_VERSION="duo_unix-2.0.3.tar.gz"; fetch_release_notes "duo_unix-2.0.3";;
        6) SELECTED_VERSION="duo_unix-2.0.2.tar.gz"; fetch_release_notes "duo_unix-2.0.2";;
        7) SELECTED_VERSION="duo_unix-2.0.1.tar.gz"; fetch_release_notes "duo_unix-2.0.1";;
        8) SELECTED_VERSION="duo_unix-2.0.0.tar.gz"; fetch_release_notes "duo_unix-2.0.0";;
        99) SELECTED_VERSION="duo_unix-latest.tar.gz";;
        0) main_menu; return;;
        *) echo "Invalid choice. Returning to settings..."; read -p "Press Enter to return to the menu..."; settings;;
    esac

    # Ask for confirmation to save the selected version
        read -p "Save this version as default (Y/n)? " CONFIRMATION
    if [[ "$CONFIRMATION" =~ ^[Yy]$ || -z "$CONFIRMATION" ]]; then
        print_green "Version $SELECTED_VERSION saved as default."
    else
        print_red "Version not saved. Returning to settings..."
        read -p "Press Enter to return to the menu..."
        main_menu
    fi

}

#======================================================================
#menu Settings

install_duo() {

    echo "Downloading Duo Unix version $SELECTED_VERSION..."
    wget --content-disposition "https://dl.duosecurity.com/$SELECTED_VERSION" -O "$SELECTED_VERSION"
    if [ $? -ne 0 ]; then
        print_red "Failed to download Duo Unix. Exiting..."
    fi

  # Verify sha256 integrity if possible
  EXPECTED_SHA=$(get_expected_checksum "$SELECTED_VERSION")
  ACTUAL_SHA=""
  if [ -z "$EXPECTED_SHA" ]; then
    # Try remote .sha256 if available
    if wget -q "https://dl.duosecurity.com/$SELECTED_VERSION.sha256" -O "$SELECTED_VERSION.sha256"; then
      EXPECTED_SHA=$(awk '{print $1}' "$SELECTED_VERSION.sha256" | head -n1)
      rm -f "$SELECTED_VERSION.sha256"
    fi
  fi
  ACTUAL_SHA=$(compute_sha256 "$SELECTED_VERSION")
  if [ -z "$ACTUAL_SHA" ]; then
    print_yellow "sha256 tool not found; skipping checksum verification."
  else
    if [ -n "$EXPECTED_SHA" ]; then
      if [ "$ACTUAL_SHA" != "$EXPECTED_SHA" ]; then
        print_red "SHA256 mismatch for $SELECTED_VERSION"
        echo "Expected: $EXPECTED_SHA"
        echo "Actual  : $ACTUAL_SHA"
        if ! prompt_bypass_with_timeout; then
          print_red "Aborting installation due to checksum mismatch."
          main_menu
          return
        else
          print_yellow "Bypassing checksum failure and continuing..."
        fi
      else
        print_green "SHA256 verified successfully."
      fi
    else
      print_yellow "No expected SHA256 available; skipping verification."
    fi
  fi

  # Extract Duo Unix
  echo "Extracting Duo Unix..."
  tar -xzvf "$SELECTED_VERSION"
  if [ $? -ne 0 ]; then
    print_red "Failed to extract $SELECTED_VERSION"
   # main_menu
  fi

  # Determine the extracted directory name
  DUO_DIR=$(tar -tzf "$SELECTED_VERSION" | head -1 | cut -f1 -d"/")
  if [ -z "$DUO_DIR" ]; then
    print_red "Failed to determine Duo Unix directory. Exiting..."
   # main_menu
  fi

  # Change directory to Duo Unix source directory
  echo "Changing directory to $DUO_DIR..."
  cd "$DUO_DIR"
  if [ $? -ne 0 ]; then
    print_red "Cannot change to directory $DUO_DIR"
   # main_menu
  fi

  # Check if login_duo.conf already exists
  if [ -f /etc/duo/login_duo.conf ] || [ -f /etc/login_duo.conf ]; then
    print_green "Duo Unix is already configured."
    echo "Configuring Duo Unix..."
    
    # If the config file exists, edit it
    if [ -f /etc/duo/login_duo.conf ]; then
      echo "Found login_duo.conf file."
      if [ -x "$(command -v nano)" ]; then
        nano /etc/duo/login_duo.conf
      else
        vi /etc/duo/login_duo.conf
      fi
    else
      echo "Found login_duo.conf file in /etc."
      if [ -x "$(command -v nano)" ]; then
        nano /etc/login_duo.conf
      else
        vi /etc/login_duo.conf
      fi
    fi
    
    # Change directory to Duo Unix source directory for configuration
    cd "$DUO_DIR"
  else
    # Install Duo Unix
    echo "Installing Duo Unix..."
    ./configure --prefix=/usr && make && sudo make install
    if [ $? -ne 0 ]; then
      print_red "Error during Duo Unix installation"
    #  main_menu
    else
      print_green "Duo Unix installed successfully."
    fi

    # Configure Duo Unix
    echo "Configuring Duo Unix..."
    if [ -f /etc/duo/login_duo.conf ]; then
      echo "Found login_duo.conf file."
      if [ -x "$(command -v nano)" ]; then
        nano /etc/duo/login_duo.conf
      else
        vi /etc/duo/login_duo.conf
      fi
    elif [ -f /etc/login_duo.conf ]; then
      echo "Found login_duo.conf file in /etc."
      if [ -x "$(command -v nano)" ]; then
        nano /etc/login_duo.conf
      else
        vi /etc/login_duo.conf
      fi
    else
      print_red "Error: login_duo.conf file not found in /etc/duo or /etc."
     # main_menu
    fi
  fi

  # Function to display Duo 2FA login configuration
  show_duo_config() {
    clear
    echo ""
    echo "--------------------------------------------"
    echo ""
    echo ""
    echo -e "\e[38;2;0;255;0m\e[1m# Duo 2FA login\e[0m"
    echo "ForceCommand /usr/sbin/login_duo"
    echo "PermitTunnel no"
    echo "AllowTcpForwarding no"
    echo ""
    echo ""
    echo "--------------------------------------------"
    echo ""
    echo "Please manually select and copy the above configuration text."
    echo "Right-click to copy, then paste it where needed."
    read -p "Press Enter to continue..."
    show_loading_animation 2
  }

  # Call the function
  show_duo_config

  # Edit SSH configuration
  echo "Editing SSH configuration..."
  cd /etc/ssh
  if [ -x "$(command -v nano)" ]; then
    nano sshd_config
  else
    vi sshd_config
  fi

  clear
  # Restart SSH service after configuration
  restart_ssh_service

  # print_green "Duo installation completed."
  # main_menu
}


# Restart SSH service
restart_ssh_service() {
  echo "--------------------------------------------"
  print_yellow "Restarting SSH service..."
  show_loading_animation 1

  # Function to handle successful restarts
  ssh_restart_success() {
    print_green "SSH service restarted successfully using $1."
  }

  # Attempt to restart SSH service using different methods
  if sudo systemctl restart sshd 2>/dev/null; then
    ssh_restart_success "systemctl"
    return
  elif sudo service ssh restart 2>/dev/null; then
    ssh_restart_success "service ssh"
    return
  elif sudo service sshd restart 2>/dev/null; then
    ssh_restart_success "service sshd"
    return
  else
    print_yellow "Cannot restarting the SSH service."
    print_red "Failed to restart SSH service. Please check the service Secure Shell status"
  fi
}


# # Function to check if Duo Unix is installed
# check_Duo_pam() {
#   detect_os  # Ensure OS is detected and set

#   show_loading_animation 3  # Show loading animation for 3 seconds

#   # Check if the OS is supported
#   if [ "$OS" == "Red Hat-Based" ]; then
#     # Use rpm to check for duo_unix on Red Hat-based systems
#     if rpm -q duo_unix > /dev/null 2>&1; then
#       print_green "Duo Unix is installed."
#     else
#       print_yellow "Duo Unix is not installed."
#     fi
#   elif [ "$OS" == "Debian-Based" ]; then
#     # Use dpkg to check for duo_unix on Debian-based systems
#     if dpkg -l | grep duo_unix > /dev/null 2>&1; then
#       print_green "Duo Unix is installed."
#     else
#       print_yellow "Duo Unix is not installed."
#     fi
#   else
#     print_red "Unsupported OS: $OS"
#     exit 1
#   fi
# }







uninstall_duo() {

  # Check if Duo is installed before uninstalling
  if ! rpm -q duo_unix > /dev/null 2>&1; then
    show_loading_animation 3
    print_yellow "Duo Pam is already uninstalled."
    DUO_ALREADY_UNINSTALLED=true
  else
    show_loading_animation 3
    print_yellow "Uninstalling Duo Pam..."

    # Remove Duo package
    sudo yum remove duo_unix -y
    print_green "Duo Unix package removed."
  fi

  # Check if Duo files exist
  if [ ! -d "/etc/duo" ] && [ ! -f "/etc/login_duo.conf" ] && [ ! -f "/usr/sbin/login_duo" ] && [ ! -f "/usr/lib/libduo.*" ] && [ ! -f "/etc/yum.repos.d/duosecurity.repo" ]; then
    show_loading_animation 3
    print_yellow "Duo files already removed."
    # Skip editing SSH configuration if files are already removed
    skip_ssh_config=true
  else
    show_loading_animation 3
    print_yellow "Removing Duo files..."

    # Remove Duo files
    show_progress_bar 1

    if [ -f "/etc/duo/login_duo.conf" ]; then
      sudo rm -rf /etc/duo/login_duo.conf
      print_green "Removed /etc/duo/login_duo.conf"
    else
      print_yellow "/etc/duo/login_duo.conf not found, skipping."
    fi

    if [ -f "/etc/login_duo.conf" ]; then
      sudo rm -rf /etc/login_duo.conf
      print_green "Removed /etc/login_duo.conf"
    else
      print_yellow "/etc/login_duo.conf not found, skipping."
    fi

    show_progress_bar 1
    if [ -f "/usr/sbin/login_duo" ]; then
      sudo rm -rf /usr/sbin/login_duo
      print_green "Removed /usr/sbin/login_duo"
    else
      print_yellow "/usr/sbin/login_duo not found, skipping."
    fi

    show_progress_bar 1
    if ls /usr/lib/libduo.* 1> /dev/null 2>&1; then
      sudo rm -rf /usr/lib/libduo.*
      print_green "Removed libduo.*"
    else
      print_yellow "libduo.* not found, skipping."
    fi

    show_progress_bar 1
    if [ -f "/etc/yum.repos.d/duosecurity.repo" ]; then
      sudo rm -rf /etc/yum.repos.d/duosecurity.repo
      print_green "Removed duosecurity.repo"
    else
      print_yellow "duosecurity.repo not found, skipping."
    fi

    show_progress_bar 1
    if [ -d "/etc/duo" ]; then
      sudo rm -rf /etc/duo
      print_green "Removed /etc/duo directory"
    else
      print_yellow "/etc/duo directory not found or not empty, skipping."
    fi

    show_progress_bar 3
  fi

  # Only edit SSH configuration if Duo files were removed
  if [ "${DUO_ALREADY_UNINSTALLED:-false}" = "true" ]; then
    echo "--------------------------------------------"
    print_yellow "Manual cleanup suggested in SSH config. Remove this line if present:"
    echo ""
    print_green "In /etc/ssh/sshd_config remove (or set to 'no') this line:"
    echo "ChallengeResponseAuthentication yes"
    echo "--------------------------------------------"

    # Edit SSH configuration only
    echo "Editing SSH configuration (/etc/ssh/sshd_config)..."
    cd /etc/ssh
    if [ -x "$(command -v nano)" ]; then
      nano sshd_config
    else
      vi sshd_config
    fi
  elif [ -z "$skip_ssh_config" ]; then
    echo "--------------------------------------------"
    print_yellow "Manual cleanup required in SSH and PAM configs. Remove these lines if present:"
    echo ""
    print_green "In /etc/ssh/sshd_config remove (or set to 'no') this line:"
    echo "ChallengeResponseAuthentication yes"
    echo ""
    print_green "In /etc/pam.d/sshd remove this line:"
    echo "auth       required     pam_duo.so"
    echo "--------------------------------------------"

    # Edit SSH configuration
    echo "Editing SSH configuration (/etc/ssh/sshd_config)..."
    cd /etc/ssh
    if [ -x "$(command -v nano)" ]; then
      nano sshd_config
    else
      vi sshd_config
    fi

    # Edit PAM sshd configuration
    echo "Editing PAM configuration (/etc/pam.d/sshd)..."
    cd /etc/pam.d
    if [ -x "$(command -v nano)" ]; then
      nano sshd
    else
      vi sshd
    fi
  fi
  
  

  # Restart SSH service using the restart_ssh_service function
  restart_ssh_service

  print_green "Duo uninstallation completed."
}




# #------------------------------------------------------------

# # Function to uninstall Duo
# uninstall_duo() {
#   if [ ! -d "/etc/duo" ] && [ ! -f "/etc/login_duo.conf" ]; then
#     show_loading_animation 3
#     print_yellow "Duo is already uninstalled."
#   else
#     show_loading_animation 3
#     print_yellow "Uninstalling Duo..."

#     # Remove Duo files
#     show_progress_bar 1

#     # Check and remove /etc/duo/login_duo.conf if it exists
#     if [ -f "/etc/duo/login_duo.conf" ]; then
#       sudo rm -rf /etc/duo/login_duo.conf
#       print_green "Removed /etc/duo/login_duo.conf"
#     else
#       print_yellow "/etc/duo/login_duo.conf not found, skipping."
#     fi

#     # Check and remove /etc/login_duo.conf if it exists
#     if [ -f "/etc/login_duo.conf" ]; then
#       sudo rm -rf /etc/login_duo.conf
#       print_green "Removed /etc/login_duo.conf"
#     else
#       print_yellow "/etc/login_duo.conf not found, skipping."
#     fi

#     show_progress_bar 1

#     # Remove the login_duo binary if it exists
#     if [ -f "/usr/sbin/login_duo" ]; then
#       sudo rm -rf /usr/sbin/login_duo
#       print_green "Removed /usr/sbin/login_duo"
#     else
#       print_yellow "/usr/sbin/login_duo not found, skipping."
#     fi

#     show_progress_bar 1

#     # Remove libduo.* files if they exist
#     if ls /usr/lib/libduo.* 1> /dev/null 2>&1; then
#       sudo rm -rf /usr/lib/libduo.*
#       print_green "Removed libduo.*"
#     else
#       print_yellow "libduo.* not found, skipping."
#     fi

#     show_progress_bar 1

#     # Remove /etc/duo directory if it exists and is empty
#     if [ -d "/etc/duo" ]; then
#       sudo rm -rf /etc/duo
#       print_green "Removed /etc/duo directory"
#     else
#       print_yellow "/etc/duo directory not found or not empty, skipping."
#     fi

#     show_progress_bar 3

#     # Edit SSH configuration to remove Duo settings
#     echo "Editing SSH configuration..."
#     cd /etc/ssh
#     if [ -x "$(command -v nano)" ]; then
#       nano sshd_config
#     else
#       vi sshd_config
#     fi

#     # Restart SSH service using the restart_ssh_service function
#     restart_ssh_service

#     print_green "Duo uninstallation completed."
#   fi
#   # main_menu
# }

# #------------------------------------------------------------


# Function to check for root permission
check_root_permission() {
  if [ "$EUID" -ne 0 ]; then
    print_red ""-------------------------------""
    print_red "This script must be run as root."
    print_red ""-------------------------------""
    echo ""
    exit 1
  fi
}

# Function to get Duo version
get_duo_version() {
    local version=""
    local login_duo_path=""
    
    # Find login_duo binary in common locations
    for path in /usr/sbin/login_duo /usr/local/sbin/login_duo /sbin/login_duo; do
        if [ -f "$path" ] && [ -x "$path" ]; then
            login_duo_path="$path"
            break
        fi
    done
    
    # If not found in common paths, try command -v
    if [ -z "$login_duo_path" ]; then
        if command -v login_duo >/dev/null 2>&1; then
            login_duo_path="login_duo"
        fi
    fi
    
    # Try to get version from login_duo -v (capture both stdout and stderr)
    if [ -n "$login_duo_path" ]; then
        # Try to get version - login_duo -v might output to stderr or stdout
        # Don't fail on error codes, just capture output
        local output=$($login_duo_path -v 2>&1 || true)
        
        # Extract version number (look for patterns like "2.2.2" or "login_duo 2.2.2")
        if [ -n "$output" ]; then
            # Try to extract version number (e.g., "2.2.2" or "2.2.0")
            version=$(echo "$output" | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -n1)
            
            # If no version pattern found, try to get the first line and clean it (but skip error messages)
            if [ -z "$version" ]; then
                local first_line=$(echo "$output" | head -n1 | tr -d '\n' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
                if [ -n "$first_line" ] && ! echo "$first_line" | grep -qi "error\|not found\|command\|usage"; then
                    version="$first_line"
                fi
            fi
        fi
    fi
    
    # Clean up the version string if it exists
    if [ -n "$version" ]; then
        echo "$version"
    else
        echo "Not Installed"
    fi
}

# Function to display the main menu with borders, clear only once initially
main_menu() {
    clear  # Always clear the screen before showing the menu
    
    # Get Duo version
    DUO_VERSION=$(get_duo_version)

    # Display currently selected Duo package version (from settings)
    local SELECTED_VERSION_DISPLAY
    if [ -n "$SELECTED_VERSION" ]; then
        SELECTED_VERSION_DISPLAY="${SELECTED_VERSION#duo_unix-}"
        SELECTED_VERSION_DISPLAY="${SELECTED_VERSION_DISPLAY%.tar.gz}"
    else
        SELECTED_VERSION_DISPLAY="Not Set"
    fi
    
    echo        "┌──────────────────────────────────────────────────────────────────────┐"
    if [ "$DUO_VERSION" != "Not Installed" ]; then
        VERSION_TEXT="Duo Version: $DUO_VERSION"
        # Format: "                        DUO INSTALLER MENU V1.3                         Duo Version: [version] |"
        # Box width is 70, borders take 2, so 68 chars for content
        LEFT_PART="          DUO INSTALLER MENU V1.3"
        # Calculate padding to right-align version (68 total - left part - version text)
        PADDING=$((   68 - ${#LEFT_PART} - ${#VERSION_TEXT}))
        if [ $PADDING -lt 1 ]; then
            PADDING=1
        fi
        printf "\033[32m│%s%*s%s│\033[0m\n" "$LEFT_PART" "$PADDING" "" "$VERSION_TEXT  "
    else
        VERSION_TEXT="   Duo Version: Not Installed"
        LEFT_PART="          DUO INSTALLER MENU V1.3"
        PADDING=$((68 - ${#LEFT_PART} - ${#VERSION_TEXT}))
        if [ $PADDING -lt 1 ]; then
            PADDING=1
        fi
        printf "\033[32m│%s%*s%s│\033[0m\n" "$LEFT_PART" "$PADDING" "" "$VERSION_TEXT  "
    fi
    echo        "├──────────────────────────────────────────────────────────────────────┤"
    echo        "│ Select an option:                                                    │"
    echo        "│                                                                      │"
    echo        "│ 1) Install Duo                                                       │"
    echo        "│ 2) Uninstall Duo                                                     │"
    echo        "│ 3) Check OS Version                                                  │"
    echo        "│ 4) Check Tools                                                       │"
    echo        "│ 5) Check Users List                                                  │"
    printf      "│ %-66s   │\n" "6) Settings Duo Version (${SELECTED_VERSION_DISPLAY})" 
    echo -e    "│ 7) Install Duo PAM \e[31m(Warning)   \e[0m                                      │"
    echo        "│                                                                      │"
    echo        "└──────────────────────────────────────────────────────────────────────┘"
    read -p "Enter your choice: " CHOICE
    echo ""

    case $CHOICE in
        1)
            check_internet_install_duo
            read -p "Press Enter to return to the menu..."
            main_menu  # Clear and return to menu
            ;;
        2)
            uninstall_duo
            read -p "Press Enter to return to the menu..."
            main_menu  # Clear and return to menu
            ;;
        3)
            check_os_version
            read -p "Press Enter to return to the menu..."
            main_menu  # Clear and return to menu
            ;;
        4)
            check_tools
            echo ""
            read -p "Press Enter to return to the menu..."
            main_menu  # Clear and return to menu
            ;;
        5)
            echo "--------------------------------------------"
            echo ""
            HUMAN_USERS=$(awk -F: '($1=="root" || $3>=1000) && $7 !~ /(nologin|false)/ {print $1}' /etc/passwd | sort)
            COUNT=$(echo "$HUMAN_USERS" | grep -c .)
            print_green "login users ($COUNT):"
            if [ -n "$HUMAN_USERS" ]; then
              if command -v column >/dev/null 2>&1; then
                echo "$HUMAN_USERS" | nl -w2 -s'. ' | column
              else
                echo "$HUMAN_USERS" | nl -w2 -s'. '
              fi
            else
              print_yellow "No human/login users found."
            fi
            echo ""
            read -p "Press Enter to return to the menu..."
            main_menu  # Clear and return to menu
            ;;
        6)
            settings
            read -p "Press Enter to return to the menu..."
            main_menu  # Clear and return to menu
            ;;
        7)
            echo ""
            echo "--------------------------------------------"
            print_red "Warning: Install Duo PAM is unfinished."
            print_yellow "This process may modify PAM and SSH configurations."
            print_yellow "Ensure you have console access and backups of /etc/pam.d and /etc/ssh."
            echo "--------------------------------------------"
            read -p "Press Enter to continue, or press 0 to abort and return to the main menu: " PAM_ACK
            if [[ "$PAM_ACK" == "0" ]]; then
                main_menu
                return
            fi
            check_internet_install_duo_pam
            read -p "Press Enter to return to the menu..."
            main_menu  # Clear and return to menu
            ;;
        *)
            print_red "Invalid choice, please try again."
            read -p "Press Enter to return to the menu..."
            main_menu  # Clear and return to menu
            ;;
    esac
}

check_root_permission
main_menu





#=============================================


