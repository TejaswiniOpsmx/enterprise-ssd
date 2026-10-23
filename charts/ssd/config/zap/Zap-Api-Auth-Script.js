function authenticate(helper, paramsValues, credentials) {
    print("authenticate stub");
    /* Return a dummy message (no network login required).               */
    var msg = helper.prepareMessage();
    msg.setRequestHeader("GET / HTTP/1.1");
    return msg;
}
function getRequiredParamsNames() { return []; }
function getOptionalParamsNames() { return []; }
function getCredentialsParamsNames() { return []; }
