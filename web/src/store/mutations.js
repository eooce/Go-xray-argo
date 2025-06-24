export default {
    SET_PASS(state, pass) {
        state.sshInfo.password = pass
    },
    SET_LIST(state, list) {
        state.sshList = list
        localStorage.setItem('sshList', list)
    },
    SET_TERMLIST(state, list) {
        state.termList = list
    },
    SET_SSH(state, ssh) {
        state.sshInfo.hostname = ssh.hostname
        state.sshInfo.port = ssh.port
        state.sshInfo.username = ssh.username
        if (ssh.password !== undefined) {
            state.sshInfo.password = ssh.password
        }
        if (ssh.command !== undefined) {
            state.sshInfo.command = ssh.command
        }
        if (ssh.privateKey !== undefined) {
            state.sshInfo.privateKey = ssh.privateKey
        }
        if (ssh.passphrase !== undefined) {
            state.sshInfo.passphrase = ssh.passphrase
        }
    },
    SET_TAB(state, tab) {
        state.currentTab = tab
    },
    SET_LANGUAGE: (state, language) => {
        state.language = language
        localStorage.setItem('language', language)
    }
}
