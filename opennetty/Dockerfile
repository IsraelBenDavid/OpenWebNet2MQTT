ARG BUILD_FROM
FROM mcr.microsoft.com/dotnet/sdk:10.0-preview AS build

RUN apt-get update && \
    apt-get install -y --no-install-recommends git && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /src

# Clone the repository source
RUN git clone --depth 1 --branch HA-addon \
    https://github.com/IsraelBenDavid/opennetty-core.git .

# Restore dependencies
RUN dotnet restore src/OpenNetty.Daemon/OpenNetty.Daemon.csproj

# Publish the daemon
RUN dotnet publish src/OpenNetty.Daemon/OpenNetty.Daemon.csproj \
    -c Release \
    -o /app \
    --no-restore

# Runtime image
FROM ${BUILD_FROM:-mcr.microsoft.com/dotnet/runtime:10.0-preview}

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        jq \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app
COPY --from=build /app .

# Copy the run script
COPY run.sh /run.sh
RUN chmod +x /run.sh

# Configure console logging for Home Assistant log viewer
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
