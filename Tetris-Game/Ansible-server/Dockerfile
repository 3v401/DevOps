# We use eclipse-temurin:17-jdk
# CentOS Stream 10 doesn’t provide
# “java-17-openjdk-devel” package in its repositories.
# 17-jdk required for running Clojure
FROM eclipse-temurin:17-jdk

LABEL maintainer="3v401"

# apache2: The web server that will serve the Tetris game
RUN apt-get update && apt-get install -y rlwrap git curl apache2 && apt-get clean

# Clojure is required to build tetris
RUN curl -O https://download.clojure.org/install/linux-install-1.11.1.1208.sh && \
    chmod +x linux-install-1.11.1.1208.sh && \
    ./linux-install-1.11.1.1208.sh && \
    rm linux-install-1.11.1.1208.sh

# Set working directory. From now on, Dockerfile will use this path as default.
# Before it was '/'
WORKDIR /var/www/html/

# Clone tetris game (clone will be at WORKDIR, if settled before, it would be in '/'
RUN git clone https://github.com/djblue/tetris.git

# Move the Tetris game files into the Apache web root directory
RUN mv tetris/* . && rm -rf tetris

# Build the game and generate `index.html`
# required to play the game in WORKDIR (step explained in README.md)
RUN clojure -M:app > index.html

# Ensure correct permissions (drwxr-xr-x)
RUN chmod -R 755 /var/www/html/

RUN echo "ServerName localhost" >> /etc/apache2/apache2.conf

# Start the Apache HTTP server in the foreground
# /usr/sbin/httpd = Starts the Apache web server inside the Docker container
# -D FOREGROUND = Keeps it running so the container doesn't stop
CMD ["apache2ctl", "-D", "FOREGROUND"]

# Expose port 3000
EXPOSE 3000
