package org.eclipse.edc.extension.scope;

import org.eclipse.edc.runtime.metamodel.annotation.Extension;
import org.eclipse.edc.spi.system.ServiceExtension;
import org.eclipse.edc.spi.system.ServiceExtensionContext;
import org.eclipse.edc.token.spi.TokenDecorator;
import org.eclipse.edc.util.string.StringUtils;

import static org.eclipse.edc.jwt.spi.JwtRegisteredClaimNames.SCOPE;

/**
 * Registers a TokenDecorator that ensures outbound DSP requests always carry a scope claim.
 */
@Extension(value = DefaultScopeExtension.NAME)
public class DefaultScopeExtension implements ServiceExtension {

    public static final String NAME = "Default DSP Scope Extension";
    private static final String DEFAULT_SCOPE_SETTING = "edc.iam.dsp.scope.default";

    @Override
    public String name() {
        return NAME;
    }

    @Override
    public void initialize(ServiceExtensionContext context) {
        var monitor = context.getMonitor();
        var configuredScopes = context.getConfig().getString(DEFAULT_SCOPE_SETTING, null);
    monitor.info("Default DSP scope raw configuration: '" + configuredScopes + "'");
        if (StringUtils.isNullOrBlank(configuredScopes)) {
            monitor.info("No default DSP scope configured; skipping scope decorator registration.");
            return;
        }

        var normalizedScopes = configuredScopes.replace(',', ' ').trim().replaceAll("\\s+", " ");
        if (normalizedScopes.isEmpty()) {
            monitor.debug("Default DSP scope configuration resolves to empty after normalization; skipping decorator registration.");
            return;
        }

        TokenDecorator decorator = builder -> {
            var currentScope = builder.build().getStringClaim(SCOPE);
            if (StringUtils.isNullOrBlank(currentScope)) {
                builder.claims(SCOPE, normalizedScopes);
            }
            return builder;
        };

        context.registerService(TokenDecorator.class, decorator);

        monitor.info("Registered default DSP scope decorator with scope(s): " + normalizedScopes);
    }
}
