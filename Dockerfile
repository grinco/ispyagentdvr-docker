# Use latest ubuntu version with ffmpeg5
FROM ubuntu:22.10

# Download and install dependencies
RUN apt-get update \
    && apt-get install -y wget unzip software-properties-common alsa-utils

# Install libgdiplus, used for smart detection
RUN apt-get install -y libgdiplus

# Install ffmpeg
RUN apt-get install -y ffmpeg
    
# Install Time Zone
RUN apt-get install -y tzdata

# Install curl, used for calling external webservices in Commands
RUN apt-get install -y curl


#Define download location variables
ENV FILE_LOCATION="https://ispyfiles.azureedge.net/downloads/Agent_Linux64_4_7_2_0.zip"
ENV FILE_LOCATION_SET=${FILE_LOCATION:+true}
ENV DEFAULT_FILE_LOCATION="https://www.ispyconnect.com/api/Agent/DownloadLocation4?platform=Linux64&fromVersion=0"
ARG DEBIAN_FRONTEND=noninteractive
ARG TZ=America/Los_Angeles
ARG name

# Download/Install iSpy Agent DVR: 
# Detect the arch
RUN arch=$(dpkg --print-architecture) && \
   echo "Adjusting architecture to $arch" && \
   if [ "$arch" = "arm64" ]; then \
      DEFAULT_FILE_LOCATION=$(echo ${DEFAULT_FILE_LOCATION} | sed -e 's/Linux64/LinuxARM64/'); \
      FILE_LOCATION=$(echo ${FILE_LOCATION} | sed -e 's/Linux64/LinuxARM64/'); \
   fi &&\
   # Check if we were given a specific version
   if [ "${FILE_LOCATION_SET}" = "true" ]; then \
      echo "Downloading from specific location: ${FILE_LOCATION}" && \
      wget -c ${FILE_LOCATION} -O agent.zip; \
    else \
      #Get latest instead
      arch=$(dpkg --print-architecture) && \
      echo "Downloading latest" && \
      wget -c $(wget -qO- ${DEFAULT_FILE_LOCATION} | tr -d '"') -O agent.zip; \
    fi && \
    unzip agent.zip -d /agent && \
    rm agent.zip
    
# Clean up
RUN apt-get -y --purge remove unzip wget \ 
    && apt autoremove -y \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Docker needs to run a TURN server to get webrtc traffic to and from it over forwarded ports from the host
# These are the default ports. If the ports below are modified here you'll also need to set the ports in XML/Config.xml
# for example <TurnServerPort>3478</TurnServerPort><TurnServerMinPort>50000</TurnServerMinPort><TurnServerMaxPort>50010</TurnServerMaxPort>
# The main server port is overridden by creating a text file called port.txt in the root directory containing the port number, eg: 8090
# To access the UI you must use the local IP address of the host, NOT localhost - for example http://192.168.1.12:8090/

# Modify permission for execution
RUN echo "Adding executable permissions" && \
    chmod +x /agent/Agent && \
    chmod +x /agent/agent-register.sh && \
    chmod +x /agent/agent-reset.sh && \
    chmod +x /agent/agent-reset-local-login.sh

# Define default environment variables
ENV PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
# Fix a memory leak on encoded recording
ENV MALLOC_TRIM_THRESHOLD_=100000

# Main UI port
EXPOSE 8090

# STUN server port
EXPOSE 3478/udp

# TURN server UDP port range
EXPOSE 50000-50010/udp

# Data volumes
VOLUME ["/agent/Media/XML", "/agent/Media/WebServerRoot/Media", "/agent/Commands"]

# Define service entrypoint
CMD ["/agent/Agent"]
