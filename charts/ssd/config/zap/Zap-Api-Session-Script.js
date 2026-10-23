// print("inside session management…");

/* 1 ─ extractWebSession: read Script parameters and stash into session */
function extractWebSession(sessionWrapper) {
    var params = sessionWrapper.getParam;
    var sess = sessionWrapper.getSession();

    // Read & normalize script parameters
    var auth_type = params("auth_type") || "none";
    var http_scheme = (params("http_scheme") || "").toLowerCase();
    var http_user = params("http_user") || "";
    var http_pass = params("http_pass") || "";
    var token = params("token") || "";
    var key_in = (params("key_in") || "header").toLowerCase();
    var key_name = params("key_name") || "X-API-Key";

    var defaultHeader = params("headerDefault") || "X-API-Key";
    var defaultQuery = params("queryDefault") || "api_key";
    var defaultCookie = params("cookieDefault") || "api_key";

    // Fallback for blank key_name
    key_name = key_name || (
        key_in === "query" ? defaultQuery :
        key_in === "cookie" ? defaultCookie :
        defaultHeader
    );

    // Store everything in the Session
    sess.setValue("auth_type", auth_type);
    sess.setValue("http_scheme", http_scheme);
    sess.setValue("http_user", http_user);
    sess.setValue("http_pass", http_pass);
    sess.setValue("token", token);
    sess.setValue("key_in", key_in);
    sess.setValue("key_name", key_name);
    sess.setValue("defaultHeader", defaultHeader);
    sess.setValue("defaultQuery", defaultQuery);
    sess.setValue("defaultCookie", defaultCookie);

    // Debug
    // print("auth_type   = " + auth_type);
    // print("http_scheme = " + http_scheme);
    // print("key_in      = " + key_in);
    // print("key_name    = " + key_name);
}

/* 2 ─ processMessageToMatchSession: inject creds on every request */
function processMessageToMatchSession(sessionWrapper) {
    var msg = sessionWrapper.getHttpMessage();
    var sess = sessionWrapper.getSession();

    var auth_type = sess.getValue("auth_type");
    // print("authType: " + auth_type);

    switch (auth_type) {
        case "http":
            var scheme = sess.getValue("http_scheme");
            // print("scheme: " + scheme);

            if (scheme === "basic") {
                var raw = sess.getValue("http_user") + ":" + sess.getValue("http_pass");
                var enc = java.util.Base64.getEncoder()
                    .encodeToString(new java.lang.String(raw).getBytes());

                msg.getRequestHeader().setHeader("Authorization", "Basic " + enc);

            } else if (scheme === "bearer") {
                // print("bearer: " + sess.getValue("token"));
                msg.getRequestHeader().setHeader(
                    "Authorization",
                    "Bearer " + sess.getValue("token")
                );
            }
            break;

        case "apiKey":
            // print("apikey name: " + sess.getValue("key_name"));
            // print("apikey in  : " + sess.getValue("key_in"));
            // print("apikey     : " + sess.getValue("token"));

            switch (sess.getValue("key_in")) {

                case "header":
                    msg.getRequestHeader().setHeader(
                        sess.getValue("key_name"),
                        sess.getValue("token")
                    );
                    break;

                case "cookie":
                    var ck = msg.getRequestHeader().getHeader("Cookie");
                    var nv = sess.getValue("key_name") + "=" + sess.getValue("token");

                    ck = ck ? ck + "; " + nv : nv;

                    msg.getRequestHeader().setHeader("Cookie", ck);
                    break;

                case "query":
                    var uri = msg.getRequestHeader().getURI();
                    var q = uri.getEscapedQuery();

                    var keyEsc = encodeURIComponent(sess.getValue("key_name"));
                    var tokenEsc = encodeURIComponent(sess.getValue("token"));

                    if (q) {
                        var re = new RegExp("(^|&)" + keyEsc + "=[^&]*");

                        q = q.replace(re, "").replace(/^&/, "");
                    }

                    q = (q ? q + "&" : "") + keyEsc + "=" + tokenEsc;

                    uri.setEscapedQuery(q);
                    break;
            }
            break;

        default:
        /* no auth */
    }
}

/* 3 ─ clearWebSessionIdentifiers: scrub when ZAP clones a request */
function clearWebSessionIdentifiers(sessionWrapper) {
    var msg = sessionWrapper.getHttpMessage();
    var sess = sessionWrapper.getSession();

    var defaultHeader = sess.getValue("defaultHeader");
    var defaultQuery = sess.getValue("defaultQuery");
    var defaultCookie = sess.getValue("defaultCookie");

    // Remove Authorization/header
    msg.getRequestHeader().setHeader("Authorization", null);
    msg.getRequestHeader().setHeader(defaultHeader, null);

    // Remove cookie
    var ck = msg.getRequestHeader().getHeader("Cookie");

    if (ck) {
        var reC = new RegExp(
            "(^|;\\s*)" + defaultCookie + "=[^;]*;?\\s*"
        );

        ck = ck.replace(reC, "").trim();

        msg.getRequestHeader().setHeader("Cookie", ck || null);
    }

    // Remove query param
    var uri = msg.getRequestHeader().getURI();
    var q = uri.getEscapedQuery();

    if (q) {
        var reQ = new RegExp(
            "(&|^)" + defaultQuery + "=[^&]*"
        );

        uri.setEscapedQuery(q.replace(reQ, ""));
    }
}

/* 4 ─ tell ZAP which parameters to expose in the UI */
function getRequiredParamsNames() {
    return ["auth_type"];
}

function getOptionalParamsNames() {
    return [
        "http_scheme",
        "http_user",
        "http_pass",
        "token",
        "key_name",
        "key_in",
        "headerDefault",
        "queryDefault",
        "cookieDefault"
    ];
}
