package org.eclipse.edc.extension.health;

import org.eclipse.edc.runtime.metamodel.annotation.Inject;
import org.eclipse.edc.spi.system.ServiceExtension;
import org.eclipse.edc.spi.system.ServiceExtensionContext;
import org.eclipse.edc.web.spi.WebService;

/**
 * Extension que registra el endpoint REST de health.
 */
public class HealthEndpointExtension implements ServiceExtension {

    @Inject
    private WebService webService;

    @Override
    public void initialize(ServiceExtensionContext context) {
        webService.registerResource(new HealthApiController(context.getMonitor()));
    }
}
