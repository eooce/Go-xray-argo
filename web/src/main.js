import Vue from 'vue'

import element from '@/utils/element'
import 'element-ui/lib/theme-chalk/index.css'

import '@/styles/index.scss' // global css

import App from '@/App'
import store from '@/store/index'
import router from './router'

import 'xterm/css/xterm.css'

import i18n from './lang/index'

Vue.use(element)

Vue.config.productionTip = false

/* eslint-disable no-new */
new Vue({
    el: '#app',
    i18n,
    store,
    router,
    render: h => h(App)
})

function setTheme(theme) {
  if (theme === 'dark') {
    document.body.classList.add('dark-theme');
  } else {
    document.body.classList.remove('dark-theme');
  }
  localStorage.setItem('theme', theme);
}

// 初始化
setTheme(localStorage.getItem('theme') || 'light');
window.setTheme = setTheme; // 方便全局调用