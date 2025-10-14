package org.eclipse.edc.extension.identity;

import jakarta.ws.rs.GET;
import jakarta.ws.rs.Path;
import jakarta.ws.rs.Produces;
import jakarta.ws.rs.core.MediaType;
import jakarta.ws.rs.core.Response;

/**
 * Simple JAX-RS resource that exposes the DID document under the ".well-known" path so that other
 * participants in the dataspace can resolve {@code did:web} identifiers pointing at this connector.
 */
@Path("/.well-known")
public class DidDocumentController {

    private final String documentJson;

    public DidDocumentController(String documentJson) {
        this.documentJson = documentJson;
    }

    @GET
    @Path("did.json")
    @Produces(MediaType.APPLICATION_JSON)
    public Response getDocument() {
        return Response.ok(documentJson).build();
    }
}