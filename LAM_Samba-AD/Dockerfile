FROM ubuntu:22.04

LABEL maintainer="Your Name <your.email@example.com>"
LABEL description="Combined Samba Active Directory Domain Controller with LDAP Account Manager"
LABEL version="1.0.0"

ENV DEBIAN_FRONTEND=noninteractive

# Add ondrej/php PPA for newer PHP versions (LAM requires PHP >= 8.1.10)
RUN apt-get update && \
    apt-get install -y software-properties-common && \
    add-apt-repository ppa:ondrej/php -y && \
    apt-get update

# Install Samba AD DC dependencies (from original nowsci/samba-domain)
RUN apt-get install -y \
        # Original Samba AD packages
        pkg-config \
        attr \
        acl \
        samba \
        smbclient \
        ldap-utils \
        winbind \
        libnss-winbind \
        libpam-winbind \
        krb5-user \
        krb5-kdc \
        supervisor \
        openvpn \
        inetutils-ping \
        ldb-tools \
        vim \
        curl \
        dnsutils \
        ntp \
        jq \
        # NEW: LAM Web Interface dependencies (PHP 8.1 from ondrej PPA)
        nginx \
        php8.1-fpm \
        php8.1-ldap \
        php8.1-xml \
        php8.1-zip \
        php8.1-mbstring \
        php8.1-gd \
        php8.1-curl \
        wget \
        unzip && \
    apt-get clean autoclean && \
    apt-get autoremove --yes && \
    rm -rf /var/lib/{apt,dpkg,cache,log}/ && \
    rm -fr /tmp/* /var/tmp/*

# Download and install LAM from official SourceForge
# Using SourceForge's latest release redirect
RUN wget --content-disposition -O /tmp/lam.tar.bz2 \
    "https://sourceforge.net/projects/lam/files/latest/download" && \
    mkdir -p /var/www/html && \
    tar -xjf /tmp/lam.tar.bz2 -C /var/www/html && \
    EXTRACTED_DIR=$(ls -d /var/www/html/ldap-account-manager-* 2>/dev/null | head -1) && \
    mv "$EXTRACTED_DIR" /var/www/html/lam && \
    chown -R www-data:www-data /var/www/html/lam && \
    chmod -R 755 /var/www/html/lam && \
    rm /tmp/lam.tar.bz2

# Create LAM config directory with proper permissions
RUN mkdir -p /var/lib/lam/config /var/lib/lam/sess && \
    chown -R www-data:www-data /var/lib/lam && \
    chmod -R 755 /var/lib/lam

# Configure PHP-FPM
RUN sed -i 's/;cgi.fix_pathinfo=1/cgi.fix_pathinfo=0/' /etc/php/8.1/fpm/php.ini && \
    sed -i 's/upload_max_filesize = 2M/upload_max_filesize = 10M/' /etc/php/8.1/fpm/php.ini && \
    sed -i 's/post_max_size = 8M/post_max_size = 10M/' /etc/php/8.1/fpm/php.ini && \
    sed -i 's/;date.timezone =/date.timezone = UTC/' /etc/php/8.1/fpm/php.ini

# Add nginx configuration for LAM
COPY nginx-lam.conf /etc/nginx/sites-available/lam
RUN rm -f /etc/nginx/sites-enabled/default && \
    ln -s /etc/nginx/sites-available/lam /etc/nginx/sites-enabled/lam

# Volumes for persistence
VOLUME ["/var/lib/samba", "/etc/samba/external", "/var/lib/lam/config"]

# Add initialization and management scripts
COPY init.sh /init.sh
COPY domain.sh /domain.sh
COPY lam-config.sh /lam-config.sh
RUN chmod 755 /init.sh /domain.sh /lam-config.sh

# Expose ports (documentation only - MACVLAN uses dedicated IP)
# Samba AD DC ports: 53, 88, 135, 137-139, 389, 445, 464, 636, 3268, 3269, 49152+
# LAM Web Interface: 8080
EXPOSE 53 88 135 137 138 139 389 445 464 636 3268 3269 8080

CMD ["/init.sh"]
