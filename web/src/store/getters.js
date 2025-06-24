export default {
    sshReq: state => {
        const sshInfo = {
            hostname: state.sshInfo.hostname,
            port: Number(state.sshInfo.port),
            username: state.sshInfo.username,
            logintype: state.sshInfo.privateKey && state.sshInfo.privateKey.trim() ? 1 : 0 // 只有当privateKey存在且不为空时才使用密钥登录
        };
        if (state.sshInfo.password) {
            sshInfo.password = state.sshInfo.password;
        }
        if (state.sshInfo.privateKey && state.sshInfo.privateKey.trim()) {
            sshInfo.privateKey = state.sshInfo.privateKey;
        }
        if (state.sshInfo.passphrase) {
            sshInfo.passphrase = state.sshInfo.passphrase;
        }
        const jsonStr = JSON.stringify(sshInfo);
        return window.btoa(jsonStr);
    }
}
