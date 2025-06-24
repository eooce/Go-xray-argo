import { getLanguage } from '@/lang/index'

const state = () => ({
    sshInfo: {
        hostname: '',
        username: '',
        port: '',
        password: '',
        command: ''
    },
    sshList: Object.prototype.hasOwnProperty.call(localStorage, 'sshList') ? localStorage.getItem('sshList') : null,
    termList: [],
    currentTab: {},
    language: getLanguage()
})

export default state
