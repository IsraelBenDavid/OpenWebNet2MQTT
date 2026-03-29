ARG BUILD_FROM=ghcr.io/home-assistant/amd64-base:latest
FROM mcr.microsoft.com/dotnet/nightly/sdk:10.0 AS build

WORKDIR /src

# Clone the repository source
RUN apt-get update && \
    apt-get install -y --no-install-recommends git && \
    rm -rf /var/lib/apt/lists/* && \
    git clone --depth 1 --branch HA-addon \
        https://github.com/IsraelBenDavid/opennetty-core.git .

# Restore dependencies
RUN dotnet restore src/OpenNetty.Daemon/OpenNetty.Daemon.csproj

# Build and publish
RUN dotnet publish src/OpenNetty.Daemon/OpenNetty.Daemon.csproj \
    -c Release \
    -o /publish \
    --no-restore

# List what we got to debug
RUN echo "=== Build output ===" && \
    ls -laR /publish && \
    find /publish -type f -name "*daemon*" -o -name "*.dll"

# =============================================================================
# Runtime stage: use .NET runtime (smaller than SDK, includes runtime)
# =============================================================================
FROM mcr.microsoft.com/dotnet/nightly/runtime:10.0

# Install jq, python3, and venv
RUN apt-get update && \
    apt-get install -y --no-install-recommends jq python3 python3-pip python3-venv && \
    rm -rf /var/lib/apt/lists/*

# Create a virtual environment and install paho-mqtt
RUN python3 -m venv /opt/venv
ENV PATH="/opt/venv/bin:$PATH"
RUN pip3 install paho-mqtt

WORKDIR /app

# Copy published binaries and dependencies
COPY --from=build /publish .

# Copy the entry-point script and the persistence script
COPY run.sh /run.sh
COPY persist-devices.py /app/persist-devices.py

RUN chmod +x /run.sh && \
    chmod +x /app/persist-devices.py

CMD [ "sh", "/run.sh" ]
