<template>
    <div class="file-list-wrapper">
        <div class="sftp-title">SFTP文件管理</div>
        <div class="file-header">
            <el-input class="path-input" v-model="currentPath" size="small" @keyup.enter.native="getFileList()" placeholder="当前路径..."></el-input>
            <el-button-group>
                <el-button type="primary" size="small" icon="el-icon-s-home" @click="goToHome()" title="主目录"></el-button>
                <el-button type="primary" size="small" icon="el-icon-arrow-up" @click="upDirectory()" title="返回上级目录"></el-button>
                <el-button type="primary" size="small" icon="el-icon-refresh" @click="getFileList()" title="刷新当前目录"></el-button>
                <el-dropdown @click="openUploadDialog()" @command="handleUploadCommand" size="small">
                    <el-button type="primary" size="small" icon="el-icon-upload"></el-button>
                    <el-dropdown-menu slot="dropdown">
                        <el-dropdown-item command="file">{{ $t('uploadFile') }}</el-dropdown-item>
                        <el-dropdown-item command="folder">{{ $t('uploadFolder') }}</el-dropdown-item>
                    </el-dropdown-menu>
                </el-dropdown>
            </el-button-group>
        </div>

        <el-dialog custom-class="uploadContainer" :title="$t(this.titleTip)" :visible.sync="uploadVisible" append-to-body width="32%">
            <el-upload ref="upload" multiple drag :action="uploadUrl" :data="uploadData" :before-upload="beforeUpload" :on-progress="uploadProgress" :on-success="uploadSuccess">
                <i class="el-icon-upload"></i>
                <div class="el-upload__text">{{ $t(this.selectTip) }}</div>
                <div class="el-upload__tip" slot="tip">{{ this.uploadTip }}</div>
            </el-upload>
        </el-dialog>
        
        <el-table :data="fileList" class="file-table" @row-click="rowClick" height="100%">
            <el-table-column
                :label="$t('Name')"
                width="140"
                sortable :sort-method="nameSort">
                <template slot-scope="scope">
                    <p v-if="scope.row.IsDir === true" style="color:#0c60b5;cursor:pointer;" class="el-icon-folder"> {{ scope.row.Name }}</p>
                    <p v-else-if="scope.row.IsDir === false" style="cursor: pointer" class="el-icon-document"> {{ scope.row.Name }}</p>
                </template>
            </el-table-column>
            <el-table-column :label="$t('Size')" prop="Size" width="80"></el-table-column>
            <el-table-column :label="$t('ModifiedTime')" prop="ModifyTime" width="120" sortable></el-table-column>
        </el-table>
    </div>
</template>

<script>
import { fileList } from '@/api/file'
import { mapState } from 'vuex'

export default {
    name: 'FileList',
    data() {
        return {
            uploadVisible: false,
            fileList: [],
            downloadFilePath: '',
            currentPath: '/',
            selectTip: 'clickSelectFile',
            titleTip: 'uploadFile',
            uploadTip: '',
            progressPercent: 0,
            initialRedirectDone: false,
            homePath: ''
        }
    },
    mounted() {
        // 组件挂载时，currentPath 为空或/，自动拉取
        if (!this.currentPath || this.currentPath === '/') {
            this.getFileList()
        }
    },
    computed: {
        ...mapState(['currentTab']), // currentTab may be deprecated but keeping for now
        sshInfoReady() {
            return this.$store.state.sshInfo && this.$store.state.sshInfo.hostname;
        },
        uploadUrl: () => {
            return `${process.env.NODE_ENV === 'production' ? `${location.origin}` : 'api'}/file/upload`
        },
        uploadData: function() {
            return {
                sshInfo: this.$store.getters.sshReq,
                path: this.currentPath
            }
        }
    },
    watch: {
        // Watch for sshInfo to become available
        sshInfoReady(newValue, oldValue) {
            if (newValue && !oldValue) {
                this.getFileList();
            }
        },
        currentTab: function() {
            // This logic might need adjustment if multi-tab is re-enabled
            this.fileList = []
            this.currentPath = this.currentTab && this.currentTab.path ? this.currentTab.path : '/';
        }
    },
    methods: {
        goToHome() {
            if (this.homePath) {
                if (this.currentPath !== this.homePath) {
                    this.currentPath = this.homePath;
                    this.getFileList();
                }
            } else {
                this.$message.warning('主目录信息尚不可用，请刷新重试。');
            }
        },
        openUploadDialog() {
            this.uploadTip = `${this.$t('uploadPath')}: ${this.currentPath}`
            this.uploadVisible = true
        },
        handleUploadCommand(cmd) {
            if (cmd === 'folder') {
                this.selectTip = 'clickSelectFolder'
                this.titleTip = 'uploadFolder'
            } else {
                this.selectTip = 'clickSelectFile'
                this.titleTip = 'uploadFile'
            }
            this.openUploadDialog();
            const isFolder = 'folder' === cmd,
                supported = this.webkitdirectorySupported();
            if (!supported) {
                isFolder && this.$message.warning('当前浏览器不支持');
                return;
            }
            // Add folder support
            this.$nextTick(() => {
                const input = document.getElementsByClassName('el-upload__input')[0];
                if (input) input.webkitdirectory = isFolder;
            })
        },
        webkitdirectorySupported(){
            return 'webkitdirectory' in document.createElement('input')
        },
        beforeUpload(file) {
            this.uploadTip = `${this.$t('uploading')} ${file.name} ${this.$t('to')} ${this.currentPath}, ${this.$t('notCloseWindows')}..`
            this.uploadData.id = file.uid
            // Is there a folder?
            const dirPath = file.webkitRelativePath;
            this.uploadData.dir = dirPath ? dirPath.substring(0, dirPath.lastIndexOf('/')) : '';
            return true
        },
        uploadSuccess(r, file) {
            this.uploadTip = `${file.name}${this.$t('uploadFinish')}!`
        },
        uploadProgress(e, f) {
            e.percent = e.percent / 2
            f.percentage = f.percentage / 2
            if (e.percent === 50) {
                const ws = new WebSocket(`${(location.protocol === 'http:' ? 'ws' : 'wss')}://${location.host}${process.env.NODE_ENV === 'production' ? '' : '/ws'}/file/progress?id=${f.uid}`)
                ws.onmessage = e1 => {
                    f.percentage = (f.size + Number(e1.data)) / (f.size * 2) * 100
                }
                ws.onclose = () => {
                    console.log(Date(), 'onclose')
                }
                ws.onerror = () => {
                    console.log(Date(), 'onerror')
                }
            }
        },
        nameSort(a, b) {
            return a.Name > b.Name
        },
        rowClick(row) {
            if (row.IsDir) {
                // Folder handling
                this.currentPath = this.currentPath.charAt(this.currentPath.length - 1) === '/' ? this.currentPath + row.Name : this.currentPath + '/' + row.Name
                this.getFileList()
            } else {
                // File handling
                this.downloadFilePath = this.currentPath.charAt(this.currentPath.length - 1) === '/' ? this.currentPath + row.Name : this.currentPath + '/' + row.Name
                this.downloadFile()
            }
        },
        async getFileList() {
            this.currentPath = this.currentPath.replace(/\\+/g, '/')
            if (this.currentPath === '') {
                this.currentPath = '/'
            }
            const result = await fileList(this.currentPath, this.$store.getters.sshReq)
            if (result.Msg === 'success') {
                if (result.Data.home) {
                    this.homePath = result.Data.home;
                }
                if (result.Data.list === null) {
                    this.fileList = []
                } else {
                    this.fileList = result.Data.list
                }
                // 只要后端返回的home和当前路径不同且home不为/，就切换 (仅执行一次)
                if (!this.initialRedirectDone && result.Data.home && result.Data.home !== '/' && this.currentPath !== result.Data.home) {
                    this.initialRedirectDone = true
                    this.currentPath = result.Data.home
                    await this.getFileList()
                    return
                }
            } else {
                this.fileList = []
                this.$message({
                    message: result.Msg,
                    type: 'error',
                    duration: 3000
                })
            }
        },
        upDirectory() {
            if (this.currentPath === '/') {
                return
            }
            let pathList = this.currentPath.split('/')
            if (pathList[pathList.length - 1] === '') {
                pathList = pathList.slice(0, pathList.length - 2)
            } else {
                pathList = pathList.slice(0, pathList.length - 1)
            }
            this.currentPath = pathList.length === 1 ? '/' : pathList.join('/')
            this.getFileList()
        },
        downloadFile() {
            const prefix = process.env.NODE_ENV === 'production' ? `${location.origin}` : 'api'
            const downloadUrl = `${prefix}/file/download?path=${this.downloadFilePath}&sshInfo=${this.$store.getters.sshReq}`
            window.open(downloadUrl)
        }
    }
}
</script>

<style lang="scss">
.file-list-wrapper {
    display: flex;
    flex-direction: column;
    height: 100%;
    padding-top: 10px;
    box-sizing: border-box;

    .sftp-title {
        font-size: 16px;
        font-weight: bold;
        color: var(--text-color);
        text-align: center;
        padding-bottom: 8px;
        margin-bottom: 8px;
        border-bottom: 1px solid var(--input-border);
        flex-shrink: 0;
    }

    .file-header {
        flex-shrink: 0;
        margin-bottom: 10px;
        display: flex;
        align-items: center;
    }

    .path-input {
        flex: 1;
        padding: 0 5px;
        margin-right: 2px;
    }

    .file-header .el-button-group .el-button {
        padding: 8px;
        width: 36px;
        height: 32px;
        line-height: 1;
    }

    .file-table {
        flex-grow: 1;
        width: 100%;
        & .el-table__body-wrapper {
            height: calc(100% - 40px) !important; /* Adjust based on header height */
        }
        /* --- Style Customization for Compact Look --- */
        &.el-table th {
            height: 40px;
            padding: 0;
        }
        &.el-table td {
            padding: 0;
        }
        .cell {
            padding: 1px 0px 2px 5px;
            line-height: 1.1;
            p {
              margin: 0;
            }
        }
        th > .cell {
            display: flex;
            align-items: center;
        }
        /* --- End Customization --- */
    }
}
.uploadContainer {
    .el-upload {
        display: flex;
    }
    .el-upload-dragger {
        width: 95%;
    }
}
</style>
