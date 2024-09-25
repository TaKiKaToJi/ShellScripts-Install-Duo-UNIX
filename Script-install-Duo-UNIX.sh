#!/bin/bash

# Display colored and large text
  echo -e "\e[38;2;0;255;0m\e[1m
░█░░▒█▒██▀░█▒░░▄▀▀░▄▀▄░█▄▒▄█▒██▀░░░█░█▄░█░▀█▀▒██▀▒█▀▄░█▄░█▒██▀░▀█▀░░░▀█▀░█▄█▒▄▀▄░█░█▒░▒▄▀▄░█▄░█░█▀▄
░▀▄▀▄▀░█▄▄▒█▄▄░▀▄▄░▀▄▀░█▒▀▒█░█▄▄▒░░█░█▒▀█░▒█▒░█▄▄░█▀▄░█▒▀█░█▄▄░▒█▒▒░░▒█▒▒█▒█░█▀█░█▒█▄▄░█▀█░█▒▀█▒█▄▀
\e[0m"

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


# Function to check OS version, kernel, hostname, and IP address
check_os_version() {
  echo "Checking OS version, kernel, hostname, and IP address..."

  # Determine the OS
  detect_os

  # Retrieve OS version based on OS type
  if [ "$OS" == "Debian-Based" ]; then
    OS_VERSION=$(lsb_release -a 2>/dev/null || cat /etc/os-release)
  elif [ "$OS" == "Red Hat-Based" ]; then
    OS_VERSION=$(cat /etc/redhat-release)
  else
    OS_VERSION="Unsupported OS"
  fi

  # Retrieve kernel version
  KERNEL_VERSION=$(uname -r)

  # Check if hostname command is available and get hostname
  if command -v hostname &> /dev/null; then
    HOSTNAME=$(hostname)
  else
    HOSTNAME="Hostname command not found"
  fi

  # Retrieve IP address
  IP_ADDRESS=$(hostname -I | awk '{print $1}')
  if [ -z "$IP_ADDRESS" ]; then
    IP_ADDRESS="IP Address not found"
  fi

  # Display results
  print_green "OS version: $OS_VERSION"
  print_green "Kernel version: $KERNEL_VERSION"
  print_green "Hostname: $HOSTNAME"
  print_green "IP Address: $IP_ADDRESS"

  main_menu
}


# Function to detect OS and set the OS variable
detect_os() {
  if [ -f /etc/redhat-release ]; then
    OS="Red Hat-Based"
  elif [ -f /etc/debian_version ]; then
    OS="Debian-Based"
  else
    OS="Unsupported"
  fi
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

# Function to check and install a package based on OS type
check_install_package() {
  PACKAGE_NAME=$1

  # Detect the OS type and set the package manager and command accordingly
  if [ "$OS" == "Red Hat-Based" ]; then
    COMMAND_CHECK="rpm -q $PACKAGE_NAME"
    INSTALL_COMMAND="sudo yum install -y $PACKAGE_NAME"
  elif [ "$OS" == "Debian-Based" ]; then
    COMMAND_CHECK="dpkg -l | grep '^ii' | grep $PACKAGE_NAME"
    INSTALL_COMMAND="sudo apt-get install -y $PACKAGE_NAME"
  else
    print_red "Unsupported OS."
    return 1
  fi

  # Check if the package is installed
  if eval "$COMMAND_CHECK" &> /dev/null; then
    print_green "$PACKAGE_NAME is already installed."
    return 0
  else
    print_yellow "$PACKAGE_NAME not found. Installing $PACKAGE_NAME..."
    if eval "$INSTALL_COMMAND"; then
      print_green "$PACKAGE_NAME installed successfully."
      return 0
    else
      print_red "Failed to install $PACKAGE_NAME."
      return 1
    fi
  fi
}

# Function to check tools
check_tools_and_install() {
  detect_os  # Ensure OS is detected and set
  clean_package_cache  # Run clean package cache only once

# Call the function with the duration you want (e.g., 5 seconds)
show_loading_animation 3  # Wait before proceeding

  if [ "$OS" == "Red Hat-Based" ]; then
    TOOLS=("gcc" "openssl-devel" "wget" "make" "nano" "curl")
  elif [ "$OS" == "Debian-Based" ]; then
    TOOLS=("build-essential" "libssl-dev" "wget" "make" "nano" "curl")
  else
    print_red "Unsupported OS: $OS"
    exit 1
  fi

  ALL_INSTALLED=true
  INSTALLATION_OCCURRED=false  # Flag to track if any installation occurred

  for TOOL in "${TOOLS[@]}"; do
    check_install_package "$TOOL"
    if [ $? -ne 0 ]; then
      ALL_INSTALLED=false
      INSTALLATION_OCCURRED=true  # Mark that something has been installed
    fi
  done

  if [ "$ALL_INSTALLED" = true ]; then
    print_green "All tools are already installed."
  elif [ "$INSTALLATION_OCCURRED" = true ]; then
    print_yellow "Some tools were missing and have been installed."
  fi

  #main_menu  # Return to main menu after checking tools
}

# Function to check tools
check_tools() {
  detect_os  # Ensure OS is detected and set
  clean_package_cache  # Run clean package cache only once

# Call the function with the duration you want (e.g., 5 seconds)
show_loading_animation 3  # Wait before proceeding

  if [ "$OS" == "Red Hat-Based" ]; then
    TOOLS=("gcc" "openssl-devel" "wget" "make" "nano" "curl")
  elif [ "$OS" == "Debian-Based" ]; then
    TOOLS=("build-essential" "libssl-dev" "wget" "make" "nano" "curl")
  else
    print_red "Unsupported OS: $OS"
    exit 1
  fi

  ALL_INSTALLED=true
  INSTALLATION_OCCURRED=false  # Flag to track if any installation occurred

  for TOOL in "${TOOLS[@]}"; do
    check_install_package "$TOOL"
    if [ $? -ne 0 ]; then
      ALL_INSTALLED=false
      INSTALLATION_OCCURRED=true  # Mark that something has been installed
    fi
  done

  if [ "$ALL_INSTALLED" = true ]; then
    print_green "All tools are already installed."
  elif [ "$INSTALLATION_OCCURRED" = true ]; then
    print_yellow "Some tools were missing and have been installed."
  fi

  main_menu  # Return to main menu after checking tools
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



run_install_duo() {
  show_loading_animation 3
  echo "----------------------------------"
  
  check_tools_and_install  # Call the function to check tools and install
  print_yellow "Installing Duo..." 
  show_loading_animation 5
  echo "----------------------------------"
  
  install_duo  # Call to the Duo installation function
}

install_duo() {

  # Download Duo Unix
  DUO_ARCHIVE="duo_unix-latest.tar.gz"
  echo "Downloading Duo Unix..."
  wget --content-disposition "https://dl.duosecurity.com/duo_unix-latest.tar.gz" -O "$DUO_ARCHIVE"
  if [ $? -ne 0 ]; then
    print_red "Failed to download Duo Unix. Exiting..."
    main_menu
  fi

  # Extract Duo Unix
  echo "Extracting Duo Unix..."
  tar -xzvf "$DUO_ARCHIVE"
  if [ $? -ne 0 ]; then
    print_red "Failed to extract $DUO_ARCHIVE"
    main_menu
  fi

  # Determine the extracted directory name
  DUO_DIR=$(tar -tzf "$DUO_ARCHIVE" | head -1 | cut -f1 -d"/")
  if [ -z "$DUO_DIR" ]; then
    print_red "Failed to determine Duo Unix directory. Exiting..."
    main_menu
  fi

  # Change directory to Duo Unix source directory
  echo "Changing directory to $DUO_DIR..."
  cd "$DUO_DIR"
  if [ $? -ne 0 ]; then
    print_red "Cannot change to directory $DUO_DIR"
    main_menu
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
      main_menu
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
      main_menu
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

  # Restart SSH service after configuration
  restart_ssh_service

  print_green "Duo installation completed."
  main_menu
}




# Restart SSH service
restart_ssh_service() {
  echo "--------------------------------------------"
  print_yellow "Restarting SSH service..."
  show_loading_animation 1

  # Detect OS before attempting to restart the SSH service
  detect_os

  # Attempt to restart SSH service based on OS type
  if [[ "$OS" == "Debian-Based" || "$OS" == "Red Hat-Based" ]]; then
    if sudo systemctl restart sshd; then
      print_green "SSH service restarted successfully using systemctl."
      return
    elif sudo service ssh restart; then
      print_green "SSH service restarted successfully using service ssh."
      return
    elif sudo service sshd restart; then
      print_green "SSH service restarted successfully using service sshd."
      return
    else
      print_red "Error restarting SSH service. Please check the service status."
      main_menu
    fi
  else
    print_red "Unsupported OS for SSH service restart."
    main_menu
  fi
}


# Function to uninstall Duo
uninstall_duo() {
  if [ ! -d "/etc/duo" ]; then
    show_loading_animation 3
    print_yellow "Duo is already uninstalled."
  else
    show_loading_animation 3
    print_yellow "Uninstalling Duo..."

    # Remove Duo files
    show_progress_bar 1
    sudo rm -rf /etc/duo/login_duo.conf
    print_green "Removed login_duo.conf"
    show_progress_bar 1
    sudo rm -rf /usr/sbin/login_duo
    print_green "Removed login_duo"
    show_progress_bar 1
    sudo rm -rf /usr/lib/libduo.*
    print_green "Removed libduo.*"
    show_progress_bar 1
    sudo rmdir /etc/duo
    print_green "Removed dir duo"
    
    show_progress_bar 3
    
    # Edit SSH configuration to remove Duo settings
    echo "Editing SSH configuration..."
    cd /etc/ssh
    if [ -x "$(command -v nano)" ]; then
      nano sshd_config
    else
      vi sshd_config
    fi

    # Restart SSH service using the restart_ssh_service function
    restart_ssh_service
    
    print_green "Duo uninstallation completed."
  fi
  main_menu
}


# Function to delete this script
self_delete() {
    print_green "Deleting this script..."
    trap 'rm -- "$0"' EXIT
    exec rm -- "$0"
}

# Function to display the main menu
main_menu() {
    echo "--------------------------------------------"
    echo "Select an option:"
    echo "1) Install Duo"
    echo "2) Uninstall Duo"
    echo "3) Check OS Version"
    echo "4) Check Tools"
    echo "5) Check passwd"
    echo "6) Delete Script"
    read -p "Enter your choice: " CHOICE
    echo "--------------------------------------------"

    case $CHOICE in
        1)
            check_internet_install_duo
            ;;
        2)
            uninstall_duo
            ;;
        3)
            check_os_version 
            ;;
        4)
            check_tools
            ;;
        5)
            echo "--------------------------------------------"
            echo ""
            cut -d: -f1 /etc/passwd
            echo ""
            main_menu
            ;;
        6)
            self_delete 
            ;;
        *)
            print_red "Invalid choice, please try again."
            main_menu
            ;;
    esac
}

main_menu

#=============================================


