package org.eclipse.edc.extension.protocol;

import org.eclipse.edc.runtime.metamodel.annotation.Extension;
import org.eclipse.edc.runtime.metamodel.annotation.Inject;
import org.eclipse.edc.runtime.metamodel.annotation.Provides;
import org.eclipse.edc.runtime.metamodel.annotation.Setting;
import org.eclipse.edc.runtime.metamodel.annotation.SettingContext;
import org.eclipse.edc.spi.protocol.ProtocolWebhook;
import org.eclipse.edc.spi.system.Hostname;
import org.eclipse.edc.spi.system.ServiceExtension;
import org.eclipse.edc.spi.system.ServiceExtensionContext;
import org.eclipse.edc.web.spi.WebServer;
import org.eclipse.edc.web.spi.configuration.ApiContext;
import org.eclipse.edc.web.spi.configuration.WebServiceConfigurer;
import org.eclipse.edc.web.spi.configuration.WebServiceSettings;

import static java.lang.String.format;

/**
 * Local protocol API configuration that ensures a ProtocolWebhook is available when the runtime boots.
 */
@Extension(value = ProtocolApiConfigurationExtension.NAME)
@Provides(ProtocolWebhook.class)
public class ProtocolApiConfigurationExtension implements ServiceExtension {

    public static final String NAME = "Embedded Protocol API Configuration";

    @Setting(value = "Configures endpoint for reaching the Protocol API.", defaultValue = "<hostname:protocol.port/protocol.path>")
    public static final String DSP_CALLBACK_ADDRESS = "edc.dsp.callback.address";

    @SettingContext("Protocol API context setting key")
    private static final String PROTOCOL_CONFIG_KEY = "web.http." + ApiContext.PROTOCOL;

    private static final WebServiceSettings SETTINGS = WebServiceSettings.Builder.newInstance()
            .apiConfigKey(PROTOCOL_CONFIG_KEY)
            .contextAlias(ApiContext.PROTOCOL)
            .defaultPath("/api/v1/dsp")
            .defaultPort(8282)
            .name("Protocol API")
            .build();

    @Inject
    private WebServer webServer;
    @Inject
    private WebServiceConfigurer configurator;
    @Inject
    private Hostname hostname;

    @Override
    public String name() {
        return NAME;
    }

    @Override
    public void initialize(ServiceExtensionContext context) {
        var contextConfig = context.getConfig(PROTOCOL_CONFIG_KEY);
        var apiConfiguration = configurator.configure(contextConfig, webServer, SETTINGS);
        var dspWebhookAddress = context.getSetting(DSP_CALLBACK_ADDRESS,
                format("http://%s:%s%s", hostname.get(), apiConfiguration.getPort(), apiConfiguration.getPath()));
        context.registerService(ProtocolWebhook.class, () -> dspWebhookAddress);
    }
}
