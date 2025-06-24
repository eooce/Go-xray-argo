<template>
  <div class="terminal-page-wrapper">
    <div class="terminal-page-container">
      <div class="terminal-area">
        <div id="xterm-container"></div>
      </div>
      <div class="file-tree" :class="{ 'is-visible': isSftpVisible }">
        <FileList />
      </div>
    </div>
    <div class="terminal-footer">
      <span>WebSSH Console | Powered by eooce</span>
      <a href="https://github.com/eooce/webssh" target="_blank" class="github-link" title="GitHub">
        <i class="fab fa-github"></i>
      </a>
      <button @click="toggleSftpPanel" class="sftp-toggle-btn" title="文件管理">
        <i class="fas fa-folder-open"></i>
      </button>
    </div>
  </div>
</template>

<script>
import { checkSSH } from '@/api/common'
import { Terminal } from 'xterm'
import { FitAddon } from 'xterm-addon-fit'
import { AttachAddon } from 'xterm-addon-attach'
import FileList from '@/components/FileList'

export default {
    name: 'Terminal',
    components: { FileList },
    data() {
        return {
            term: null,
            ws: null,
            resetClose: false,
            ssh: null,
            savePass: false,
            fontSize: 15,
            isSftpVisible: false
        }
    },
    mounted() {
        this.$nextTick(() => {
            this.createTerm()
        })
    },
    methods: {
        toggleSftpPanel() {
            this.isSftpVisible = !this.isSftpVisible
        },
        setSSH() {
            this.$store.commit('SET_SSH', this.ssh)
        },
        resizeTerm() {
            // This is now handled by CSS flexbox and xterm's fit-addon.
            // The logic is kept here in case of future need.
        },
        createTerm() {
            const sshInfo = this.$store.state.sshInfo;
            if (!sshInfo || !sshInfo.hostname) {
                this.$message.error('无效的连接信息！正在返回登录页...')
                this.$router.push('/')
                return
            }
            const termWeb = document.getElementById('xterm-container')
            if (!termWeb) {
                console.error('Terminal container #xterm-container not found.')
                return
            }
            const sshReq = this.$store.getters.sshReq
            this.close()
            const prefix = process.env.NODE_ENV === 'production' ? '' : '/api'
            const fitAddon = new FitAddon()
            this.term = new Terminal({
                cursorBlink: true,
                cursorStyle: 'bar',
                cursorWidth: 4,
                fontFamily: 'DejaVu Sans Mono, monospace',  // 设置字体
                fontSize: this.fontSize,            // 字号
                theme: {
                    background: '#000000',          // 背景色
                    foreground: '#ffffff',          // 字体颜色
                    cursor: '#ffffff',              // 光标颜色
                    selection: '#acacac7d',         // 选中区域颜色
                    blue: '#0950ee',        
                    brightBlue: '#71afff',
                }
            })
            this.term.loadAddon(fitAddon)
            this.term.open(document.getElementById('xterm-container'))
            this.term.focus()
            this.term.write('\x1b[1;1H\x1b[1;32m正在连接，请稍后...\x1b[0m\r\n')
            try { fitAddon.fit() } catch (e) {/**/}
            const self = this
            const heartCheck = {
                timeout: 5000, // 5s发一次心跳
                intervalObj: null,
                stop: function() {
                    clearInterval(this.intervalObj)
                },
                start: function() {
                    this.intervalObj = setInterval(function() {
                        if (self.ws !== null && self.ws.readyState === 1) {
                            self.ws.send('ping')
                        }
                    }, this.timeout)
                }
            }
            let closeTip = '已超时关闭!'
            if (this.$store.state.language === 'en') {
                closeTip = 'Connection timed out!'
            }
            // open websocket
            this.ws = new WebSocket(`${(location.protocol === 'http:' ? 'ws' : 'wss')}://${location.host}${prefix}/term?sshInfo=${sshReq}&rows=${this.term.rows}&cols=${this.term.cols}&closeTip=${closeTip}`)
            this.ws.onopen = () => {
                console.log(Date(), 'onopen')
                self.connected()
                heartCheck.start()
                self._initCmdSent = false
            }
            // 监听ws消息，检测到提示符再自动执行初始命令并清理提示
            this.ws.onmessage = (event) => {
                if (typeof event.data === 'string') {
                    // We need to wait for the attach addon to process the data and write it to the terminal.
                    // A timeout of 0ms should be enough to push this to the end of the execution queue.
                    setTimeout(() => {
                        if (!self._initCmdSent && self.ssh) {
                            const term = self.term;
                            if (!term || !term.buffer || !term.buffer.active) return;

                            const currentLineNumber = term.buffer.active.baseY + term.buffer.active.cursorY;
                            const line = term.buffer.active.getLine(currentLineNumber);
                            if (line) {
                                const lineText = line.translateToString();
                                // More robust regex to detect various shell prompts at the end of the line
                                if (/[>$#%]\s*$/.test(lineText.trimEnd())) {
                                    self._initCmdSent = true;
                                    // This ANSI sequence saves cursor, moves to 1,1, clears line, and restores cursor
                                    self.term.write('\x1b[s\x1b[1;1H\x1b[2K\x1b[u');
                                    if (self.ssh.command) {
                                        setTimeout(() => {
                                            if (self.ws && self.ws.readyState === 1) {
                                                self.ws.send(self.ssh.command + '\r'); // 让后端执行命令
                                            }
                                        }, 100);
                                    }
                                }
                            }
                        }
                    }, 10);
                }
            }
            this.ws.onclose = () => {
                console.log(Date(), 'onclose')
                if (!self.resetClose) {
                    if (self.ssh && !this.savePass) {
                        this.$store.commit('SET_PASS', '')
                        self.ssh.password = ''
                    }
                    this.$message({
                        message: this.$t('wsClose'),
                        type: 'warning',
                        duration: 0,
                        showClose: true
                    })
                    this.ws = null
                }
                heartCheck.stop()
                self.resetClose = false
                if (self.ws !== null && self.ws.readyState === 1) {
                    self.ws.send(`resize:${self.term.rows}:${self.term.cols}`)
                }
            }
            this.ws.onerror = () => {
                console.log(Date(), 'onerror')
            }
            const attachAddon = new AttachAddon(this.ws, { bidirectional: false })
            this.term.loadAddon(attachAddon)

            // 恢复终端输入到ws
            this.term.onData(data => {
                if (self.ws && self.ws.readyState === 1) {
                    self.ws.send(data)
                }
            })

            this.term.attachCustomKeyEventHandler((e) => {
                const keyArray = ['F5', 'F11', 'F12']
                if (keyArray.indexOf(e.key) > -1) {
                    return false
                }
                // ctrl + v
                if (e.ctrlKey && e.key === 'v') {
                    document.execCommand('copy')
                    return false
                }
                // ctrl + c
                if (e.ctrlKey && e.key === 'c' && self.term.hasSelection()) {
                    document.execCommand('copy')
                    return false
                }
            })
            // detect available wheel event
            // 各个厂商的高版本浏览器都支持"wheel"
            // Webkit 和 IE一定支持"mousewheel"
            // "DOMMouseScroll" 用于低版本的firefox
            const wheelSupport = 'onwheel' in document.createElement('div') ? 'wheel' : document.onmousewheel !== undefined ? 'mousewheel' : 'DOMMouseScroll'
            termWeb.addEventListener(wheelSupport, (e) => {
                if (e.ctrlKey) {
                    e.preventDefault()
                    if (e.deltaY < 0) {
                        self.term.setOption('fontSize', ++this.fontSize)
                    } else {
                        self.term.setOption('fontSize', --this.fontSize)
                    }
                    try { fitAddon.fit() } catch (e) {/**/}
                    if (self.ws !== null && self.ws.readyState === 1) {
                        self.ws.send(`resize:${self.term.rows}:${self.term.cols}`)
                    }
                }
            })
            window.addEventListener('resize', () => {
                try { fitAddon.fit() } catch (e) {/**/}
                if (self.ws !== null && self.ws.readyState === 1) {
                    self.ws.send(`resize:${self.term.rows}:${self.term.cols}`)
                }
            })
        },
        async connected() {
            const sshInfo = this.$store.state.sshInfo
            // 深度拷贝对象
            this.ssh = Object.assign({}, sshInfo)
            // 校验ssh连接信息是否正确
            const result = await checkSSH(this.$store.getters.sshReq)
            if (result.Msg !== 'success') {
                return
            } else {
                this.savePass = result.Data.savePass
            }
            document.title = sshInfo.hostname
            let sshList = this.$store.state.sshList
            if (sshList === null) {
                if (this.savePass) {
                    sshList = `[{"hostname": "${sshInfo.hostname}", "username": "${sshInfo.username}", "port":${sshInfo.port}, "logintype":${sshInfo.logintype}, "password":"${sshInfo.password}"}]`
                } else {
                    sshList = `[{"hostname": "${sshInfo.hostname}", "username": "${sshInfo.username}", "port":${sshInfo.port},  "logintype":${sshInfo.logintype}}]`
                }
            } else {
                const sshListObj = JSON.parse(window.atob(sshList))
                sshListObj.forEach((v, i) => {
                    if (v.hostname === sshInfo.hostname) {
                        sshListObj.splice(i, 1)
                    }
                })
                sshListObj.push({
                    hostname: sshInfo.hostname,
                    username: sshInfo.username,
                    port: sshInfo.port,
                    logintype: sshInfo.logintype
                })
                if (this.savePass) {
                    sshListObj[sshListObj.length - 1].password = sshInfo.password
                }
                sshList = JSON.stringify(sshListObj)
            }
            this.$store.commit('SET_LIST', window.btoa(sshList))
        },
        close() {
            if (this.ws !== null) {
                this.ws.close()
                this.resetClose = true
            }
            if (this.term !== null) {
                this.term.dispose()
            }
        }
    },
    beforeDestroy() {
        this.close()
    }
}
</script>

<style scoped>
.terminal-page-wrapper {
  display: flex;
  flex-direction: column;
  flex-grow: 1; /* This will make it fill the space given by App.vue */
  min-height: 0; /* Prevents overflow issues */
  background: var(--card-bg);
  box-shadow: var(--shadow);
}

.terminal-page-container {
  display: flex;
  flex-grow: 1;
  min-height: 0;
  overflow: hidden;
}

.terminal-area {
  flex: 1;
  min-width: 0;
  display: flex;
  flex-direction: column;
  background-color: black;
}

#xterm-container {
  flex-grow: 1;
  width: 100%;
  padding-left: 2px;
}

.file-tree {
  width: 350px;
  border-left: 1px solid var(--input-border);
  background: var(--input-bg);
  display: flex;
  flex-direction: column;
}

.terminal-footer {
  width: 100%;
  margin-left: -3rem;
  text-align: center;
  padding: 8px 0 6px 0;
  font-size: 15px;
  color: #0e0e0e;
  background: var(--card-bg);
  border-top: 1px solid var(--input-border);
  display: flex;
  justify-content: center;
  align-items: center;
  gap: 8px;
  flex-shrink: 0;
}

.github-link {
  color: #0e0e0e;
  margin-left: 4px;
  font-size: 18px;
  transition: color 0.2s;
}

.github-link:hover {
  color: var(--text-primary);
}

.sftp-toggle-btn {
  display: none;
  background: none;
  border: none;
  color: #0e0e0e;
  font-size: 18px;
  cursor: pointer;
  padding: 0;
  line-height: 1;
}

.sftp-toggle-btn:hover {
  color: var(--text-primary);
}

@media (max-width: 768px) {
  .sftp-toggle-btn {
    display: inline-block;
  }

  .terminal-page-container {
    position: relative;
    overflow: hidden; /* Contain the sliding panel */
  }

  .file-tree {
    position: absolute;
    top: 0;
    right: 0;
    bottom: 0;
    width: 85%;
    max-width: 320px;
    transform: translateX(100%);
    transition: transform 0.3s ease-in-out;
    z-index: 20;
    border-left: none;
    box-shadow: -2px 0 10px rgba(0,0,0,0.15);
  }

  .file-tree.is-visible {
    transform: translateX(0);
  }

  .terminal-footer {
    margin-left: 0;
    width: 100%;
  }
}
</style>
