package org.eclipse.edc.extension.identity;

import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;

import org.eclipse.edc.runtime.metamodel.annotation.Extension;
import org.eclipse.edc.runtime.metamodel.annotation.Inject;
import org.eclipse.edc.runtime.metamodel.annotation.Setting;
import org.eclipse.edc.spi.monitor.Monitor;
import org.eclipse.edc.spi.system.ServiceExtension;
import org.eclipse.edc.spi.system.ServiceExtensionContext;
import org.eclipse.edc.web.spi.WebService;
import org.eclipse.edc.web.spi.configuration.ApiContext;

/**
 * Registers the {@link DidDocumentController} on the protocol API so that the connector's DID document
 * is resolvable via {@code http://<host>:<protocol-port>/.well-known/did.json}.
 */
@Extension(value = DidDocumentExtension.NAME)
public class DidDocumentExtension implements ServiceExtension {

    public static final String NAME = "Connector DID Document Extension";

    @Setting(value = "Absolute path to the DID document that should be published.", defaultValue = "/app/resources/identity/did.json")
    public static final String DID_DOCUMENT_PATH_SETTING = "edc.connector.did.document.path";

    @Inject
    private WebService webService;

    @Override
    public String name() {
        return NAME;
    }

    @Override
    public void initialize(ServiceExtensionContext context) {
        Monitor monitor = context.getMonitor();
        var documentPath = context.getSetting(DID_DOCUMENT_PATH_SETTING, "/app/resources/identity/did.json");
        var path = Path.of(documentPath);
        if (!Files.exists(path)) {
            monitor.warning("DID document not found at " + documentPath + "; skipping /.well-known endpoint registration.");
            return;
        }

        try {
            var documentJson = Files.readString(path, StandardCharsets.UTF_8);
            webService.registerResource(ApiContext.PROTOCOL, new DidDocumentController(documentJson));
            monitor.info("Published DID document from " + documentPath + " on the protocol API");
        } catch (IOException ex) {
            monitor.severe("Failed to read DID document from " + documentPath, ex);
        }
    }
}