/*
 * Licensed under the Apache License, Version 2.0 (http://www.apache.org/licenses/LICENSE-2.0)
 * See https://github.com/opennetty/opennetty-core for more information concerning
 * the license and the contributors participating to this project.
 */

using System.Globalization;
using MQTTnet.Client;

namespace OpenNetty.Mqtt;

/// <summary>
/// Provides various settings needed to configure the OpenNetty MQTT services.
/// </summary>
public sealed class OpenNettyMqttOptions
{
    /// <summary>
    /// Gets or sets the MQTT client options.
    /// </summary>
    public MqttClientOptions? ClientOptions { get; set; }

    /// <summary>
    /// Gets or sets a boolean indicating whether Home Assistant discovery is enabled.
    /// </summary>
    public bool DisableHomeAssistantDiscovery { get; set; }

    /// <summary>
    /// Gets or sets the UI culture to use in the user-visible strings
    /// (e.g device identities) included in the MQTT discovery payloads.
    /// </summary>
    public CultureInfo HomeAssistantDiscoveryUICulture { get; set; } = default!;

    /// <summary>
    /// Gets or sets the MQTT discovery root topic (by default, "homeassistant").
    /// </summary>
    public string HomeAssistantDiscoveryRootTopic { get; set; } = default!;

    /// <summary>
    /// Gets or sets the MQTT root topic (by default, "opennetty").
    /// </summary>
    public string RootTopic { get; set; } = default!;

    /// <summary>
    /// Gets or sets the delay in seconds before retrying when no response
    /// is received during a discovery scan (by default, 2 seconds).
    /// </summary>
    public int ScanRetryNoResponseDelay { get; set; } = 2;

    /// <summary>
    /// Gets or sets the delay in seconds before retrying after an error
    /// during a discovery scan (by default, 3 seconds).
    /// </summary>
    public int ScanRetryErrorDelay { get; set; } = 3;

    /// <summary>
    /// Gets or sets the delay in milliseconds between querying each device
    /// during a discovery scan (by default, 1000 milliseconds).
    /// </summary>
    public int ScanInterDeviceDelay { get; set; } = 1000;

    /// <summary>
    /// Gets or sets the timeout in seconds for waiting for a product info
    /// response during a discovery scan (by default, 5 seconds).
    /// </summary>
    public int ScanQueryTimeout { get; set; } = 5;
}
