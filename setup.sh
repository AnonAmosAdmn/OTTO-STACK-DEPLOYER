#!/bin/bash

#==============================================================================#
#                  OTTO Stack Deployer™️ by AnonAmosAdmn                        #
#==============================================================================#
# This script sets up a full-stack application based on user-selected stacks.  #
# It supports multiple backend, frontend, and database combinations and        #
# integrates with Docker, Kubernetes (K8s), CI/CD pipelines, and monitoring.   #
#______________________________________________________________________________#

### INITIAL SETUP

trap 'otto_error "Script interrupted."; exit 1' INT TERM

rm -rf log my-fullstack-app
mkdir -p log

exec > >(tee -i log/otto.log) 2>&1

clear

### UTILITY FUNCTIONS

BLACK='\033[0;30m'
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[0;37m'
NC='\033[0m'
BOLD='\033[1m'

otto_clean_line() { 
    echo -en "\r\033[K"; 
}

otto_check_command_exists() { 
    command -v "$1" >/dev/null 2>&1; 
}

otto_main() { 
    echo "$1" | sed 's/[^a-zA-Z0-9_-]//g'; 
}

otto_clear() {
    clear
    echo -e "${GREEN}${BOLD}
     ██████╗ ████████╗████████╗ ██████╗       ███████╗████████╗ █████╗  ██████╗██╗  ██╗
    ██╔═══██╗╚══██╔══╝╚══██╔══╝██╔═══██╗      ██╔════╝╚══██╔══╝██╔══██╗██╔════╝██║ ██╔╝
    ██║   ██║   ██║      ██║   ██║   ██║      ███████╗   ██║   ███████║██║     █████╔╝ 
    ██║   ██║   ██║      ██║   ██║   ██║      ╚════██║   ██║   ██╔══██║██║     ██╔═██╗ 
    ╚██████╔╝   ██║      ██║   ╚██████╔╝      ███████║   ██║   ██║  ██║╚██████╗██║  ██╗
     ╚═════╝    ╚═╝      ╚═╝    ╚═════╝       ╚══════╝   ╚═╝   ╚═╝  ╚═╝ ╚═════╝╚═╝  ╚═╝

            ██████╗ ███████╗██████╗ ██╗      ██████╗ ██╗   ██╗███████╗██████╗ TM
            ██╔══██╗██╔════╝██╔══██╗██║     ██╔═══██╗╚██╗ ██╔╝██╔════╝██╔══██╗
            ██║  ██║█████╗  ██████╔╝██║     ██║   ██║ ╚████╔╝ █████╗  ██████╔╝
            ██║  ██║██╔══╝  ██╔═══╝ ██║     ██║   ██║  ╚██╔╝  ██╔══╝  ██╔══██╗
            ██████╔╝███████╗██║     ███████╗╚██████╔╝   ██║   ███████╗██║  ██║
            ╚═════╝ ╚══════╝╚═╝     ╚══════╝ ╚═════╝    ╚═╝   ╚══════╝╚═╝  ╚═╝

                OTTO-Stack-Deployer™️    by AnonAmosAdmn    August 15th 2024${NC}"
    echo
}

otto_spacer() {
    echo -e "${BLUE}${BOLD}______________________________________________________________________________________________${NC}\n"
    echo
}

otto_progress() {
    local duration=${1}
    already_done() { for ((done=0; done<$elapsed; done++)); do echo -n "🟩"; done }
    remaining() { for ((remain=$elapsed; remain<$duration; remain++)); do echo -n ":"; done }
    percentage() { echo -n " ($((elapsed * 100 / duration))%)"; }
    for ((elapsed=1; elapsed<=duration; elapsed++))
    do
        echo -n " "; already_done; remaining; percentage
        sleep 1
        otto_clean_line
    done
    echo
}

otto_title() {
    local message=$1
    echo
    otto_spacer
    echo -e "${MAGENTA}${BOLD}${message}${NC}\n"
    otto_spacer
}

otto_menu() {
    local title=$1
    local options=("${@:2}")
    echo -e "${MAGENTA}${BOLD}${title}${NC}"
    for option in "${options[@]}"; do
        echo -e "${CYAN}${BOLD}${option}${NC}"
    done
}

otto_prompt() {
    local message=$1
    local variable_name=$2
    local default_value=$3
    echo
    echo -en "${MAGENTA}${BOLD}${message} ${NC}\n"
    if [ -n "$default_value" ]; then
        echo -en " [ ${YELLOW}${BOLD}default value = ${default_value} ${NC}]  ? "
    fi
    read user_input
    echo
    if [ -z "$user_input" ] && [ -n "$default_value" ]; then
        user_input="$default_value"
    fi
    eval "$variable_name=\"\$user_input\""
}

otto_text() {
    local message=$1
    echo
    echo -e "${CYAN}${message}${NC}\n"
}

otto_log() {
    local message=$1
    echo
    echo -e "${YELLOW}${message}${NC}\n"
}

otto_success() {
    local message=$1
    echo
    echo -e "${GREEN}${BOLD}${message}${NC} $(date "+%B %d %Y %H:%M:%S")\n"
}

otto_error() {
    local message=$1
    echo
    echo -e "${RED}${BOLD}${message}${NC} $(date "+%B %d %Y %H:%M:%S")\n"
}

otto_set_env() {
    local key=$1
    local value=$2
    echo "$key=$value" >> .env
}

otto_service() {
    local service_name=$1
    local action=$2
    sudo systemctl $action $service_name
}

otto_validate_numeric() {
    local input=$1
    if ! [[ "$input" =~ ^[0-9]+$ ]]; then
        otto_error "Invalid input: $input. Please enter a number."
        return 1
    fi
    return 0
}

otto_pause () {
    otto_prompt "Press Enter to continue..." CONTINUE
}


### UPDATE SYSTEM

otto_update() {
    otto_title "Updating system..."
    sudo apt-get clean
    otto_apt_lock
    sudo apt-get update
    otto_apt_lock
    sudo apt-get full-upgrade -y
    otto_apt_lock
    sudo apt-get autoremove -y
    otto_apt_lock
    otto_success "System update completed."
}

otto_apt_lock() {
    while sudo fuser /var/lib/dpkg/lock-frontend >/dev/null 2>&1; do
        otto_error "Waiting for apt lock 🔐"
        echo
        otto_progress 5
    done
}


### SYSTEM INFORMATION

otto_system_info() {

    local TITLE="System Information"
    local USER_NAME=$(whoami)
    local USER_ID=$(id -u "$USER_NAME")
    local GROUP_ID=$(id -g "$USER_NAME")
    local CPU_MODEL=$(lscpu | grep "Model name:" | sed 's/Model name: *//g')
    local CPU_CORES=$(lscpu | grep "^CPU(s):" | awk '{print $2}')
    local TOTAL_RAM=$(grep MemTotal /proc/meminfo | awk '{print $2}')
    local DISK_SPACE=$(df -h --output=avail -x tmpfs -x devtmpfs / | tail -1)
    local GPU_INFO=$(lspci | grep -i 'vga\|3d\|2d')
    local KERNEL_VERSION=$(uname -r)
    local OS_NAME=$(lsb_release -ds)
    local OS_VERSION=$(lsb_release -cs)
    local OS_ARCH=$(uname -m)
    local SHELL=$(echo $SHELL)
    local HOME_DIR=$HOME
    local PATH=$PATH
    local IP_ADDRESS=$(hostname -I | awk '{print $1}')
    local HOST_NAME=$(hostname)
    local FQDN=$(hostname -f)
    local NETWORK_INTERFACES=$(ip -o link show | awk -F': ' '{print $2}')
    local PACKAGE_MANAGER=$(which apt-get || which yum || which dnf || which pacman)
    local OPEN_PORTS=$(netstat -tuln | awk '{print $4}' | grep -Eo '[0-9]+$' | sort -u)
    local FIREWALL_RULES=$(sudo iptables -L -v -n)
    local BUILD_TOOL=$(which make || which cmake || which maven || which gradle)
    local LOG_FILES=$(find /var/log -type f)
    local CURRENT_DATE=$(date "+%B %d %Y")
    local CURRENT_TIME=$(date "+%H:%M:%S")
    local SYSTEM_UPTIME=$(uptime -p)
    # local INSTALLED_PACKAGES=$(dpkg --get-selections | grep -v deinstall) 

    otto_title "System Information"
    otto_text "User Name:\n${NC} $USER_NAME"
    otto_text "User ID:\n${NC} $USER_ID"
    otto_text "Group ID:\n${NC} $GROUP_ID"
    otto_text "CPU Model:\n${NC} $CPU_MODEL"
    otto_text "CPU Cores:\n${NC} $CPU_CORES"
    otto_text "Total RAM:\n${NC} ${TOTAL_RAM} kB"
    otto_text "Disk Space:\n${NC} $DISK_SPACE"
    otto_text "GPU Info:\n${NC} $GPU_INFO"
    otto_text "Kernel Version:\n${NC} $KERNEL_VERSION"
    otto_text "OS Name:\n${NC} $OS_NAME"
    otto_text "OS Version:\n${NC} $OS_VERSION"
    otto_text "OS Architecture:\n${NC} $OS_ARCH"
    otto_text "Shell:\n${NC} $SHELL"
    otto_text "Home Directory:\n${NC} $HOME_DIR"
    otto_text "Path:\n${NC} $PATH"
    otto_text "IP Address:\n${NC} $IP_ADDRESS"
    otto_text "Host Name:\n${NC} $HOST_NAME"
    otto_text "FQDN:\n${NC} $FQDN"
    otto_text "Network Interfaces:\n${NC} $NETWORK_INTERFACES"
    otto_text "Package Manager:\n${NC} $PACKAGE_MANAGER"
    otto_text "Open Ports:\n${NC} $OPEN_PORTS"
    otto_text "Firewall Rules:\n${NC} $FIREWALL_RULES"
    otto_text "Build Tool:\n${NC} $BUILD_TOOL"
    otto_text "Log Files:\n${NC} $LOG_FILES"
    otto_text "Current Date:\n${NC} $CURRENT_DATE"
    otto_text "Current Time:\n${NC} $CURRENT_TIME"
    otto_text "System Uptime:\n${NC} $SYSTEM_UPTIME"
    # otto_text "Installed Packages: $INSTALLED_PACKAGES"
}


### INSTALL ESSENTIAL TOOLS

otto_install_essentials() {
    otto_title "Checking and installing essential packages..."

    # Install tools
    otto_text "Installing Essential Tools ${NC}..."
    sudo apt-get install -y htop net-tools nmap tmux git curl certbot brave-browser
    otto_apt_lock

    # Display versions
    otto_text "tmux ${NC}: $(tmux -V | awk '{print $2}')"
    otto_text "certbot ${NC}: $(certbot --version | awk '{print $2}')"
    otto_text "htop ${NC}: $(htop --version | head -n 1 | awk '{print $2}')"
    otto_text "Git ${NC}: $(git --version | awk '{print $3}')"
    otto_text "curl ${NC}: $(curl --version | head -n 1 | awk '{print $2}')"
    otto_text "Net-Tools ${NC}: $(ifconfig --version | head -n 1 | awk '{print $2}')"
    otto_text "Nmap ${NC}: $(nmap --version | head -n 1 | awk '{print $3}' | cut -d'(' -f1)"
    otto_text "Brave ${NC}: $(brave-browser --version)"


    # Git Configuration
    otto_title "Configuring Git ${NC}..."
    otto_text "LINK: [ https://github.com/login ]"
    otto_prompt "Enter your Git USER EMAIL:" git_user_email
    otto_prompt "Enter your Git USER NAME:" git_user_name
    otto_text "Configuring Git User..."
    git config --global user.email "$git_user_email"
    git config --global user.name "$git_user_name"
    git config --global init.defaultBranch master
    git init
    git branch -m master
    git add .
    git commit -m "Initialize OTTO-Stack-Deployer™️ v 0.11.0"
    otto_text "Git ${NC}: $(git --version | awk '{print $3}')"
    otto_success "Git Installed!"

    # Install Ollama
    otto_title "Installing Ollama ${NC} ..."
    if ! otto_check_command_exists ollama; then
        curl -fsSL https://ollama.com/install.sh | sudo -E bash -
    fi
    otto_text "Ollama ${NC}: $(ollama -v 2>&1)"
    otto_success "Ollama Installed!"


    # Start Ollama service if not running
    if ! pgrep -x "ollama" > /dev/null; then
        otto_log "Starting Ollama service..."
        nohup ollama serve &
        sleep 5
        if ! pgrep -x "ollama" > /dev/null; then
            otto_error "Failed to start Ollama service. Exiting."
            exit 1
        else
            otto_success "Ollama service started successfully."
        fi
    else
        otto_success "Ollama service is already running."
    fi


# Install Docker
otto_title "Installing Docker ${NC}..."
if ! otto_check_command_exists docker; then
    sudo apt-get install -y docker.io
    otto_apt_lock
    sudo service docker start
    sudo service docker enable
fi
otto_text "Docker ${NC}: $(docker -v)"
otto_success "Docker 🐋 Installed"

# Manage Docker Group
USER_NAME=$(whoami)  # Use the current logged-in user

echo "USER_NAME is set to: $USER_NAME"

if id "$USER_NAME" &>/dev/null; then
    if groups "$USER_NAME" | grep &>/dev/null '\bdocker\b'; then
        otto_success "User $USER_NAME is already in the Docker group."
    else
        otto_error "User $USER_NAME is not in the Docker group. Adding user to the Docker group."
        sudo usermod -aG docker "$USER_NAME"
        otto_success "User $USER_NAME added to the Docker group. Please log out and log back in to apply the changes."
        # Optional: Notify the user to log out and back in
        echo "You need to log out and log back in for the group changes to take effect."
    fi
else
    otto_error "User $USER_NAME does not exist."
    exit 1
fi

    # Cleanup
    otto_title  "Cleaning up unused packages..."
    sudo apt-get autoremove -y
    otto_success "Cleanup completed!"

}

### STACK CONFIGURATION

declare -A stacks=(
    [1,desc]="FastAPI + Next.js + PostgreSQL"
    [1,details]="A modern Python backend with a popular React frontend."
    [1,backend]="FastAPI"
    [1,frontend]="Next.js"
    [1,db]="PostgreSQL"
    [1,repo]="https://github.com/tiangolo/full-stack-fastapi-postgresql.git"
    [1,frontend_port]=3000
    [1,backend_port]=8000
    [1,db_port]=5432

    [2,desc]="Django + React + PostgreSQL"
    [2,details]="A traditional Python backend with React frontend."
    [2,backend]="Django"
    [2,frontend]="React"
    [2,db]="PostgreSQL"
    [2,repo]="https://github.com/cookiecutter/cookiecutter-django.git"
    [2,frontend_port]=3000
    [2,backend_port]=8000
    [2,db_port]=5432

    [3,desc]="Express.js + React + MongoDB"
    [3,details]="A Node.js backend with a React frontend, using MongoDB."
    [3,backend]="Express.js"
    [3,frontend]="React"
    [3,db]="MongoDB"
    [3,repo]="https://github.com/w3cj/express-react-mongo-boilerplate.git"
    [3,frontend_port]=3000
    [3,backend_port]=5000
    [3,db_port]=27017

    [4,desc]="Flask + Vue.js + MySQL"
    [4,details]="A lightweight Python backend with a Vue.js frontend."
    [4,backend]="Flask"
    [4,frontend]="Vue.js"
    [4,db]="MySQL"
    [4,repo]="https://github.com/cookiecutter-flask/cookiecutter-flask.git"
    [4,frontend_port]=8080
    [4,backend_port]=5000
    [4,db_port]=3306

    [5,desc]="Node.js + Angular + PostgreSQL"
    [5,details]="A full-stack JavaScript solution with Angular frontend."
    [5,backend]="Node.js"
    [5,frontend]="Angular"
    [5,db]="PostgreSQL"
    [5,repo]="https://github.com/sahat/hackathon-starter.git"
    [5,frontend_port]=4200
    [5,backend_port]=3000
    [5,db_port]=5432

    [6,desc]="thirdweb + React + PostgreSQL"
    [6,details]="A blockchain-ready backend with React frontend."
    [6,backend]="thirdweb"
    [6,frontend]="React"
    [6,db]="PostgreSQL"
    [6,repo]="https://github.com/thirdweb-example/next.js-templates.git"
    [6,frontend_port]=3000
    [6,backend_port]=5000
    [6,db_port]=5432

    [7,desc]="SvelteKit + Node.js + MongoDB"
    [7,details]="A cutting-edge frontend framework with a Node.js backend."
    [7,backend]="Node.js"
    [7,frontend]="SvelteKit"
    [7,db]="MongoDB"
    [7,repo]="https://github.com/sveltejs/template.git"
    [7,frontend_port]=3000
    [7,backend_port]=5000
    [7,db_port]=27017

    [8,desc]="Nuxt.js + Laravel + MySQL"
    [8,details]="A Vue.js framework with a PHP backend."
    [8,backend]="Laravel"
    [8,frontend]="Nuxt.js"
    [8,db]="MySQL"
    [8,repo]="https://github.com/cretueusebiu/laravel-nuxt.git"
    [8,frontend_port]=3000
    [8,backend_port]=8000
    [8,db_port]=3306

    [9,desc]="Ruby on Rails + Vue.js + PostgreSQL"
    [9,details]="A mature Ruby backend with a Vue.js frontend."
    [9,backend]="Ruby on Rails"
    [9,frontend]="Vue.js"
    [9,db]="PostgreSQL"
    [9,repo]="https://github.com/rails/webpacker.git"
    [9,frontend_port]=3000
    [9,backend_port]=3000
    [9,db_port]=5432
    
    [10,desc]="Spring Boot + Thymeleaf + MySQL"
    [10,details]="A Java backend with a templating engine."
    [10,backend]="Spring Boot"
    [10,frontend]="Thymeleaf"
    [10,db]="MySQL"
    [10,repo]="https://github.com/spring-guides/gs-spring-boot.git"
    [10,frontend_port]=8080
    [10,backend_port]=8080
    [10,db_port]=3306
)

otto_configure_stack() {
    STACK_CHOICE=$1
    BACKEND_FRAMEWORK="${stacks[$STACK_CHOICE,backend]}"
    FRONTEND_FRAMEWORK="${stacks[$STACK_CHOICE,frontend]}"
    DATABASE="${stacks[$STACK_CHOICE,db]}"
    git_repo="${stacks[$STACK_CHOICE,repo]}"
    frontend_port="${stacks[$STACK_CHOICE,frontend_port]}"
    backend_port="${stacks[$STACK_CHOICE,backend_port]}"
    db_port="${stacks[$STACK_CHOICE,db_port]}"
    grafana_port=3003
    prometheus_port=9090
    ollama_port=11434
}

otto_install_tool() {
    local tool_name=$1
    local install_command=$2
    if ! otto_check_command_exists $tool_name; then
        otto_log "Installing $tool_name..."
        eval $install_command
    else
        otto_success "$tool_name is already installed."
    fi
}

otto_get_project_details() {

    otto_title "Stack Details"

    otto_menu "Select a Stack:"
    for i in {1..10}; do
        printf "${CYAN}${BOLD}%2d) %-35s %s${NC}\n" "$i" "${stacks[$i,desc]}" "${stacks[$i,details]}"
    done
    while true; do
        otto_prompt "Enter the number of your chosen stack:" STACK_CHOICE
        otto_validate_numeric $STACK_CHOICE
        if [[ $STACK_CHOICE -ge 1 && $STACK_CHOICE -le 10 ]]; then
            otto_configure_stack $STACK_CHOICE
            break
        else
            otto_error "Invalid choice. Please select a valid option."
        fi
    done

    otto_title "Deployment Configuration"
    otto_menu "Select a Deployment Service:" \
        "1) Vercel" \
        "2) AWS" \
        "3) Netlify" \
        "4) Custom"
    otto_prompt "Enter the number corresponding to your deployment service:" DEPLOYMENT_SERVICE_CHOICE
    case $DEPLOYMENT_SERVICE_CHOICE in
        1) DEPLOYMENT_SERVICE="vercel" ; otto_install_tool "vercel" "npm install -g vercel";;
        2) DEPLOYMENT_SERVICE="aws" ; otto_install_tool "aws" "curl \"https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip\" -o \"awscliv2.zip\" && unzip awscliv2.zip && sudo ./aws/install";;
        3) DEPLOYMENT_SERVICE="netlify" ; otto_install_tool "netlify" "npm install -g netlify-cli";;
        4) DEPLOYMENT_SERVICE="custom" ; otto_log "No specific deployment tools to install for custom deployment.";;
        *) otto_error "Invalid choice. Please select a valid option."; otto_get_project_details ;;
    esac

    otto_title "Stack Configuration"
    otto_prompt "Enter the port for Frontend" frontend_port $frontend_port
    otto_prompt "Enter the port for Backend" backend_port $backend_port
    otto_prompt "Enter the port for Database" db_port $db_port
    otto_prompt "Enter the port for Grafana" grafana_port $grafana_port
    otto_prompt "Enter the port for Prometheus" prometheus_port $prometheus_port
    otto_prompt "Enter the port for Ollama" ollama_port $ollama_port
    otto_prompt "Enter the project name" PROJECT_NAME "my-fullstack-app"
    otto_prompt "Enter the backend API URL" BACKEND_URL "http://localhost:$backend_port"
    otto_prompt "Enter the database username" DB_USER "admin"
    otto_prompt "Enter the database password" DB_PASS "password"
    otto_prompt "Enter the database name" DB_NAME "myapp_db"
    otto_prompt "Enter the project name" DEPLOYER_PROJECT_NAME "$PROJECT_NAME"
    otto_prompt "Enter the admin username for backend" ADMIN_USER "admin"
    otto_prompt "Enter the admin password for backend" ADMIN_PASS "adminpass"
    otto_prompt "Enter the admin email for backend" ADMIN_EMAIL "admin@example.com"

    otto_title "Project Details"
    otto_text "Project Name: $PROJECT_NAME"
    otto_text "Backend URL: $BACKEND_URL"
    otto_text "Database Username: $DB_USER"
    otto_text "Database Password: ********"
    otto_text "Database Name: $DB_NAME"
    otto_text "Deployer Project Name: $DEPLOYER_PROJECT_NAME"
    otto_text "Admin Username: $ADMIN_USER"
    otto_text "Admin Password: ********"
    otto_text "Admin Email: $ADMIN_EMAIL"
    otto_text "Frontend Port: $frontend_port"
    otto_text "Backend Port: $backend_port"
    otto_text "Database Port: $db_port"
    otto_text "Grafana Port: $grafana_port"
    otto_text "Prometheus Port: $prometheus_port"
    otto_text "Ollama Port: $ollama_port"
    otto_text "Deployment Service: $DEPLOYMENT_SERVICE"

    otto_prompt "Please confirm your input is correct? (y/n)" CONFIRM "y"
    if [[ "$CONFIRM" != "y" && "$CONFIRM" != "Y" ]]; then
        otto_error "Setup canceled by the user."
        otto_get_project_details
    fi
}





### PROJECT SETUP

otto_setup_project_environment() {
    otto_title "Setting Up Project Environment"
    otto_log "Cloning the selected boilerplate repository..."
    git clone $git_repo "$PROJECT_NAME" || { otto_error "Failed to clone the repository."; exit 1; }
    cd "$PROJECT_NAME" || { otto_error "Failed to change directory to $PROJECT_NAME"; exit 1; }
    otto_log "Creating the .env file..."
    otto_create_env_file
    otto_log "Installing project dependencies..."
    otto_install_dependencies
    otto_log "Running backend tests..."
    otto_run_backend_tests

    # Ensure Docker is active before attempting to build images
    otto_log "Checking Docker service status..."
    if ! pgrep -x "dockerd" > /dev/null; then
        otto_log "Docker service is not active. Attempting to start..."
        sudo service docker start || sudo dockerd &
        sleep 5  # Give Docker a few seconds to initialize
        if ! pgrep -x "dockerd" > /dev/null; then
            otto_error "Failed to start Docker service. Please check the system configuration."
            exit 1
        fi
        otto_success "Docker service started successfully."
    fi


    otto_log "Building Docker images..."
    docker-compose -p "$PROJECT_NAME" build || { otto_error "Failed to build Docker images."; exit 1; }
    otto_log "Running Docker Compose services..."
    docker-compose -p "$PROJECT_NAME" up -d --force-recreate || { otto_error "Failed to start Docker Compose services."; exit 1; }
    otto_check_services
}


### ENVIRONMENT SETUP

otto_create_env_file() {
    otto_set_env "PROJECT_NAME" "$PROJECT_NAME"
    otto_set_env "BACKEND_URL" "$BACKEND_URL"
    otto_set_env "DB_USER" "$DB_USER"
    otto_set_env "DB_PASS" "$DB_PASS"
    otto_set_env "DB_NAME" "$DB_NAME"
    otto_set_env "FRONTEND_PORT" "$frontend_port"
    otto_set_env "BACKEND_PORT" "$backend_port"
    otto_set_env "DB_PORT" "$db_port"
    otto_set_env "GRAFANA_PORT" "$grafana_port"
    otto_set_env "PROMETHEUS_PORT" "$prometheus_port"
    otto_set_env "OLLAMA_PORT" "$ollama_port"
    otto_set_env "DEPLOYER_PROJECT_NAME" "$DEPLOYER_PROJECT_NAME"
    otto_set_env "ADMIN_USER" "$ADMIN_USER"
    otto_set_env "ADMIN_PASS" "$ADMIN_PASS"
    otto_set_env "ADMIN_EMAIL" "$ADMIN_EMAIL"
    echo ".env" >> .gitignore
}

### INSTALL DEPENDENCIES

otto_install_dependencies() {
    case $STACK_CHOICE in
        1|2|6)
            if [ ! -d "venv" ]; then
                python3 -m venv venv || { otto_error "Failed to create a virtual environment."; exit 1; }
            fi
            source venv/bin/activate
            if [ ! -f "requirements.txt" ]; then
                otto_log "Creating requirements.txt file..."
                cat <<EOL > requirements.txt
# Add your required packages here, e.g.:
# fastapi
# uvicorn[standard]
# psycopg2-binary
EOL
            fi
            pip install -r requirements.txt || { otto_error "Failed to install Python dependencies."; exit 1; }
            ;;
        3|7|9)
            if [ -f "package.json" ]; then
                npm install || { otto_error "Failed to install Node.js dependencies."; exit 1; }
            else
                otto_error "package.json file not found."
                exit 1
            fi
            ;;
        4|5|10)
            if [ -f "pom.xml" ]; then
                mvn install || { otto_error "Failed to install Maven dependencies."; exit 1; }
            else
                otto_error "pom.xml file not found."
                exit 1
            fi
            ;;
        8)
            if [ -f "composer.json" ]; then
                composer install || { otto_error "Failed to install Composer dependencies."; exit 1; }
            else
                otto_error "composer.json file not found."
                exit 1
            fi
            ;;
    esac
}

### BACKEND TESTING

otto_run_backend_tests() {
    case $STACK_CHOICE in
        1|2|6)
            if [ -d "backend/tests" ] && [ "$(ls -A backend/tests)" ]; then
                pytest backend/tests || { otto_error "Backend tests failed. Please check the test results."; exit 1; }
            else
                otto_log "No Python test files found. Skipping backend tests."
            fi
            ;;
        3|7|9)
            if [ -f "package.json" ] && grep -q '"test":' package.json; then
                npm test || { otto_error "Backend tests failed. Please check the test results."; exit 1; }
            else
                otto_log "No Node.js test scripts found. Skipping backend tests."
            fi
            ;;
        4|5|10)
            if [ -f "pom.xml" ]; then
                mvn test || { otto_error "Backend tests failed. Please check the test results."; exit 1; }
            else
                otto_log "No Maven test configuration found. Skipping backend tests."
            fi
            ;;
        8)
            if [ -f "phpunit.xml" ] || [ -f "phpunit.xml.dist" ]; then
                php artisan test || { otto_error "Backend tests failed. Please check the test results."; exit 1; }
            else
                otto_log "No PHP test configuration found. Skipping backend tests."
            fi
            ;;
    esac
}


### SERVICE LOGS

check_service_logs() {
    local service_name="${PROJECT_NAME}_$1_1"
    if [ "$(docker inspect -f '{{.State.Running}}' "$service_name" 2>/dev/null)" != "true" ]; then
        otto_error "$service_name is not running. Retrieving logs..."
        docker logs "$service_name" || otto_error "Failed to retrieve logs for $service_name. The container might not exist."
        otto_log "Attempting to restart $service_name..."
        docker-compose -p "$PROJECT_NAME" up -d "$1" || otto_error "Failed to start $service_name. Please check the configuration."
        sleep 5
        if [ "$(docker inspect -f '{{.State.Running}}' "$service_name" 2>/dev/null)" != "true" ]; then
            otto_error "Failed to start $service_name after retrying. Please check the logs."
            exit 1
        else
            otto_success "$service_name restarted successfully."
        fi
    else
        otto_success "$service_name is running."
    fi
}


### DOCKER COMPOSE CONFIGURATION

otto_create_docker_compose_file() {
    cat <<EOF > docker-compose.yml
version: '3.8'
services:
  frontend:
    image: frontend:latest
    ports:
      - "$frontend_port:80"

  backend:
    image: backend:latest
    ports:
      - "$backend_port:80"

  db:
    image: postgres:latest
    environment:
      POSTGRES_USER: $DB_USER
      POSTGRES_PASSWORD: $DB_PASS
      POSTGRES_DB: $DB_NAME
    ports:
      - "$db_port:5432"

  mailcatcher:
    image: mailcatcher/mailcatcher
    ports:
      - "1025:1025"
      - "1080:1080"

  proxy:
    image: traefik:v2.4
    ports:
      - "80:80"
      - "443:443"

  adminer:
    image: adminer
    ports:
      - "8080:8080"

EOF
}

otto_check_services() {
    check_service_logs backend
    check_service_logs frontend
    check_service_logs db
}

### MONITORING AND LOGGING                                 

otto_setup_monitoring() {
    otto_log "Setting up Prometheus and Grafana for monitoring..."
    otto_create_monitoring_compose_file
    otto_create_prometheus_config
    docker-compose -f docker-compose-monitoring.yml up -d || { otto_error "Failed to start Prometheus and Grafana services."; exit 1; }
    otto_success "Prometheus and Grafana are now running. Access Grafana at http://localhost:$grafana_port."
}

otto_create_monitoring_compose_file() {
    cat <<EOF > docker-compose-monitoring.yml
version: '3.8'
services:
  prometheus:
    image: prom/prometheus
    ports:
      - "$prometheus_port:9090"
    volumes:
      - ./prometheus.yml:/etc/prometheus/prometheus.yml
  grafana:
    image: grafana/grafana
    ports:
      - "$grafana_port:3003"
EOF
}

otto_create_prometheus_config() {
    cat <<EOF > prometheus.yml
global:
  scrape_interval: 15s
scrape_configs:
  - job_name: 'prometheus'
    static_configs:
      - targets: ['localhost:$prometheus_port']
  - job_name: 'docker'
    static_configs:
      - targets: ['docker.for.mac.localhost:9323']
EOF
}

### SSL/TLS SETUP

otto_setup_ssl_tls() {
    if otto_check_command_exists certbot; then
        otto_log "Setting up SSL/TLS using Let's Encrypt..."
        otto_install_nginx
        otto_configure_nginx
        otto_success "SSL/TLS setup complete. Your site is now secured."
    fi
}

otto_install_nginx() {
    if ! otto_check_command_exists nginx; then
        sudo apt-get install -y nginx
    fi
}

otto_generate_self_signed_certificate() {
    otto_log "Generating a self-signed SSL certificate..."
    sudo openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
        -keyout /etc/nginx/self-signed.key \
        -out /etc/nginx/self-signed.crt \
        -subj "/CN=localhost" || { otto_error "Failed to generate self-signed certificate."; exit 1; }
    otto_success "Self-signed SSL certificate generated."
}

otto_configure_nginx() {
    local domain_name=$(echo "$BACKEND_URL" | sed 's~http[s]*://~~g')

    # Remove existing symbolic link if it exists
    if [ -L /etc/nginx/sites-enabled/${PROJECT_NAME} ]; then
        sudo rm /etc/nginx/sites-enabled/${PROJECT_NAME}
    fi

    # Create the NGINX configuration file
    sudo bash -c "cat <<'EOF' > /etc/nginx/sites-available/${PROJECT_NAME}
server {
    listen 80;
    server_name $domain_name;

    location / {
        proxy_pass http://localhost:$frontend_port;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}

server {
    listen 443 ssl;
    server_name $domain_name;

    ssl_certificate /etc/nginx/self-signed.crt;
    ssl_certificate_key /etc/nginx/self-signed.key;
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_prefer_server_ciphers on;
    ssl_ciphers HIGH:!aNULL:!MD5;
    ssl_session_cache shared:SSL:10m;
    ssl_session_timeout 10m;
    ssl_stapling off;

    location / {
        proxy_pass http://localhost:$frontend_port;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}
EOF"

    # Create a symbolic link in sites-enabled
    sudo ln -s /etc/nginx/sites-available/${PROJECT_NAME} /etc/nginx/sites-enabled/

    # Test the NGINX configuration for syntax errors
    sudo nginx -t || { otto_error "NGINX configuration test failed."; exit 1; }
    
    # Restart NGINX only if the configuration is valid
    sudo service nginx reload || sudo /etc/init.d/nginx reload || otto_error "Failed to reload NGINX."
}



### LAUNCH PROJECT

otto_start() {

    # Start Docker containers

    docker-compose up -d
    sleep 5

    # Frontend
    brave-browser "http://localhost:$frontend_port" &
    # Backend
    brave-browser "http://localhost:$backend_port" &
    # Database
    brave-browser "http://localhost:$db_port" &
    # Grafana
    brave-browser "http://localhost:$grafana_port" &
    # Prometheus
    brave-browser "http://localhost:$prometheus_port" &
    # Proxy
    brave-browser "http://localhost:80" &
    # MailCatcher SMTP server
    brave-browser "http://localhost:1025" &
    # MailCatcher Web Interface
    brave-browser "http://localhost:1080" &
    # NGINX (assuming you might want to test it via HTTP)
    brave-browser "http://localhost:80" &
    # Ollama Backend - main interface for Ollama services
    brave-browser "http://localhost:11434" &
    
    # Mistral Services - ensure these services are correctly configured and running:
    # - CLI interface
    brave-browser "http://localhost:8080/cli" &
    # - Main Mistral service
    brave-browser "http://localhost:8081" &
    # - Web Interface
    brave-browser "http://localhost:8082" &
    # - API Interface
    brave-browser "http://localhost:8083" &
    # - RPC Interface
    brave-browser "http://localhost:8084" &
    # - Event Bus Interface
    brave-browser "http://localhost:8085" &
    # - RabbitMQ Interface
    brave-browser "http://localhost:15672" &

    # Wait for all services to start before continuing
    sleep 5

    otto_log "Docker containers started."
    otto_log "Please wait a few moments for all services to start."
    otto_log "Access the following URLs in your web browser:"
    otto_log "Frontend: http://localhost:$frontend_port"
    otto_log "Backend: http://localhost:$backend_port"
    otto_log "Database: http://localhost:$db_port"
    otto_log "Grafana: http://localhost:$grafana_port"
    otto_log "Prometheus: http://localhost:$prometheus_port"
    otto_log "Proxy: http://localhost:80"
    otto_log "MailCatcher SMTP server: http://localhost:1025"
    otto_log "MailCatcher Web Interface: http://localhost:1080"
    otto_log "Ollama Backend: http://localhost:11434"
    otto_log "Mistral Services CLI: http://localhost:8080/cli"
    otto_log "Mistral Services Main: http://localhost:8081"
    otto_log "Mistral Services Web Interface: http://localhost:8082"
    otto_log "Mistral Services API Interface: http://localhost:8083"
    otto_log "Mistral Services RPC Interface: http://localhost:8084"
    otto_log "Mistral Services Event Bus Interface: http://localhost:8085"
    otto_log "Mistral Services RabbitMQ Interface: http://localhost:15672"


    # Start tmux session for monitoring logs and services
    tmux new-session -d -s "$PROJECT_NAME-session"
    tmux split-window -v "$PROJECT_NAME-session" -n "Backend" "docker logs -f ${PROJECT_NAME}_backend_1"
    tmux split-window -v "$PROJECT_NAME-session" -n "Frontend" "docker logs -f ${PROJECT_NAME}_frontend_1"
    tmux split-window -v "$PROJECT_NAME-session" -n "Database" "docker logs -f ${PROJECT_NAME}_db_1"
    tmux split-window -v "$PROJECT_NAME-session" -n "Mistral" "ollama pull mistral; clear; ollama run mistral"
    tmux attach-session -t "$PROJECT_NAME-session"
    
    otto_success "Full-stack application setup complete!"
}


otto_stop() {
    docker-compose down
    otto_success "Docker containers stopped."
    exit 0
}


### MAIN SCRIPT EXECUTION

otto_main() {
    otto_clear
    otto_update
    otto_system_info
    otto_install_essentials
    otto_get_project_details
    otto_create_docker_compose_file
    otto_setup_project_environment
    otto_setup_monitoring
    otto_generate_self_signed_certificate
    otto_configure_nginx
    otto_start
    otto_stop
}

otto_main