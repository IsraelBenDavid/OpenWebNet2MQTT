ARG BUILD_FROM=debian:bookworm-slim

# =============================================================================
# Build stage: compile the .NET daemon from source
# =============================================================================
FROM mcr.microsoft.com/dotnet/nightly/sdk:10.0 AS build

WORKDIR /src

# Clone the repository source
RUN apt-get update && \
    apt-get install -y --no-install-recommends git && \
    rm -rf /var/lib/apt/lists/* && \
    git clone --depth 1 --branch HA-addon \
        https://github.com/IsraelBenDavid/opennetty-core.git .

# Restore and publish as a self-contained single-file executable
RUN dotnet publish src/OpenNetty.Daemon/OpenNetty.Daemon.csproj \
    -c Release \
    -o /app \
    --self-contained true \
    -r linux-$(case "$(uname -m)" in \
        x86_64)  echo "x64"   ;; \
        aarch64) echo "arm64" ;; \
        armv7l)  echo "arm"   ;; \
        *)       echo "x64"   ;; \
    esac)

# =============================================================================
# Runtime stage: minimal image with the compiled binary
# =============================================================================
FROM ${BUILD_FROM}

# Install only the native dependencies needed by .NET + jq for config generation
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        jq \
        libicu72 \
        libssl3 \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app
COPY --from=build /app .

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

CMD [ "/run.sh" ]
