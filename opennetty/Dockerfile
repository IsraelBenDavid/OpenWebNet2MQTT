ARG BUILD_FROM=ghcr.io/home-assistant/amd64-base:latest
FROM mcr.microsoft.com/dotnet/nightly/sdk:10.0 AS build

WORKDIR /src

# Clone the repository source
RUN apt-get update && \
    apt-get install -y --no-install-recommends git && \
    rm -rf /var/lib/apt/lists/* && \
    git clone --depth 1 --branch HA-addon \
        https://github.com/IsraelBenDavid/opennetty-core.git .

# Restore and publish as a self-contained single-file executable
# Note: We must detect the target architecture
RUN dotnet publish src/OpenNetty.Daemon/OpenNetty.Daemon.csproj \
    -c Release \
    -o /app \
    --self-contained true \
    -p:PublishSingleFile=true \
    -p:PublishTrimmed=true \
    -p:IncludeNativeLibrariesForSelfExtract=true && \
    # Make sure the binary exists and is executable
    ls -la /app/opennetty-daemon && \
    chmod +x /app/opennetty-daemon

# =============================================================================
# Runtime stage: use HA's base image (Alpine)
# =============================================================================
FROM ${BUILD_FROM}

# Install jq and runtime dependencies using apk (Alpine package manager)
RUN apk add --no-cache \
    jq \
    icu \
    openssl

WORKDIR /app
COPY --from=build /app/opennetty-daemon /app/opennetty-daemon
COPY --from=build /app/appsettings.json /app/appsettings.json

# Copy the entry-point script
COPY run.sh /run.sh
RUN chmod +x /run.sh

# Configure console logging for the Home Assistant log viewer
RUN echo '{ \
  "Logging": { \
    "LogLevel": { \
      "Default": "Information", \
      "OpenNetty": "Information" \
    }, \
    "Console": { \
      "FormatterName": "Simple", \
      "FormatterOptions": { \
        "SingleLine": true, \
        "TimestampFormat": "yyyy-MM-dd HH:mm:ss " \
      } \
    } \
  } \
}' > /app/appsettings.json

CMD [ "sh", "/run.sh" ]
