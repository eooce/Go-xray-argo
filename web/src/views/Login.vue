<template>
  <div class="login-container" :class="{ 'dark-theme': isDarkTheme }">
    <div class="theme-switch-wrapper">
      <div class="theme-switch" @click="toggleTheme">
        <i class="fas" :class="isDarkTheme ? 'fa-sun' : 'fa-moon'" style="margin-top: -40px;"></i>
      </div>
    </div>
    <div class="card" style="margin: 20px auto;">
      <div class="title">WebSSH Console</div>
      <el-form :model="sshInfo" label-position="top" class="form-grid">
        <el-row :gutter="20">
          <el-col :span="12">
            <el-form-item label="主机地址 (Hostname)">
              <el-input v-model="sshInfo.hostname" placeholder="请输入主机地址" />
            </el-form-item>
          </el-col>
          <el-col :span="12">
            <el-form-item label="端口 (Port)">
              <el-input v-model.number="sshInfo.port" placeholder="请输入端口(默认22)" />
            </el-form-item>
          </el-col>
        </el-row>
        <el-row :gutter="20">
          <el-col :span="12">
            <el-form-item label="用户名 (Username)">
              <el-input v-model="sshInfo.username" placeholder="请输入用户名" />
            </el-form-item>
          </el-col>
          <el-col :span="12">
            <el-form-item label="密码 (Password)">
              <el-input v-model="sshInfo.password" type="password" placeholder="请输入密码" show-password/>
            </el-form-item>
          </el-col>
        </el-row>
        <el-row :gutter="20">
          <el-col :span="12">
            <el-form-item label="私钥 (Private Key)">
              <el-upload
                class="upload-key"
                :show-file-list="false"
                :before-upload="handlePrivateKeyUpload"
                accept=".pem,.ppk,.key,.rsa,.id_rsa,.id_dsa,.txt"
              >
                <div class="upload-flex-row">
                  <div class="upload-btn">
                    <i class="el-icon-folder-opened" style="margin-right:8px;"></i>
                    选择文件
                  </div>
                  <div class="upload-filename">
                    {{ privateKeyFileName || '未选择私钥文件' }}
                  </div>
                </div>
              </el-upload>
            </el-form-item>
          </el-col>
          <el-col :span="12">
            <el-form-item label="密钥口令 (PIN)">
              <el-input v-model="sshInfo.passphrase" placeholder="如果有设置请输入密钥口令" />
            </el-form-item>
          </el-col>
        </el-row>
        <el-row>
          <el-col :span="24">
            <el-form-item label="初始命令 (Initial command)">
              <el-input v-model="sshInfo.command" placeholder="登录后要执行的命令" />
            </el-form-item>
          </el-col>
        </el-row>
        <el-row type="flex" justify="center" style="margin-top: 10px;">
          <el-button type="danger" icon="el-icon-refresh" @click="onReset">重置输入</el-button>
          <el-button type="primary" icon="el-icon-link" @click="onGenerateLink">生成链接</el-button>
          <el-button type="success" @click="onConnect"><i class="fas fa-terminal" style="margin-right: 6px;"></i>连接SSH</el-button>
        </el-row>
        <el-row v-if="generatedLink" style="margin-top: 18px;">
          <el-col :span="24">
             <el-input v-model="generatedLink" readonly>
              <template slot="append">
                <el-button @click="copyLink" icon="el-icon-document-copy"></el-button>
              </template>
            </el-input>
          </el-col>
        </el-row>
      </el-form>
    </div>
    <div class="footer">
      <a href="https://github.com/eooce/webssh" target="_blank" rel="noopener noreferrer">WebSSH Console | Powered by eooce</a>
    </div>
  </div>
</template>

<script>
export default {
  data () {
    return {
      sshInfo: {
        hostname: '',
        port: '',
        username: '',
        password: '',
        privateKey: '',
        passphrase: '',
        command: ''
      },
      privateKeyFileName: '',
      generatedLink: '',
      isDarkTheme: false
    }
  },
  watch: {
    sshInfo: {
      handler(newVal) {
        localStorage.setItem('sshInfo', JSON.stringify(newVal));
      },
      deep: true
    }
  },
  created() {
    // 从 localStorage 恢复完整的连接信息
    const savedInfo = localStorage.getItem('connectionInfo')
    if (savedInfo) {
      const info = JSON.parse(savedInfo)
      this.sshInfo = {
        hostname: info.hostname || '',
        port: info.port || '',
        username: info.username || '',
        password: info.password || '',
        privateKey: info.privateKey || '',
        passphrase: info.passphrase || '',
        command: info.command || ''
      }
      // 如果有私钥，恢复文件名显示
      if (info.privateKey) {
        this.privateKeyFileName = '已保存的密钥文件'
      }
    }
    
    // 检查主题设置
    const savedTheme = localStorage.getItem('isDarkTheme')
    if (savedTheme !== null) {
      this.isDarkTheme = savedTheme === 'true'
    }
    
    // 添加 Font Awesome CSS
    const link = document.createElement('link')
    link.rel = 'stylesheet'
    link.href = 'https://cdnjs.cloudflare.com/ajax/libs/font-awesome/5.15.4/css/all.min.css'
    document.head.appendChild(link)
  },
  methods: {
    onConnect () {
      // 清除之前的认证信息
      sessionStorage.removeItem('sshInfo')
      
      if (!this.sshInfo.hostname || !this.sshInfo.username) {
        this.$message.error('主机和用户名不能为空！')
        return
      }
      if (!this.sshInfo.password && !this.sshInfo.privateKey) {
        this.$message.error('请输入密码或上传密钥！')
        return
      }

      // 根据实际使用的登录方式清理未使用的认证信息
      if (this.sshInfo.privateKey && this.sshInfo.privateKey.trim()) {
        // 使用密钥登录时，清除密码
        this.sshInfo.password = ''
      } else if (this.sshInfo.password) {
        // 使用密码登录时，清除密钥相关信息
        this.sshInfo.privateKey = ''
        this.sshInfo.passphrase = ''
        this.privateKeyFileName = ''
      }

      // 保存完整连接信息到 localStorage
      const connectionInfo = {
        hostname: this.sshInfo.hostname,
        port: this.sshInfo.port || 22,
        username: this.sshInfo.username,
        password: this.sshInfo.password || '',
        privateKey: this.sshInfo.privateKey || '',
        passphrase: this.sshInfo.passphrase || '',
        command: this.sshInfo.command || ''
      }
      localStorage.setItem('connectionInfo', JSON.stringify(connectionInfo))

      // 构建查询参数
      const query = {
        hostname: encodeURIComponent(this.sshInfo.hostname),
        port: Number(this.sshInfo.port) || 22,
        username: encodeURIComponent(this.sshInfo.username),
        command: encodeURIComponent(this.sshInfo.command || '')
      }

      // 根据登录方式设置认证信息
      if (this.sshInfo.privateKey && this.sshInfo.privateKey.trim()) {
        // 使用密钥登录
        sessionStorage.setItem('sshInfo', JSON.stringify(this.sshInfo))
        query.useKey = 1
      } else if (this.sshInfo.password) {
        // 使用密码登录
        query.password = btoa(this.sshInfo.password)
      }

      this.$router.push({
        path: '/terminal',
        query
      })
    },
    onReset () {
      // 清除表单数据
      this.sshInfo = { 
        hostname: '', 
        port: '', 
        username: '', 
        password: '', 
        command: '', 
        privateKey: '', 
        passphrase: '' 
      }
      this.privateKeyFileName = ''
      this.generatedLink = ''

      // 清除所有存储的认证信息
      localStorage.removeItem('connectionInfo')
      sessionStorage.removeItem('sshInfo')

      // 清除文件输入框
      const fileInput = document.querySelector('.upload-key input[type="file"]')
      if (fileInput) {
        fileInput.value = ''
      }
    },
    onGenerateLink () {
      if (this.sshInfo.privateKey) {
        this.$message.warning('密钥方式登录不支持生成快捷链接，请改用密码登录方式')
        return
      }
      if (!this.sshInfo.hostname || !this.sshInfo.username) {
        this.$message.error('请填写主机、用户名和密码以生成链接！')
        return
      }
      const url = new URL(window.location.href)
      url.pathname = '/terminal'
      const cleanSshInfo = {}
      const infoToProcess = { ...this.sshInfo, port: this.sshInfo.port || 22 }
      for (const key in infoToProcess) {
        if (infoToProcess[key] !== '' && infoToProcess[key] !== null) {
          if (key === 'password') {
            cleanSshInfo[key] = btoa(infoToProcess[key])
          } else {
            cleanSshInfo[key] = infoToProcess[key]
          }
        }
      }
      url.search = new URLSearchParams(cleanSshInfo).toString()
      this.generatedLink = url.href
    },
    copyLink () {
      if (this.generatedLink) {
        navigator.clipboard.writeText(this.generatedLink).then(() => {
          this.$message.success('链接已复制！')
        }).catch(err => {
          this.$message.error('复制失败: ' + err)
        })
      }
    },
    toggleTheme () {
      this.isDarkTheme = !this.isDarkTheme;
      localStorage.setItem('isDarkTheme', this.isDarkTheme);
    },
    handlePrivateKeyUpload(file) {
      // 上传密钥时清除密码，确保使用密钥登录
      this.sshInfo.password = ''
      
      const reader = new FileReader()
      reader.onload = (e) => {
        this.sshInfo.privateKey = e.target.result
        this.privateKeyFileName = file.name
      }
      reader.readAsText(file)
      return false // 阻止自动上传
    }
  }
}
</script>

<style lang="scss" scoped>
.login-container ::v-deep .el-input__inner {
  font-size: medium;
  border-radius: 10px;
}

.login-container ::v-deep .el-form-item {
  margin-bottom: 15px;
}

.login-container {
  display: flex;
  min-height: 100vh;
  flex-direction: column;
  align-items: center;
  background: var(--bg-color);
  position: relative;
  padding-top: 3vh;
  padding-bottom: 60px;
  transition: background-color 0.3s, color 0.3s;
}

.card {
  background: var(--card-bg);
  box-shadow: var(--shadow);
  border-radius: 20px;
  padding-top: 10px;
  padding-bottom: 25px;
  width: 100%;
  max-width: 42rem;
  position: relative;
  transition: background-color 0.3s, box-shadow 0.3s;
}

.title {
  text-align: center;
  font-size: 2.5rem;
  font-weight: 800;
  color: var(--title-color);
  margin-bottom: 2.3rem;
  letter-spacing: 1px;
  position: relative;
  padding-bottom: 1rem;
  font-family: none;
  transition: color 0.3s;
}

.title::after {
  content: '';
  position: absolute;
  bottom: 0;
  left: 50%;
  transform: translateX(-50%);
  width: 300px;
  height: 4px;
  background-color: var(--title-color);
  border-radius: 2px;
  transition: background-color 0.3s;
}

.form-grid ::v-deep .el-form-item__label {
  padding-bottom: 0;
  font-size: 15px;
  color: var(--text-color);
  line-height: 30px;
  transition: color 0.3s;
}

.form-grid ::v-deep .el-button {
  font-size: 1rem;
  font-weight: 600;
  padding: 0.9rem 1rem;
  border-radius: 10px;
  transition: all 0.3s;
}

.login-container ::v-deep .el-form-item .el-upload.upload-key {
  width: 100% !important;
  height: 48px !important;
  background: none !important;
  border: none !important;
  box-shadow: none !important;
  margin: 0 !important;
  padding: 0 !important;
}

.login-container ::v-deep .upload-flex-row {
  display: flex !important;
  flex-direction: row !important;
  align-items: stretch !important;
  width: 100%;
  height: 100%;
}

.login-container ::v-deep .upload-flex-row .upload-btn,
.login-container ::v-deep .upload-flex-row .upload-filename {
  height: 100%;
  display: flex;
  align-items: center;
}

.login-container ::v-deep .upload-btn {
  display: flex;
  align-items: center;
  background: var(--primary);
  color: #fff;
  font-weight: 600;
  font-size: 16px;
  border-radius: 12px 0 0 12px;
  padding: 0 28px;
  cursor: pointer;
  transition: background 0.2s;
  height: 100%;
}

.login-container ::v-deep .upload-btn:hover {
  background: #202f3e;
}

.login-container ::v-deep .upload-filename {
  display: flex;
  align-items: center;
  background: var(--input-bg);
  color: #6b7680;
  font-size: 15px;
  border-radius: 0 12px 12px 0;
  padding: 1px 30px;
  height: 100%;
  flex: 1;
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
}

.login-container.dark-theme ::v-deep .upload-key {
  border-color: #4d4d4d;
  background-color: var(--card-bg);
}
.login-container.dark-theme ::v-deep .upload-key .el-button {
  background: #232323;
  color: #409eff;
}
.login-container.dark-theme ::v-deep .upload-key .el-button:hover,
.login-container.dark-theme ::v-deep .upload-key .el-button:focus {
  background: #409eff !important;
  color: #fff !important;
}
.login-container.dark-theme ::v-deep .upload-key span {
  background: #232323;
  color: #aaa !important;
}

.login-container.dark-theme ::v-deep .upload-filename {
  background: var(--input-bg) !important;
  color: var(--text-color) !important;
}

.footer {
  position: absolute;
  bottom: 8px;
  text-align: center;
  width: 100%;
  color: var(--text-color);
  opacity: 0.6;
  transition: color 0.3s;
}

.footer a {
  font-size: 0.9rem;
  color: #000000;
  font-family: system-ui;
  color: var(--text-color);
  text-decoration: none;
  transition: color 0.3s;
}

.footer a:hover {
  text-decoration: underline;
}

.theme-switch-wrapper {
  position: absolute;
  top: 25px;
  right: 30px;
  z-index: 10;
}

.theme-switch {
  width: 40px;
  height: 40px;
  border-radius: 50%;
  display: flex;
  align-items: center;
  justify-content: center;
  cursor: pointer;
  transition: background-color 0.3s;
}

.theme-switch i {
  margin-top: -20px;
  font-size: 20px;
  color: var(--icon-color);
  transition: color 0.3s;
}

/* Light theme variables */
.login-container {
  --bg-color: #f5f5f5;
  --card-bg: #ffffff;
  --title-color: #125fc7; /* Darker blue for title */
  --text-color: #3b3d3d;
  --shadow: 0 4px 6px rgba(0, 0, 0, 0.1);
  --success: #13af54;
  --success-hover: #0e8942; /* Darker green */
  --danger: #d63031;
  --danger-hover: #b247c2; /* Darker purple */
  --primary: #409eff;
  --primary-hover: #0f9281; /* Darker blue */
  --switch-bg: #f0f0f0;
  --icon-color: #494949;
}

/* Dark theme variables */
.login-container.dark-theme {
  --bg-color: #1a1a1a;
  --card-bg: #2d2d2d;
  --title-color: #ffffff;
  --text-color: #e0e0e0;
  --shadow: 0 4px 6px rgba(0, 0, 0, 0.3);
  --success: #13af54;
  --success-hover: #0e8942;
  --danger: #d63031;
  --danger-hover: #b247c2;
  --primary: #409eff;
  --primary-hover: #0f9281;
  --switch-bg: #333333;
  --icon-color: #f5f5f5;
}

/* Button styles with custom hover colors */
.el-button--success {
  background-color: var(--success);
  border-color: var(--success);
  color: white;
}

.el-button--danger {
  background-color: var(--danger);
  border-color: var(--danger);
  color: white;
}

.el-button--primary {
  background-color: var(--primary);
  border-color: var(--primary);
  color: white;
}

.el-button--success:hover {
  background-color: var(--success-hover);
  border-color: var(--success-hover);
  color: white;
}

.el-button--danger:hover {
  background-color: var(--danger-hover);
  border-color: var(--danger-hover);
  color: white;
}

.el-button--primary:hover {
  background-color: var(--primary-hover);
  border-color: var(--primary-hover);
  color: white;
}
</style>