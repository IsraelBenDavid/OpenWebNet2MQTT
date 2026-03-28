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

# Install jq for config generation and python3 for device persistence
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        jq \
        python3 \
        python3-pip && \
    pip3 install paho-mqtt --break-system-packages && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Copy published binaries and dependencies
COPY --from=build /publish .

# Copy the entry-point script and persistence service
COPY run.sh /run.sh
COPY persist-devices.py /app/persist-devices.py
RUN chmod +x /run.sh /app/persist-devices.py

# Note: appsettings.json is now generated dynamically by run.sh
# based on the debug_logging configuration option

CMD [ "sh", "/run.sh" ]
