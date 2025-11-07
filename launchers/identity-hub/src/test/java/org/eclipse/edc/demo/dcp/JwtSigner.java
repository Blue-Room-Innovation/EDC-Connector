/*
 *  Copyright (c) 2024 Metaform Systems, Inc.
 *
 *  This program and the accompanying materials are made available under the
 *  terms of the Apache License, Version 2.0 which is available at
 *  https://www.apache.org/licenses/LICENSE-2.0
 *
 *  SPDX-License-Identifier: Apache-2.0
 *
 *  Contributors:
 *       Metaform Systems, Inc. - initial API and implementation
 *
 */

package org.eclipse.edc.demo.dcp;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.nimbusds.jose.JOSEException;
import com.nimbusds.jose.JOSEObjectType;
import com.nimbusds.jose.JWSAlgorithm;
import com.nimbusds.jose.JWSHeader;
import com.nimbusds.jwt.JWTClaimsSet;
import com.nimbusds.jwt.SignedJWT;
import org.eclipse.edc.keys.keyparsers.PemParser;
import org.eclipse.edc.security.token.jwt.CryptoConverter;
import org.junit.jupiter.api.extension.ExtensionContext;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.Arguments;
import org.junit.jupiter.params.provider.ArgumentsProvider;
import org.junit.jupiter.params.provider.ArgumentsSource;

import java.io.File;
import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Paths;
import java.security.PrivateKey;
import java.time.Instant;
import java.util.Date;
import java.util.Map;
import java.util.stream.Stream;

import static org.mockito.Mockito.mock;

/**
 * Use this test to read a verifiable credential from the file system, and sign it with a given private key. You will need:
 * <ul>
 *     <li>A JSON file containing the VC</li>
 *     <li>A public/private key pair in either JWK or PEM format</li>
 * </ul>
 */
@SuppressWarnings("NewClassNamingConvention")
public class JwtSigner {

    private static final String USER_DIR = System.getProperty("user.dir");
    public static final String ISSUER_PRIVATE_KEY_FILE_PATH = USER_DIR + "/../../deployment/assets/private.pem";
    public static final String ISSUER_PUBLIC_KEY_FILE_PATH = USER_DIR + "/../../deployment/assets/public.pem";
    // No hay issuer DID document, así que lo omitimos en la prueba
    public static final String DATASPACE_ISSUER_DID_LOCAL = "did:web:identityhub";
    private final ObjectMapper mapper = new ObjectMapper();

    @ParameterizedTest
    @ArgumentsSource(InputOutputProvider.class)
    void generateJwt(String rawCredentialFilePath, File vcResource, String did, String issuerDid, File issuerDidDocument) throws JOSEException, IOException {
        var header = new JWSHeader.Builder(JWSAlgorithm.RS256)
                .keyID(issuerDid + "#key-1")
                .type(JOSEObjectType.JWT)
                .build();

        var credential = mapper.readValue(new File(rawCredentialFilePath), Map.class);

        var claims = new JWTClaimsSet.Builder()
                .audience(did)
                .subject(did)
                .issuer(issuerDid)
                .claim("vc", credential)
                .issueTime(Date.from(Instant.now()))
                .build();

        // Usar las claves presentes en assets
        var privateKey = (PrivateKey) new PemParser(mock()).parse(readFile(ISSUER_PRIVATE_KEY_FILE_PATH)).orElseThrow(f -> new RuntimeException(f.getFailureDetail()));

        // Firmar el JWT
        var jwt = new SignedJWT(header, claims);
        jwt.sign(CryptoConverter.createSignerFor(privateKey));

        // Actualizar el campo "rawVc" en el archivo de credencial
        var content = Files.readString(vcResource.toPath());
        var updatedContent = content.replaceFirst("\"rawVc\":.*,", "\"rawVc\": \"%s\",".formatted(jwt.serialize()));
        Files.write(vcResource.toPath(), updatedContent.getBytes());
        // No se actualiza issuer DID document porque no existe en assets
    }

    private String readFile(String path) {
        try {
            return Files.readString(Paths.get(path));
        } catch (IOException e) {
            throw new RuntimeException("Error leyendo archivo: " + path, e);
        }
    }

    private static class InputOutputProvider implements ArgumentsProvider {
        @Override
        public Stream<? extends Arguments> provideArguments(ExtensionContext extensionContext) {
            return Stream.of(
                Arguments.of(USER_DIR + "/../../deployment/assets/credentials/membership-credential.json",
                    new File(USER_DIR + "/../../deployment/assets/credentials/membership-credential.json"),
                    DATASPACE_ISSUER_DID_LOCAL, DATASPACE_ISSUER_DID_LOCAL, null),

                Arguments.of(USER_DIR + "/../../deployment/assets/credentials/dataprocessor-credential.json",
                    new File(USER_DIR + "/../../deployment/assets/credentials/dataprocessor-credential.json"),
                    DATASPACE_ISSUER_DID_LOCAL, DATASPACE_ISSUER_DID_LOCAL, null)
            );
        }
    }
}
